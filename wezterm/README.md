# wezterm

WezTerm configuration with **per-git-repo tab coloring**: every tab is tinted by
its current git repository root, so all panes in the same repo share one color
(subdirectories included). Outside a repo it falls back to coloring by cwd.

## What's here

| File | Purpose | Installs to |
|---|---|---|
| `.wezterm.lua` | WezTerm config. Reads the repo root from the `WEZTERM_GIT_ROOT` user var and colors tabs by it. | Windows home: `C:\Users\<user>\.wezterm.lua` *(this setup runs WezTerm on Windows, shells in WSL)* |
| `wezterm-shell-integration.fish` | fish hook that publishes `WEZTERM_PROG` and `WEZTERM_GIT_ROOT` to WezTerm via OSC 1337. **Required** — the Lua side only reads them. | `~/.config/fish/conf.d/` (inside WSL) |
| `deploy.sh` | Copies both files to the locations above (auto-detects the Windows home). | — |

## Install

```sh
./deploy.sh
```

Then open a **new** tab. Already-open fish shells don't reload `conf.d`
automatically — in each, run once:

```fish
source ~/.config/fish/conf.d/wezterm-shell-integration.fish
```

## Why a shell hook (and not pure Lua)

WezTerm runs on Windows while the shells run in WSL, so WezTerm can't walk the
WSL filesystem to find `.git`. The shell instead computes the repo root where
git actually runs (`git rev-parse --show-toplevel`) and sends it to WezTerm as
a user var. This is also why `wezterm.glob` is **not** used in `format-tab-title`
— it's async and that event runs outside a coroutine, so it throws
`attempt to yield from outside a coroutine`.

## Dependencies (on the target machine)

- `git`, `base64` (coreutils), `fish`.
- Inside **tmux**: `set -g allow-passthrough on` in your tmux config (tmux 3.3+),
  or the OSC sequence won't reach WezTerm.
- Font `Pragmata Pro Mono` + a Nerd Font for the configured glyphs and icons.
