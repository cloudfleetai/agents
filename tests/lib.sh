# Shared helpers for tests/run. Source it, do not run it.

PASSED=0
FAILED=0
SKIPPED=0

pass() { printf '  ok       %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  FAIL     %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/           /'; FAILED=$((FAILED + 1)); }
skip() { printf '  skip     %s\n' "$1"; SKIPPED=$((SKIPPED + 1)); }

# check <description> <shell condition>
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

# same_set <description> <expected, one per line> <actual, one per line>
same_set() {
    local want got
    want=$(printf '%s\n' "$2" | sed '/^$/d' | sort -u)
    got=$(printf '%s\n' "$3" | sed '/^$/d' | sort -u)
    if [ "$want" = "$got" ]; then
        pass "$1"
    else
        fail "$1" "$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | sed 's/^</missing:/; s/^>/unexpected:/')"
    fi
}

all_skills() { for d in "$REPO"/skills/*/; do basename "$d"; done | sed 's/^/cloudfleet:/'; }

invocable_skills() {
    local d
    for d in "$REPO"/skills/*/; do
        grep -q '^user-invocable: false' "$d/SKILL.md" || basename "$d"
    done | sed 's/^/cloudfleet:/'
}

hook_events() { jq -r '.hooks | keys[]' "$REPO/$1"; }

# Hook log queries. The log has one {harness, event, input, output} object per line.
log_lines() { [ -f "$HOOK_LOG" ] && cat "$HOOK_LOG"; }

# log_has <jq filter selecting matching lines>
log_has() { log_lines | jq -e -s "any(.[]; $1)" >/dev/null 2>&1; }

# Event shapes: for each event (split by tool kind), the top-level input fields
# and their JSON types. Contents are never kept, so a snapshot holds no session
# data, but a harness changing its hook format changes the shape.
log_shapes() {
    log_lines | jq -s -S '
        map(select(.event != "" and (.input | type) == "object")
            | (.input.tool_name // .input.toolName) as $tool
            | {key: (.event + (if $tool then ":" + ($tool | sub("^(mcp__|cloudfleet-).*"; "mcp") | ascii_downcase) else "" end)),
               value: (.input | to_entries | map({(.key): (.value | type)}) | add)})
        | group_by(.key)
        | map({key: .[0].key,
               value: (reduce (.[].value | to_entries[]) as $f ({}; .[$f.key] = ((.[$f.key] // []) + [$f.value] | unique)))})
        | from_entries'
}

# compare_shapes <snapshot file> <current shapes json>: events seen in both runs
# must match field for field. Events seen in only one run are reported, not failed,
# because a scenario that failed earlier may not have reached them.
compare_shapes() {
    local snap="$1" cur="$2" diffs
    if [ ! -f "$snap" ]; then
        skip "hook input shapes (no snapshot yet: run with --record)"
        return
    fi
    diffs=$(jq -rn --slurpfile s "$snap" --argjson c "$cur" '
        $s[0] as $s
        | ($s | keys) as $sk | ($c | keys) as $ck
        | ($sk - $ck | map("not reached this run: " + .))[],
          ($ck - $sk | map("new event: " + .))[],
          (($sk - ($sk - $ck))[] as $e
           | ($s[$e] | keys) as $sf | ($c[$e] | keys) as $cf
           | (($sf - $cf)[] | "\($e): field gone: \(.)"),
             (($cf - $sf)[] | "\($e): new field: \(.)"),
             (($sf - ($sf - $cf))[] | select($s[$e][.] != $c[$e][.])
              | "\($e): \(.) was \($s[$e][.] | join("|")), now \($c[$e][.] | join("|"))"))')
    if printf '%s\n' "$diffs" | grep -q -E ': (field gone|new field|.* was )'; then
        fail "hook input shapes match the snapshot" "$diffs"
    else
        pass "hook input shapes match the snapshot"
        [ -n "$diffs" ] && printf '%s\n' "$diffs" | sed 's/^/           note: /'
    fi
}
