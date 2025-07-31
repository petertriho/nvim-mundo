# nvim-mundo

> [!CAUTION]
> This plugin was generated with the help of AI. It is a proof-of-concept and is not actively maintained. No support will be provided.

A Lua rewrite of the [vim-mundo](https://github.com/simnalamburt/vim-mundo) plugin for Neovim. Visualizes the Vim undo tree in a graphical format with proper tree visualization and unified diff support.

## Features

- **Undo tree visualization**: See your undo history as a branching tree with vertical lines
- **Interactive navigation**: Move through undo states with keyboard shortcuts
- **Live preview**: See unified diffs of changes as you navigate
- **Proper diff format**: LCS-based unified diff with context lines and @@ headers
- **Search functionality**: Find specific changes in your undo history
- **Playback mode**: Replay changes step by step
- **Pure Lua**: No Python dependencies required
- **Fixed focus issues**: Cursor stays in target buffer, no auto-jumping to Mundo window

## Installation

### Using Lazy.nvim

```lua
{
  "petertriho/nvim-mundo",
  cmd = { "MundoToggle", "MundoShow", "MundoHide" },
  keys = {
    { "<leader>u", "<CMD>MundoToggle<CR>", desc = "Toggle Mundo Undo Tree" },
  },
  config = function()
    require('mundo').setup({
      -- Your configuration here
    })
  end,
}
```

### Using other plugin managers

Add the plugin directory to your plugin manager configuration.

## Usage

### Commands

- `:MundoToggle` - Toggle the Mundo window
- `:MundoShow` - Show the Mundo window
- `:MundoHide` - Hide the Mundo window

### Default Key Mappings (in Mundo window)

- `<CR>/o` - Preview/revert to selected state
- `j/<down>` - Move to next/older undo state
- `k/<up>` - Move to previous/newer undo state
- `J` - Move to next/older write state
- `K` - Move to previous/newer write state
- `gg` - Move to top of undo tree
- `G` - Move to bottom of undo tree
- `P` - Play changes to selected state
- `d` - Show diff in vertical split
- `i` - Toggle inline diff mode
- `/` - Search for changes
- `n/N` - Next/previous search match
- `p` - Show diff with current buffer
- `r` - Show diff (same as `d`)
- `?` - Toggle help
- `q/<Esc>/<C-c>` - Quit Mundo
- `<2-LeftMouse>` - Mouse click to select state
- `<Tab>/<C-w>p` - Return to target buffer

## Configuration

nvim-mundo supports the same configuration variables as the original vim-mundo via `vim.g` variables, plus Lua-style setup configuration:

### Using vim.g variables (original vim-mundo compatibility)

```vim
" Window layout
let g:mundo_width = 45                     " Width of the Mundo window
let g:mundo_preview_height = 15            " Height of the preview window
let g:mundo_preview_bottom = 0             " Show preview at bottom (1) or right (0)
let g:mundo_right = 0                      " Show Mundo on right side (1) or left (0)

" Display options
let g:mundo_help = 0                       " Show help by default (1) or not (0)
let g:mundo_disable = 0                    " Disable the plugin (1) or enable (0)
let g:mundo_header = 1                     " Show header in graph window (1) or not (0)
let g:mundo_verbose_graph = 1              " Show detailed graph (1) or simple (0)
let g:mundo_mirror_graph = 0               " Mirror the graph horizontally (1) or not (0)
let g:mundo_inline_undo = 0                " Show inline diffs in graph (1) or not (0)

" Behavior
let g:mundo_close_on_revert = 0            " Close Mundo after reverting (1) or not (0)
let g:mundo_return_on_revert = 1           " Return to original buffer after revert (1) or not (0)
let g:mundo_auto_preview = 1               " Auto-update preview when moving (1) or not (0)
let g:mundo_auto_preview_delay = 250       " Delay for auto-preview in milliseconds

" Playback and timing
let g:mundo_playback_delay = 60            " Delay between playback steps in milliseconds

" Status lines
let g:mundo_preview_statusline = "Mundo Preview"  " Statusline for preview window
let g:mundo_tree_statusline = "Mundo"             " Statusline for tree window

" Custom symbols for graph visualization
let g:mundo_symbols = {
    \ 'current': '@',                     " Symbol for current undo state
    \ 'node': 'o',                        " Symbol for regular undo states
    \ 'saved': 'w',                       " Symbol for saved/written states
    \ 'vertical': '|'                     " Symbol for vertical tree lines
    \ }

" Custom mappings (dictionary) - all original vim-mundo mappings
let g:mundo_mappings = {
    \ '<CR>': 'preview',
    \ 'o': 'preview',
    \ 'j': 'move_older',
    \ 'k': 'move_newer',
    \ '<down>': 'move_older',
    \ '<up>': 'move_newer',
    \ 'J': 'move_older_write',
    \ 'K': 'move_newer_write',
    \ 'gg': 'move_top',
    \ 'G': 'move_bottom',
    \ 'P': 'play_to',
    \ 'd': 'diff',
    \ 'i': 'toggle_inline',
    \ '/': 'search',
    \ 'n': 'next_match',
    \ 'N': 'previous_match',
    \ 'p': 'diff_current_buffer',
    \ 'r': 'diff',
    \ '?': 'toggle_help',
    \ 'q': 'quit',
    \ '<2-LeftMouse>': 'mouse_click'
    \ }
```

### Using Lua setup (modern Neovim style)

```lua
require("mundo").setup({
    -- Window positioning
    width = 45,                    -- Graph window width
    preview_height = 15,           -- Preview window height
    preview_bottom = false,        -- Preview window at bottom
    right = false,                 -- Open on right side

    -- Display options
    help = false,                  -- Show help by default
    disable = false,               -- Disable the plugin
    header = true,                 -- Show header
    verbose_graph = true,          -- Show detailed graph
    mirror_graph = false,          -- Mirror the graph horizontally
    inline_undo = false,           -- Show inline diffs

    -- Behavior
    close_on_revert = false,       -- Close after reverting
    return_on_revert = true,       -- Return to original buffer after revert
    auto_preview = true,           -- Auto-update preview
    auto_preview_delay = 250,      -- Delay for auto-preview (ms)

    -- Playback
    playback_delay = 60,           -- Delay between playback steps (ms)

    -- Status lines
    preview_statusline = "Mundo Preview",  -- Preview window statusline
    tree_statusline = "Mundo",             -- Tree window statusline

    -- Custom symbols for graph visualization
    symbols = {
        current = "@",                 -- Symbol for current undo state
        node = "o",                    -- Symbol for regular undo states  
        saved = "w",                   -- Symbol for saved/written states
        vertical = "|",                -- Symbol for vertical tree lines
    },

    -- Navigation (internal settings)
    map_move_newer = "k",          -- Key to move to newer undo
    map_move_older = "j",          -- Key to move to older undo
    map_up_down = true,            -- Use arrow keys for navigation

    -- Custom mappings (all original vim-mundo mappings supported)
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
})
```

### Configuration precedence

Configuration is applied in this order (later overrides earlier):
1. Default values
2. Lua `setup()` options (for modern Neovim configuration)
3. `vim.g` variables (highest precedence, matching original vim-mundo behavior)

This allows you to set baseline configuration with `setup()` and override specific options with `vim.g` variables, just like the original vim-mundo plugin.

## Symbol Customization

nvim-mundo allows you to customize the symbols used in the undo tree visualization:

### Default Symbols

- `@` - Current undo state (where you are now)
- `o` - Regular undo states  
- `w` - Saved/written states (states where you saved the file)
- `|` - Vertical tree lines connecting undo states

### Custom Symbol Examples

#### Using vim.g variables:
```vim
let g:mundo_symbols = {
    \ 'current': '★',
    \ 'node': '●',
    \ 'saved': '■',
    \ 'vertical': '│'
    \ }
```

#### Using Lua setup:
```lua
require("mundo").setup({
    symbols = {
        current = "★",        -- Current state
        node = "●",           -- Regular states
        saved = "■",          -- Saved states  
        vertical = "│",       -- Tree lines
    }
})
```

#### Unicode Examples:
```lua
-- Fancy Unicode symbols
symbols = {
    current = "→",         -- Arrow for current
    node = "◦",            -- Hollow circle for nodes
    saved = "◾",          -- Black square for saves
    vertical = "┆",        -- Dashed vertical line
}

-- Emoji symbols (fun but may affect alignment)
symbols = {
    current = "🔥",        -- Fire for current
    node = "⚪",           -- White circle for nodes  
    saved = "💾",          -- Floppy disk for saves
    vertical = "┃",        -- Thick vertical line
}

-- ASCII alternatives
symbols = {
    current = "C",         -- Simple letter
    node = "n",            -- Simple letter
    saved = "S",           -- Simple letter  
    vertical = "I",        -- Capital I
}
```

#### Partial Customization:
You can customize just some symbols while keeping others as defaults:

```lua
require("mundo").setup({
    symbols = {
        current = "🎯",      -- Only change current symbol
        -- node, saved, vertical remain default (@, o, w, |)
    }
})
```

## Differences from vim-mundo

This Lua implementation provides the core functionality of vim-mundo with some differences:

### Advantages

- **No Python dependency**: Pure Lua implementation
- **Better Neovim integration**: Uses modern Neovim APIs
- **Proper unified diff**: LCS-based diff algorithm with context lines
- **Fixed focus issues**: No unwanted cursor jumping between windows
- **Tree visualization**: Vertical lines connecting undo states like original Mundo
- **Modular architecture**: Clean separation of concerns for maintainability
- **Type annotations**: Full lua-language-server support with @class, @param, @return annotations
- **Simpler codebase**: Easier to understand and modify
- **Local configuration**: Easy to customize in your dotfiles

### Limitations

- **Simplified branching**: Complex branching scenarios may not be fully visualized
- **Missing advanced features**: Some edge cases and advanced features from the original may not be implemented

## API

```lua
local mundo = require("mundo")

-- Setup with custom configuration
mundo.setup({
    width = 50,
    auto_preview = false,
})

-- Programmatic control
mundo.show() -- Show Mundo
mundo.hide() -- Hide Mundo
mundo.toggle() -- Toggle Mundo
mundo.move(1) -- Move down in tree
mundo.move(-1) -- Move up in tree
mundo.preview() -- Preview/revert to current state
mundo.diff() -- Show diff in split
```

## Recent Improvements

- **Fixed cursor focus issues**: Cursor no longer auto-jumps back to Mundo window
- **Proper tree visualization**: Added vertical lines (`|`) between undo states like original Mundo
- **Enhanced navigation**: j/k keys now skip vertical lines and jump directly between nodes
- **Unified diff format**: Implemented LCS-based diff algorithm with proper @@ headers and context lines
- **Better syntax highlighting**: Uses 'diff' filetype for proper syntax highlighting in preview
- **Modular refactor**: Broke down 1184-line monolith into 8 focused modules for better maintainability
- **Type annotations**: Added comprehensive lua-language-server type annotations for better IDE support
- **Unit tests**: Comprehensive test suite with 58+ tests covering all modules
- **Configurable symbols**: Customize tree symbols (@, o, w, |) for personalized visualization

## Testing

The plugin includes a comprehensive test suite with tests covering all modules:

### Running Tests

```bash
# Run all tests
nvim --headless -l test.lua

# Or use the Makefile
make test

# Run specific test modules
make test-config      # Config module tests
make test-utils       # Utils module tests
make test-node        # Node module tests
make test-tree        # Tree module tests
make test-graph       # Graph module tests
make test-symbols     # Symbol configuration tests
make test-integration # Integration tests
```

### Test Structure

- **`tests/test_framework.lua`**: Custom test framework with assertions
- **`tests/test_config.lua`**: Configuration module tests
- **`tests/test_utils.lua`**: Utility functions tests
- **`tests/test_node.lua`**: Node structure tests
- **`tests/test_tree.lua`**: Tree data and diff algorithm tests
- **`tests/test_graph.lua`**: Graph rendering tests  
- **`tests/test_symbols.lua`**: Symbol configuration tests
- **`tests/test_integration.lua`**: Integration and API tests

### Test Features

- **Assertion library**: `equals`, `not_equals`, `is_true`, `is_false`, `is_nil`, `contains`, `throws`
- **Test organization**: Grouped tests with setup/teardown support
- **Mocking**: Vim API mocking for headless testing
- **Performance tracking**: Test execution time measurement
- **Detailed reporting**: Clear pass/fail status with error messages

## Requirements

- Neovim 0.7+
- `undofile` enabled for persistent undo history (recommended)

## Recommended Vim Settings

```vim
" Enable persistent undo
set undofile
set undodir=~/.vim/undo
```

Or in Lua:

```lua
vim.opt.undofile = true
vim.opt.undodir = vim.fn.expand("~/.vim/undo")
```
