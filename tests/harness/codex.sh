# Codex adapter for tests/run. Everything runs against a throwaway CODEX_HOME.

H_MODEL=${CODEX_TEST_MODEL:-gpt-6-luna}
H_MCP_PREFIX=mcp__cloudfleet__
H_PROMPT_EVENT=UserPromptSubmit
H_FAIL_EVENT=PostToolUse
H_HOOK_FILE=hooks/codex.json

h_available() { command -v codex >/dev/null 2>&1; }
h_version() { codex --version 2>/dev/null | awk '{print $NF}'; }

h_setup() {
    export CODEX_HOME="$WORK/codex-home"
    mkdir -m 700 -p "$CODEX_HOME"
    codex plugin marketplace add "$REPO" >/dev/null 2>&1 &&
        codex plugin add cloudfleet@cloudfleet --json 2>/dev/null | jq -e '.installedPath' >/dev/null
}

# Live runs reuse the real login. The copy lives in WORK, which tests/run deletes.
h_live_setup() {
    local auth="${REAL_CODEX_HOME:-$HOME/.codex}/auth.json"
    [ -f "$auth" ] || return 1
    (umask 077 && cp "$auth" "$CODEX_HOME/auth.json")
}

_rpc() {
    {
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"cloudfleet-tests","version":"0"}}}' \
            '{"jsonrpc":"2.0","method":"initialized"}'
        jq -cn --arg m "$1" --arg cwd "$PROJECT" '{jsonrpc: "2.0", id: 2, method: $m, params: {cwds: [$cwd]}}'
        sleep 3
    } | codex app-server 2>/dev/null | jq -c 'select(.id == 2) | .result.data[0]'
}

h_skills() { _rpc skills/list | jq -r '.skills[].name | select(startswith("cloudfleet:"))'; }
h_mcp_servers() { codex mcp list --json 2>/dev/null | jq -r '.[].name'; }
h_expected_skills() { all_skills; }

# Prints "<event> <source file>" per discovered hook.
h_hooks() {
    _rpc hooks/list | jq -r '.hooks[] | select(.pluginId == "cloudfleet@cloudfleet")
        | "\(.eventName[0:1] | ascii_upcase)\(.eventName[1:]) \(.sourcePath | split("/") | .[-2:] | join("/"))"'
}

# `codex exec` refuses MCP calls that need approval, and plugin servers take no
# approval setting, so live runs add a same-named user server that approves its
# tools. The tool names and the hooks it triggers are the same as the plugin's.
# feedback_send is disabled, and the sandbox has no network for `cloudfleet
# feedback`, so a test run cannot send real feedback.
_exec() {
    (cd "$PROJECT" && codex exec "$@" --dangerously-bypass-hook-trust --skip-git-repo-check \
        -m "$H_MODEL" -c model_reasoning_effort='"low"' \
        -c 'mcp_servers.cloudfleet.command="cloudfleet"' -c 'mcp_servers.cloudfleet.args=["mcp"]' \
        -c 'mcp_servers.cloudfleet.default_tools_approval_mode="approve"' \
        -c 'mcp_servers.cloudfleet.disabled_tools=["feedback_send"]' </dev/null) >>"$WORK/transcript.txt" 2>&1
}

h_prompt() { _exec -s workspace-write "$1"; }
h_resume() { _exec resume --last "$1"; }

# Used by tests/uninstall, against ~/.codex unless CODEX_HOME is set. Also drops
# the stored hook trust, so the next install asks for it again.
h_status() {
    local config="${CODEX_HOME:-$HOME/.codex}/config.toml"
    codex plugin marketplace list 2>/dev/null | awk '$1 == "cloudfleet"' | sed 's/^/marketplace: /'
    [ -f "$config" ] && grep -F 'cloudfleet@cloudfleet' "$config" | sed 's/^/config.toml: /'
    [ -d "${CODEX_HOME:-$HOME/.codex}/plugins/cache/cloudfleet" ] && echo "cache: plugins/cache/cloudfleet"
    return 0
}
h_uninstall() {
    local config="${CODEX_HOME:-$HOME/.codex}/config.toml"
    codex plugin remove cloudfleet@cloudfleet >/dev/null 2>&1
    codex plugin marketplace remove cloudfleet >/dev/null 2>&1
    rm -rf "${CODEX_HOME:-$HOME/.codex}/plugins/cache/cloudfleet"
    [ -f "$config" ] || return 0
    awk '
        /^\[/ { skip = ($0 ~ /^\[(hooks\.state|plugins)\."cloudfleet@cloudfleet[":]/) }
        !skip
    ' "$config" >"$config.tmp" && mv "$config.tmp" "$config"
}
