# Claude Code adapter for tests/run. The working copy loads with --plugin-dir.
#
# Discovery uses a throwaway CLAUDE_CONFIG_DIR: the init event lists plugins,
# skills and MCP servers before the login check, so it needs no account. Live
# runs need the real login, so they use the real config dir with only project
# settings, which leaves out user-installed plugins (an installed cloudfleet
# included) and user hooks.

H_MODEL=${CLAUDE_TEST_MODEL:-haiku}
H_MCP_PREFIX=mcp__plugin_cloudfleet_cloudfleet__
H_PROMPT_EVENT=UserPromptSubmit
H_FAIL_EVENT=PostToolUseFailure
H_HOOK_FILE=hooks/hooks.json

h_available() { command -v claude >/dev/null 2>&1; }
h_version() { claude --version 2>/dev/null | awk '{print $1}'; }

_init() {
    [ -f "$WORK/claude-init.json" ] && return 0
    (cd "$PROJECT" && CLAUDE_CONFIG_DIR="$WORK/claude-home" claude -p --max-turns 1 --model "$H_MODEL" \
        --plugin-dir "$REPO" --output-format stream-json --verbose "Reply with just: ok" </dev/null 2>/dev/null) |
        jq -R -c 'fromjson? | select(.type == "system" and .subtype == "init")' >"$WORK/claude-init.json"
}

# claude exits non-zero here ("Not logged in"), so success is the captured event.
h_setup() { mkdir -p "$WORK/claude-home" && { _init; [ -s "$WORK/claude-init.json" ]; }; }
h_live_setup() { :; }

h_skills() { jq -r '.skills[] | select(startswith("cloudfleet:"))' "$WORK/claude-init.json"; }
h_expected_skills() { invocable_skills; }

h_mcp_servers() {
    jq -r '.mcp_servers[] | select(.source == "plugin" and .status == "connected") | .name | sub("^plugin:cloudfleet:"; "")' "$WORK/claude-init.json"
}

# The init event does not list hooks; the live scenarios show they fire.
h_hooks() { return 1; }

_run() {
    (cd "$PROJECT" && claude -p "$@" --model "$H_MODEL" --setting-sources project --plugin-dir "$REPO" \
        --allowedTools 'Bash(cloudfleet:*)' "${H_MCP_PREFIX%__}" \
        --disallowedTools "${H_MCP_PREFIX}feedback_send" 'Bash(cloudfleet feedback:*)' \
        --output-format stream-json --verbose </dev/null) >>"$WORK/transcript.jsonl" 2>>"$WORK/stderr.txt"
}

h_prompt() { _run "$1"; }

h_resume() {
    local id
    id=$(jq -r 'select(.type == "system" and .subtype == "init") | .session_id' "$WORK/transcript.jsonl" | tail -n 1)
    _run --resume "$id" "$1"
}

# Used by tests/uninstall, against the real config dir unless CLAUDE_CONFIG_DIR is set.
h_status() {
    claude plugin list 2>/dev/null | grep -A2 -F 'cloudfleet@' | sed 's/^/plugin: /'
    claude plugin marketplace list 2>/dev/null | grep -i -A1 'cloudfleet' | grep -v '^[[:space:]]*$' | sed 's/^/marketplace: /'
}
h_uninstall() {
    local scope
    for scope in user project local; do
        claude plugin uninstall cloudfleet@cloudfleet --scope "$scope" >/dev/null 2>&1
    done
    claude plugin marketplace remove cloudfleet >/dev/null 2>&1
    return 0
}
