# WezTerm shell integration for fish shell.
# Sends current process name as WEZTERM_PROG user var via OSC 1337.
#
# Install:
#   mkdir -p ~/.config/fish/conf.d
#   cp wezterm-shell-integration.fish ~/.config/fish/conf.d/
# Then start a new fish session.

function __wezterm_set_user_var --argument-names name value
    # base64-encode the value (no newlines)
    set -l b64 (printf '%s' "$value" | base64 | tr -d '\n')

    if set -q TMUX
        # Wrap in tmux passthrough so the OSC reaches the outer terminal.
        # Requires `set -g allow-passthrough on` in ~/.tmux.conf (tmux 3.3+).
        printf '\ePtmux;\e\e]1337;SetUserVar=%s=%s\a\e\\' $name $b64
    else
        printf '\e]1337;SetUserVar=%s=%s\a' $name $b64
    end
end

# Before each prompt: report the shell itself ("fish") and the current git
# repository root. The root is computed here, inside WSL/over SSH, where git
# and the filesystem actually live; the terminal reads it as a user var and
# colors tabs per-repo. Empty (sent as an empty value) when not in a repo, so
# the terminal falls back to coloring by cwd.
function __wezterm_report_shell --on-event fish_prompt
    __wezterm_set_user_var WEZTERM_PROG fish
    __wezterm_set_user_var WEZTERM_GIT_ROOT (command git rev-parse --show-toplevel 2>/dev/null)
end

# Before each command: report the command being executed.
function __wezterm_report_cmd --on-event fish_preexec --argument-names cmdline
    # cmdline is the full command line. Strip leading env assignments
    # (e.g. "FOO=bar baz arg" -> "baz arg") by skipping tokens with '='.
    set -l tokens (string split ' ' -- $cmdline)
    set -l first ''
    for tok in $tokens
        if test -z "$tok"
            continue
        end
        # Skip env-var assignments like FOO=bar
        if string match -qr '^[A-Za-z_][A-Za-z0-9_]*=' -- $tok
            continue
        end
        set first $tok
        break
    end

    if test -z "$first"
        return
    end

    # Strip path: /usr/bin/vim -> vim
    set first (string replace -r '^.*/' '' -- $first)

    __wezterm_set_user_var WEZTERM_PROG $first
end
