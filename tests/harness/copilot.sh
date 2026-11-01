# Copilot CLI adapter for tests/run. Everything runs against a throwaway
# COPILOT_HOME; the login comes from the system keychain. A plugin from a local
# marketplace is loaded live from the working copy, not copied.
#
# --model is not passed: on accounts without the model picker it rejects every
# model, and the default routes to a cheap one (mai-code-1.1-flash, gpt-6-luna).

H_MODEL=default
H_MCP_PREFIX=cloudfleet-
H_PROMPT_EVENT=userPromptSubmitted
H_FAIL_EVENT=postToolUse
H_HOOK_FILE=hooks/hooks.json

h_available() { command -v copilot >/dev/null 2>&1; }
h_version() { copilot --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1; }

h_setup() {
    export COPILOT_HOME="$WORK/copilot-home" COPILOT_AUTO_UPDATE=false
    mkdir -m 700 -p "$COPILOT_HOME"
    copilot plugin marketplace add "$REPO" >/dev/null 2>&1 &&
        copilot plugin install cloudfleet@cloudfleet >/dev/null 2>&1
}
h_live_setup() { :; }

h_skills() { copilot skill list --json 2>/dev/null | jq -r '.[] | select(.source == "plugin") | "cloudfleet:" + .name'; }
h_expected_skills() { all_skills; }
h_mcp_servers() { copilot mcp list --json 2>/dev/null | jq -r '.mcpServers | to_entries[] | select(.value.sourcePlugin == "cloudfleet") | .key'; }

# Copilot has no command that lists hooks; the live scenarios show they fire.
h_hooks() { return 1; }

_run() {
    (cd "$PROJECT" && copilot "$@" \
        --allow-tool='shell(cloudfleet:*)' --allow-tool=cloudfleet \
        --deny-tool='cloudfleet(feedback_send)' --deny-tool='shell(cloudfleet feedback)' \
        --output-format json </dev/null) >>"$WORK/transcript.jsonl" 2>>"$WORK/stderr.txt"
}

h_prompt() { _run -p "$1"; }
h_resume() { _run --continue -p "$1"; }

# Used by tests/uninstall, against ~/.copilot unless COPILOT_HOME is set.
h_status() {
    copilot plugin list 2>/dev/null | grep -A1 -F 'cloudfleet@' | sed 's/^/plugin: /'
    copilot plugin marketplace list 2>/dev/null | grep -i 'cloudfleet' | sed 's/^/marketplace: /'
}
h_uninstall() {
    copilot plugin uninstall cloudfleet@cloudfleet >/dev/null 2>&1
    copilot plugin marketplace remove cloudfleet >/dev/null 2>&1
    return 0
}
