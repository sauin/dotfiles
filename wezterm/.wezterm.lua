-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action

local DOMAIN_THEMES = {
    -- ["SSH to dev_server"] = "Canvased Pastel (terminal.sexy)"
    -- ["SSH"] = "zenwritten_dark"
    ["SSH to dev_server"] = "Violet Light",
    ["SSH"] = "Vice Dark (base16)"
}

local process_icons = {
    ["bash"] = wezterm.nerdfonts.dev_terminal,
    ["cargo"] = wezterm.nerdfonts.dev_rust,
    ["cmd.exe"] = wezterm.nerdfonts.custom_windows,
    ["curl"] = wezterm.nerdfonts.md_arrow_down_box,
    ["docker"] = wezterm.nerdfonts.linux_docker,
    ["docker-compose"] = wezterm.nerdfonts.linux_docker,
    ["fish"] = wezterm.nerdfonts.fa_fish, -- md_fish,
    ["gh"] = wezterm.nerdfonts.dev_github,
    ["git"] = wezterm.nerdfonts.md_git,
    ["htop"] = wezterm.nerdfonts.cod_graph_line,
    ["lazydocker"] = wezterm.nerdfonts.linux_docker,
    ["lazygit"] = wezterm.nerdfonts.oct_git_compare,
    ["lua"] = wezterm.nerdfonts.seti_lua,
    ["make"] = wezterm.nerdfonts.seti_makefile,
    ["node"] = wezterm.nerdfonts.md_hexagon_outline,
    ["psql"] = wezterm.nerdfonts.custom_sqldeveloper,
    ["sudo"] = wezterm.nerdfonts.md_death_star,
    ["sqlite3"] = wezterm.nerdfonts.dev_sqlite,
    ["vim"] = wezterm.nerdfonts.custom_vim,
    ["tmux"] = wezterm.nerdfonts.cod_terminal_tmux,
    ["wget"] = wezterm.nerdfonts.md_arrow_down_box,
    ["wsl.exe"] = wezterm.nerdfonts.custom_windows,
    ["zsh"] = wezterm.nerdfonts.dev_terminal,
}

-- Processes for which we DO NOT prepend the icon and use pane.title as-is.
-- Useful for TUI apps that set a meaningful title themselves (e.g. Claude Code,
-- Codex showing task name with "*" indicator).
local process_no_format = {
    ["claude"] = true,
    ["codex"] = true,
}

-- Return the tab's current working directory
local function get_cwd(tab)
    local pane = tab.active_pane
    if not pane then
        return ""
    end
    local cwd = pane.current_working_dir
    if not cwd then
        return ""
    end
    return cwd.file_path or ""
end

-- Key used to derive a tab's color. Prefer the git repository root published
-- by the shell as the WEZTERM_GIT_ROOT user var (computed where git actually
-- runs -- locally, in WSL, or over SSH), so every pane in the same repo shares
-- one color. Fall back to the cwd when the pane is outside a repo or the shell
-- hasn't reported a root. Reads a user var only: synchronous, never yields.
local function get_color_key(tab)
    local pane = tab.active_pane
    local root = pane and pane.user_vars and pane.user_vars.WEZTERM_GIT_ROOT
    if root and root ~= "" then
        return root
    end
    return get_cwd(tab)
end

-- Remove all path components and return only the last value
local function remove_abs_path(path)
    return path:gsub("(.*[/\\])(.*)", "%2")
end

local function format_process(process_name)
    -- if process_name:find("kubectl") then
    --     process_name = "kubectl"
    -- end
    if not process_name or process_name == "" then
        return ""
    end
    local icon = process_icons[process_name]
    if icon then
        return icon .. " "
    end
    return string.format("[%s] ", process_name)
end

