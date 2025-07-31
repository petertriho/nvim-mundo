-- Configuration module for nvim-mundo
local M = {}

---@class MundoSymbols
---@field current string Symbol for current undo state (default: "@")
---@field node string Symbol for regular undo states (default: "o")
---@field saved string Symbol for saved/written states (default: "w")
---@field vertical string Symbol for vertical tree lines (default: "|")

---@class MundoConfig
---@field width number Width of graph window (mundo_width)
---@field preview_height number Height of preview window (mundo_preview_height)
---@field preview_bottom boolean Show preview window at bottom (mundo_preview_bottom)
---@field right boolean Open Mundo on right side (mundo_right)
---@field help boolean Show help by default (mundo_help)
---@field disable boolean Disable Mundo plugin (mundo_disable)
---@field mappings table<string, string> Key mappings for Mundo window (mundo_mappings)
---@field close_on_revert boolean Close Mundo after reverting to a state (mundo_close_on_revert)
---@field preview_statusline string Statusline for preview window (mundo_preview_statusline)
---@field tree_statusline string Statusline for tree window (mundo_tree_statusline)
---@field auto_preview boolean Auto-update preview when moving (mundo_auto_preview)
---@field auto_preview_delay number Delay for auto-preview in milliseconds (mundo_auto_preview_delay)
---@field verbose_graph boolean Show detailed graph (mundo_verbose_graph)
---@field playback_delay number Delay between playback steps in milliseconds (mundo_playback_delay)
---@field mirror_graph boolean Mirror the graph horizontally (mundo_mirror_graph)
---@field inline_undo boolean Show inline diffs in the graph (mundo_inline_undo)
---@field return_on_revert boolean Return to original buffer after revert (mundo_return_on_revert)
---@field header boolean Show header in graph window (mundo_header)
---@field map_move_newer string Key to move to newer undo state
---@field map_move_older string Key to move to older undo state
---@field map_up_down boolean Use arrow keys for navigation
---@field autorefresh boolean Enable automatic tree refresh on buffer events (mundo_autorefresh)
---@field autorefresh_events table<string> List of events that trigger autorefresh (mundo_autorefresh_events)
---@field symbols MundoSymbols Configurable symbols for graph rendering (mundo_symbols)

-- Default configuration
---@type MundoConfig
M.defaults = {
    width = 45,
    preview_height = 15,
    preview_bottom = false,
    right = false,
    help = false,
    disable = false,
    mappings = {
        ["<CR>"] = "preview",
        ["o"] = "preview",
        ["j"] = "move_older",
        ["k"] = "move_newer",
        ["<down>"] = "move_older",
        ["<up>"] = "move_newer",
        ["J"] = "move_older_write",
        ["K"] = "move_newer_write",
        ["gg"] = "move_top",
        ["G"] = "move_bottom",
        ["P"] = "play_to",
        ["d"] = "diff",
        ["i"] = "toggle_inline",
        ["/"] = "search",
        ["n"] = "next_match",
        ["N"] = "previous_match",
        ["p"] = "diff_current_buffer",
        ["r"] = "diff",
        ["?"] = "toggle_help",
        ["q"] = "quit",
        ["<2-LeftMouse>"] = "mouse_click",
    },
    close_on_revert = false,
    preview_statusline = "Mundo Preview",
    tree_statusline = "Mundo",
    auto_preview = true,
    auto_preview_delay = 250,
    verbose_graph = true,
    playback_delay = 60,
    mirror_graph = false,
    inline_undo = false,
    return_on_revert = true,
    header = true,
    map_move_newer = "k",
    map_move_older = "j",
    map_up_down = true,
    autorefresh = true,
    autorefresh_events = { "BufRead", "BufNewFile", "BufWritePost" },
    symbols = {
        current = "@",
        node = "o",
        saved = "w",
        vertical = "|",
    },
}

-- Current configuration (will be merged with user options)
---@type MundoConfig
M.current = {}

-- Setup configuration with user options
---@param opts? MundoConfig User configuration options
---@return MundoConfig config The merged configuration
function M.setup(opts)
    -- Start with defaults
    local config = vim.deepcopy(M.defaults)

    -- Apply user-provided options first
    config = vim.tbl_deep_extend("force", config, opts or {})

    -- vim.g variables have highest precedence (matching original vim-mundo)
    local vim_g_mappings = {
        mundo_width = "width",
        mundo_preview_height = "preview_height",
        mundo_preview_bottom = "preview_bottom",
        mundo_right = "right",
        mundo_help = "help",
        mundo_disable = "disable",
        mundo_mappings = "mappings",
        mundo_close_on_revert = "close_on_revert",
        mundo_preview_statusline = "preview_statusline",
        mundo_tree_statusline = "tree_statusline",
        mundo_auto_preview = "auto_preview",
        mundo_auto_preview_delay = "auto_preview_delay",
        mundo_verbose_graph = "verbose_graph",
        mundo_playback_delay = "playback_delay",
        mundo_mirror_graph = "mirror_graph",
        mundo_inline_undo = "inline_undo",
        mundo_return_on_revert = "return_on_revert",
        mundo_header = "header",
        mundo_autorefresh = "autorefresh",
        mundo_autorefresh_events = "autorefresh_events",
        mundo_symbols = "symbols",
    }

    -- Apply vim.g settings with highest precedence
    for vim_var, config_key in pairs(vim_g_mappings) do
        if vim.g[vim_var] ~= nil then
            config[config_key] = vim.g[vim_var]
        end
    end

    M.current = config

    -- Add default move mappings to config.mappings
    M.current.mappings[M.current.map_move_older] = "move_older"
    M.current.mappings[M.current.map_move_newer] = "move_newer"

    return M.current
end

-- Get current configuration
---@return MundoConfig config The current configuration
function M.get()
    return M.current
end

-- Get specific config value
---@param key string The configuration key
---@return any value The configuration value
function M.get_value(key)
    return M.current[key]
end

return M
