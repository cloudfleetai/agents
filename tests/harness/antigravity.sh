# Antigravity CLI adapter for tests/run.
#
# Antigravity cannot be isolated: its login is in the macOS keychain, which is
# found through HOME. So tests install into the real ~/.gemini/config/plugins
# and uninstall at the end, and refuse to start when a cloudfleet plugin is
# already installed (tests/uninstall antigravity removes it).
#
# `agy plugin install` imports the Claude manifest and copies hooks/hooks.json
# to the plugin root, where Antigravity reads it as one named hook ("hooks").

H_MODEL=${ANTIGRAVITY_TEST_MODEL:-gemini-3.8-flash-low}
H_MCP_PREFIX=cloudfleet_cloudfleet
H_PROMPT_EVENT=PreInvocation
H_FAIL_EVENT=PreInvocation
H_HOOK_FILE=hooks/hooks.json

h_available() { command -v agy >/dev/null 2>&1; }
h_version() { agy --version 2>/dev/null | head -n 1; }

_installed() { agy plugin list --json 2>/dev/null | jq -e 'any(.[]; .name == "cloudfleet")' >/dev/null; }

h_setup() {
    if _installed; then
        echo "  cloudfleet is already installed in Antigravity; run tests/uninstall antigravity first" >&2
        return 1
    fi
    agy plugin install "$REPO" >/dev/null 2>&1 && _installed && INSTALLED_BY_TESTS=1
}
h_teardown() { [ "${INSTALLED_BY_TESTS:-0}" = 1 ] && agy plugin uninstall cloudfleet >/dev/null 2>&1; return 0; }
h_live_setup() { :; }

_plugin() { agy plugin list --json 2>/dev/null | jq -c '.[] | select(.name == "cloudfleet")'; }
h_skills() { _plugin | jq -r '.skills[] | "cloudfleet:" + .'; }
h_expected_skills() { all_skills; }
h_mcp_servers() { _plugin | jq -r '.mcpServers[]'; }

# The plugin list shows only the named hook; the live scenarios show it fires.
h_hooks() { return 1; }

# Headless mode denies tools without an allow rule. feedback_send and
# `cloudfleet feedback` are denied so a test run cannot send real feedback.
_SETTINGS='{"permissions":{"allow":["mcp(cloudfleet_cloudfleet/who_am_i)","command(cloudfleet clusters)"],"deny":["mcp(cloudfleet_cloudfleet/feedback_send)","command(cloudfleet feedback)"]}}'

_run() {
    (cd "$PROJECT" && agy "$@" --model "$H_MODEL" --settings "$_SETTINGS" --print-timeout 300s </dev/null) \
        >>"$WORK/transcript.txt" 2>&1
}

h_prompt() { _run -p "$1"; }
h_resume() { _run -c -p "$1"; }

# Used by tests/uninstall.
h_status() { _plugin | jq -r '"plugin: \(.name) \(.version) at \(.path)"'; }
h_uninstall() { agy plugin uninstall cloudfleet >/dev/null 2>&1; return 0; }