-- Try to determine the foreground process name for a pane.
-- Priority:
--   1. WEZTERM_PROG user var (set by shell helpers / some CLI tools, works over SSH).
--   2. pane.foreground_process_name (read by WezTerm from /proc, works locally and in WSL).
-- Returns a short process name (e.g. "vim") or nil.
local function get_pane_process(pane)
    local prog = pane.user_vars and pane.user_vars.WEZTERM_PROG
    if prog and prog ~= "" then
        -- WEZTERM_PROG may contain args / path, take the first token and strip path
        local first = prog:match("([^ ;]+)") or prog
        return remove_abs_path(first)
    end

    local fg = pane.foreground_process_name
    if fg and fg ~= "" then
        return remove_abs_path(fg)
    end

    return nil
end

-- Pretty format the tab title
local function format_title(tab)
    local apane = tab.active_pane
    local active_title = apane.title or ""
    local process_str = ""

    if apane.user_vars.WEZTERM_IN_TMUX == "1" then
        -- tmux mode: pane title looks like "[procname] rest of title"
        local inner_proc = active_title:match("^.*%[(.-)%] .*$")
        if inner_proc and inner_proc ~= "" then
            process_str = format_process(inner_proc)
            active_title = active_title:gsub(".*%[.-%] (.*)", "%1")
        end
        local tmux_icon = process_icons["tmux"] or "tmux"
        process_str = tmux_icon .. "  " .. process_str
    else
        local proc = get_pane_process(apane)
        process_str = format_process(proc)
    end

    local description = (active_title == "") and "!" or active_title
    return string.format("%s %s", process_str, description)
end

-- Returns manually set title (from `tab:set_title()` or `wezterm cli set-tab-title`)
-- or creates a new one
-- local function get_tab_title(tab)
--     local title = tab.tab_title
--     if title and #title > 0 then
--         return title
--     end
--     return format_title(tab)
-- end

-- Returns manually set title (from `tab:set_title()` or `wezterm cli set-tab-title`)
-- or creates a new one
local function get_tab_title(tab)
    local title = tab.tab_title
    if title and #title > 0 then
        return title
    end

    -- For processes in process_no_format, use pane.title as-is without
    -- prepending an icon or otherwise reformatting.
    local apane = tab.active_pane
    if apane then
        local proc = get_pane_process(apane)
        if proc and process_no_format[proc] then
            local raw = apane.title
            if raw and raw ~= "" then
                return raw
            end
        end
    end

    return format_title(tab)
end

-- Convert arbitrary strings to a unique hex color value
-- Based on: https://stackoverflow.com/a/3426956/3219667
local function string_to_color(str)
    -- Convert the string to a unique integer
    local hash = 0
    for i = 1, #str do
        hash = string.byte(str, i) + ((hash << 5) - hash)
    end

    -- Convert the integer to a pastel color. Hue spans the full circle, and
    -- saturation/lightness use wide bands too (driven by independent hash bits)
    -- so neighbouring repos differ on all three axes and stay easy to tell
    -- apart, while the high lightness floor keeps every tint soft and light.
    local hue = (hash & 0x1ff) / 512 * 360                       -- 0..360
    local saturation = 0.40 + ((hash >> 9) & 0xff) / 255 * 0.50  -- 0.40..0.90
    local lightness = 0.70 + ((hash >> 17) & 0x3f) / 63 * 0.20   -- 0.70..0.90
    return wezterm.color.from_hsla(hue, saturation, lightness, 1)
end

-- Determine if a tab has unseen output since last visited
local function has_unseen_output(tab)
    if not tab.is_active then
        for _, pane in ipairs(tab.panes) do
            if pane.has_unseen_output then
                return true
            end
        end
    end
    return false
end

-- On format tab title events, override the default handling to return a custom title
-- Docs: https://wezfurlong.org/wezterm/config/lua/window-events/format-tab-title.html
---@diagnostic disable-next-line: unused-local
wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
    local title = get_tab_title(tab)
    local color = string_to_color(get_color_key(tab))

    if not tab.is_active then
        return {
            -- { Attribute = { Intensity = "Bold" } },
            { Background = { Color = color } },
            { Foreground = { Color = "#282828" } },
            { Text = title },
        }
    end
    if has_unseen_output(tab) then
        return {
            { Foreground = { Color = "#d79921" } },
            { Text = title },
        }
    end
    return title
