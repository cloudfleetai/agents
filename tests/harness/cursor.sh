# Cursor CLI (cursor-agent) adapter for tests/run.
#
# Plugin hooks run only for installed plugins (not --plugin-dir), and installing
# is interactive (/plugins in cursor-agent), so the tests need cloudfleet
# installed once from a marketplace. They back up Cursor's cached copy, sync
# the working copy over it, and restore it at the end. Cursor's login lives in
# the real home, so there is no isolation.
#
# A plugin's hooks get only postToolUse, for successful calls, so the live
# checks cover the sampled prompt, not failures or the next turn.

H_MODEL=${CURSOR_TEST_MODEL:-grok-4.7-medium}
H_MCP_PREFIX=MCP:
H_HOOK_FILE=hooks/cursor.json

h_available() { command -v cursor-agent >/dev/null 2>&1; }
h_version() { cursor-agent --version 2>/dev/null | head -n 1; }

_cache() { ls -dt "$HOME"/.cursor/plugins/cache/cloudfleet/cloudfleet/*/ 2>/dev/null | head -n 1; }

h_setup() {
    local cache
    cache=$(_cache)
    if [ -z "$cache" ]; then
        echo "  install cloudfleet once with /plugins in cursor-agent (from any cloudfleet marketplace)" >&2
        return 1
    fi
    CACHE=${cache%/}
    mkdir -p "$WORK/cursor-backup" "$PROJECT/.cursor"
    rsync -a "$CACHE/" "$WORK/cursor-backup/" &&
        rsync -a --delete --exclude .git --exclude .cache-complete "$REPO/" "$CACHE/" || return 1
    SYNCED=1
    # Project-scoped permissions, so the real ~/.cursor/cli-config.json is not touched.
    printf '%s\n' '{"permissions":{"allow":["Shell(cloudfleet)","Mcp(*:who_am_i)"],"deny":["Mcp(*:feedback_send)","Shell(cloudfleet feedback)"]}}' \
        >"$PROJECT/.cursor/cli.json"
    _run "Without running any tools: list the exact names of every skill and every MCP tool available to you that relates to Cloudfleet, one per line, prefixed with skill: or tool:."
}
h_teardown() { [ "${SYNCED:-0}" = 1 ] && rsync -a --delete "$WORK/cursor-backup/" "$CACHE/"; return 0; }
h_live_setup() { :; }

_run() {
    (cd "$PROJECT" && cursor-agent -p --trust --approve-mcps --model "$H_MODEL" "$1" </dev/null) >>"$WORK/transcript.txt" 2>&1
}

h_skills() { grep -oE 'skill: *[a-z-]+' "$WORK/transcript.txt" | sed 's/skill: */cloudfleet:/' | sort -u; }
h_expected_skills() { all_skills; }
h_mcp_servers() { grep -qE 'tool: *.*who_am_i' "$WORK/transcript.txt" && echo cloudfleet; }
h_hooks() { return 1; }

h_live() {
    echo "Live ($H_MODEL; a plugin's hooks get only postToolUse for successful calls):"
    CLOUDFLEET_FEEDBACK_ROLL=99 _run "Call the cloudfleet MCP tool who_am_i once. Do not send feedback and do not ask about it. Then reply with just: done"
    check "MCP call reaches the hooks" "log_has '.input.tool_name == \"MCP:who_am_i\"'"
    check "successful call, roll above the rate: no prompt" "! log_has '.output != null'"
    CLOUDFLEET_FEEDBACK_ROLL=0 _run "Run the shell command \`cloudfleet --version\` once. Do not send feedback and do not ask about it. Then reply with just: done"
    check "successful cloudfleet command, roll under the rate: prompt" \
        "log_has '.input.tool_name == \"Shell\" and (.output | tojson | contains(\"Assess the Cloudfleet MCP tool or CLI command\"))'"
    shapes_step cursor
}

# Used by tests/uninstall. Cursor has no command that uninstalls a plugin, so
# the installed copy is reported and left for /plugins.
h_status() {
    cursor-agent plugin marketplace list 2>/dev/null | awk '$1 == "cloudfleet" {print "marketplace: " $0}'
    [ -n "$(_cache)" ] && echo "plugin: installed (remove it with /plugins in cursor-agent)"
    return 0
}
h_uninstall() { cursor-agent plugin marketplace remove cloudfleet >/dev/null 2>&1; return 0; }
