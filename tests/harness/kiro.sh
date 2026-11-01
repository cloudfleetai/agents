# Kiro CLI adapter for tests/run.
#
# The power is .kiro-power/ (a plugin.json, mcp.json and a skills symlink), since
# a root plugin.json would break other harnesses. Kiro keeps the symlink, so an
# install from the working copy stays live. Powers carry no hooks, and only the
# V3 engine (`--v3`) loads plugin-format powers, so the live check covers skills
# and MCP on V3 instead of the feedback hook scenarios.
#
# Kiro's login and powers live in the real home, so tests install there,
# refuse to start when a cloudfleet power is already installed, and uninstall
# at the end.

H_MODEL=${KIRO_TEST_MODEL:-qwen3-coder-next}
H_HOOK_FILE=none

h_available() { command -v kiro-cli >/dev/null 2>&1; }
h_version() { kiro-cli --version 2>/dev/null | awk '{print $NF}'; }

_installed() { jq -e 'any(.installedPowers[]?; .name == "cloudfleet")' "$HOME/.kiro/powers/installed.json" >/dev/null 2>&1; }
_dir() { echo "$HOME/.kiro/powers/installed/cloudfleet"; }

h_setup() {
    if _installed; then
        echo "  a cloudfleet power is already installed in Kiro; run tests/uninstall kiro first" >&2
        return 1
    fi
    kiro-cli powers install "$REPO/.kiro-power" >/dev/null 2>&1 && _installed && INSTALLED_BY_TESTS=1
}
h_teardown() { [ "${INSTALLED_BY_TESTS:-0}" = 1 ] && kiro-cli powers uninstall cloudfleet >/dev/null 2>&1; return 0; }

h_skills() { for d in "$(_dir)"/skills/*/; do [ -f "$d/SKILL.md" ] && echo "cloudfleet:$(basename "$d")"; done; }
h_expected_skills() { all_skills; }
h_mcp_servers() { jq -r '.mcpServers | keys[]' "$(_dir)/mcp.json" 2>/dev/null; }
h_hooks() { return 1; }

_chat() {
    (cd "$PROJECT" && kiro-cli chat --v3 --no-interactive --model "$H_MODEL" --trust-tools kiro_powers "$1" </dev/null) \
        >>"$WORK/transcript.txt" 2>&1
}

h_live() {
    echo "Live ($H_MODEL, V3; Kiro powers carry no hooks):"
    _chat "Without running any tools: list the exact names of every skill available to you that relates to Cloudfleet, one per line, prefixed with skill:."
    local missing=""
    for s in $(all_skills | sed 's/^cloudfleet://'); do
        grep -q "skill: *$s" "$WORK/transcript.txt" || missing="$missing $s"
    done
    check "V3 lists the skills${missing:+ (missing:$missing)}" '[ -z "$missing" ]'
    _chat "Call the Cloudfleet MCP tool who_am_i once. Do not run shell commands. Then reply with just: done"
    check "V3 activates the power and calls an MCP tool" \
        'grep -A3 -F "@cloudfleet/cloudfleet/who_am_i" "$WORK/transcript.txt" | grep -q "status: Completed"'
}

# Used by tests/uninstall.
h_status() { _installed && echo "power: cloudfleet at $(_dir)"; return 0; }
h_uninstall() { kiro-cli powers uninstall cloudfleet >/dev/null 2>&1; return 0; }