end)

-- This will hold the configuration.
local config = wezterm.config_builder()

config.ssh_backend = "Ssh2"

-- This is where you actually apply your config choices
config.initial_cols = 190
config.initial_rows = 42

config.font = wezterm.font(
    "Pragmata Pro Mono",
    -- "IosevkaTerm Nerd Font Mono",
    {
        weight = "Regular",
        stretch = "ExtraCondensed",
        style = "Normal",
    }
)
config.font_size = 11
config.bold_brightens_ansi_colors = "BrightOnly"
config.freetype_load_target = "Light"
config.freetype_render_target = 'HorizontalLcd'
config.freetype_load_flags = "NO_HINTING"
config.cell_width = 1.0
config.line_height = 1.0
config.default_cursor_style = 'BlinkingBlock'

config.harfbuzz_features = { 'frac=0', 'ss03=0', 'ss04=0', 'c2sc=0', 'calt' }

config.mouse_bindings = {
    {
        event = { Down = { streak = 1, button = "Right" } },
        mods = "NONE",
        action = act({ PasteFrom = "Clipboard" }),
        -- action = wezterm.action_callback(function(window, pane)
        --    local act = wezterm.action
        --    local has_selection = window:get_selection_text_for_pane(pane) ~= ""
        --    if has_selection then
        --        window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
        --        window:perform_action(act.ClearSelection, pane)
        --    else
        --        window:perform_action(act({ PasteFrom = "Clipboard" }), pane)
        --    end
        --end),
    },
}
--
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = true
-- For example, changing the color scheme:
-- config.color_scheme = 'Dracula (Gogh)'
-- config.color_scheme = 'Catppuccin Mocha'
-- config.color_scheme = 'Canvased Pastel (terminal.sexy)'
config.color_scheme = 'Chalk'
-- config.color_scheme = 'Chameleon (Gogh)'
-- config.color_scheme = 'Ciapre (Gogh)'

wezterm.on('update-status', function(window, pane)
    -- local domain_name = string.sub(pane:get_domain_name(), 1, 3)
    --
    local domain_name = pane:get_domain_name()

    local theme = "Chalk"
    if DOMAIN_THEMES[domain_name] then
        theme = DOMAIN_THEMES[domain_name]
    else
        local domain_head = string.sub(domain_name, 1, 3)
        if DOMAIN_THEMES[domain_head] then
            theme = DOMAIN_THEMES[domain_head]
        end
    end

    -- Применяем переопределение конфигурации для текущего окна
    window:set_config_overrides({
        color_scheme = theme,
    })
end)

config.colors = {
    -- the foreground color of selected text
    selection_fg = 'black',
    -- the background color of selected text
    selection_bg = '#fffacd',
    -- tab_bar = {
    --     inactive_tab_edge = "red",
    -- }
}

config.window_background_opacity = .98

config.keys = {
    -- Ctrl+Shift+V — вставка в терминал (стандартное поведение)
    -- {
    --  key = 'V',
    --  mods = 'CTRL|SHIFT',
    --  action = wezterm.action.PasteFrom 'Clipboard',
    --},
    -- Ctrl+V — пропускаем в приложение (Claude Code получит сигнал сам)
    {
        key = 'v',
        mods = 'SHIFT|CTRL',
        action = wezterm.action.SendKey { key = 'v', mods = 'CTRL' },
    },
    { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom 'Clipboard' },
    --{ key = 'v', mods = 'SHIFT|CTRL', action = wezterm.action_callback(function(window, pane)
    --  window:perform_action(wezterm.action.SendKey{ key='v', mods='CTRL' }, pane) end),
    --}
}

-- and finally, return the configuration to wezterm
return config
