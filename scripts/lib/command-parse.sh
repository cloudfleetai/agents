# Shell-command parsing for the feedback hook. Source it, do not run it.
#
# The goal is to tell an actual invocation of a tool apart from text that merely
# mentions it (prose, strings, document bodies), not to parse shell faithfully.

# Heredoc bodies are data, not commands. Dropping them keeps a tutorial, runbook,
# or commit message written with `cat > file <<EOF` from being scanned as if its
# contents were a command line. An unterminated heredoc swallows the rest of the
# input, which is the safe direction: less text scanned, never more.
strip_heredocs() {
    awk '
    function reset() { inhere = 0; term = ""; striptabs = 0 }
    BEGIN { reset() }
    {
        if (inhere) {
            line = $0
            if (striptabs) sub(/^\t+/, "", line)
            if (line == term) reset()
            next
        }
        # `<<<` is a herestring, not a heredoc: leave it for the quote pass.
        if (match($0, /<<-?[ \t]*("[^"]*"|\047[^\047]*\047|[A-Za-z_][A-Za-z0-9_]*)/) &&
            substr($0, RSTART + 2, 1) != "<") {
            tok = substr($0, RSTART, RLENGTH)
            striptabs = (substr(tok, 1, 3) == "<<-")
            sub(/^<<-?[ \t]*/, "", tok)
            gsub(/["\047]/, "", tok)
            term = tok
            inhere = 1
            print substr($0, 1, RSTART - 1)
            next
        }
        print
    }'
}

# Prints one simple command per line, in order, with its command word first:
# heredoc bodies dropped, quoted spans blanked, split on `|`, `;` and `&`, and
# leading `VAR=value` assignments and `sudo`/`command`/`env`/`time` removed.
# Quoted arguments are lost, so callers extract flag values from the original
# command string instead.
command_segments() {
    printf '%s' "$1" |
        strip_heredocs |
        sed -e "s/'[^']*'/ /g" -e 's/"[^"]*"/ /g' |
        tr '|;&' '\n\n\n' |
        sed -e 's/^[[:space:]]*//' |
        sed -E -e ':a' -e 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+//' -e 'ta' |
        sed -E 's/^(sudo|command|env|time)[[:space:]]+//'
}
