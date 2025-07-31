-- Test configurable symbols functionality
local test = require("test_framework")

-- Setup test environment
package.path = package.path .. ";../lua/?.lua"

local config = require("mundo.config")

test.describe("Symbols Module", function()
    -- Reset config before each test
    config.current = {}
end)

test.it("should have default symbols", function()
    config.setup()
    local cfg = config.get()
    
    test.assert.equals(cfg.symbols.current, "@", "default current symbol should be @")
    test.assert.equals(cfg.symbols.node, "o", "default node symbol should be o")
    test.assert.equals(cfg.symbols.saved, "w", "default saved symbol should be w")
    test.assert.equals(cfg.symbols.vertical, "|", "default vertical symbol should be |")
end)

test.it("should allow custom symbols configuration", function()
    config.setup({
        symbols = {
            current = "★",
            node = "●",
            saved = "■",
            vertical = "│",
        }
    })
    
    local cfg = config.get()
    test.assert.equals(cfg.symbols.current, "★", "custom current symbol should be ★")
    test.assert.equals(cfg.symbols.node, "●", "custom node symbol should be ●")
    test.assert.equals(cfg.symbols.saved, "■", "custom saved symbol should be ■")
    test.assert.equals(cfg.symbols.vertical, "│", "custom vertical symbol should be │")
end)

test.it("should merge custom symbols with defaults", function()
    config.setup({
        symbols = {
            current = "🔥",
            -- other symbols should remain default
        }
    })
    
    local cfg = config.get()
    test.assert.equals(cfg.symbols.current, "🔥", "custom current symbol should be 🔥")
    test.assert.equals(cfg.symbols.node, "o", "default node symbol should remain o")
    test.assert.equals(cfg.symbols.saved, "w", "default saved symbol should remain w")
    test.assert.equals(cfg.symbols.vertical, "|", "default vertical symbol should remain |")
end)

test.it("should handle special characters as symbols", function()
    local special_symbols = {
        current = "→",
        node = "◦",
        saved = "◾",
        vertical = "┆",
    }
    
    config.setup({ symbols = special_symbols })
    local cfg = config.get()
    
    for key, expected in pairs(special_symbols) do
        test.assert.equals(cfg.symbols[key], expected, "special symbol " .. key .. " should be " .. expected)
    end
end)

test.it("should handle single character symbols", function()
    config.setup({
        symbols = {
            current = "C",
            node = "N",
            saved = "S",
            vertical = "V",
        }
    })
    
    local cfg = config.get()
    test.assert.equals(cfg.symbols.current, "C", "single char current symbol should be C")
    test.assert.equals(cfg.symbols.node, "N", "single char node symbol should be N")
    test.assert.equals(cfg.symbols.saved, "S", "single char saved symbol should be S")
    test.assert.equals(cfg.symbols.vertical, "V", "single char vertical symbol should be V")
end)

test.it("should preserve other config options when setting symbols", function()
    config.setup({
        width = 50,
        symbols = {
            current = "★",
        },
        help = true,
    })
    
    local cfg = config.get()
    test.assert.equals(cfg.width, 50, "width should be preserved")
    test.assert.equals(cfg.symbols.current, "★", "symbols should be set")
    test.assert.equals(cfg.help, true, "help should be preserved")
end)

test.it("should reset to defaults when called without symbols", function()
    -- First set custom symbols
    config.setup({
        symbols = {
            current = "★",
            node = "●",
        }
    })
    
    -- Then reset to defaults
    config.setup()
    local cfg = config.get()
    
    test.assert.equals(cfg.symbols.current, "@", "reset current symbol should be @")
    test.assert.equals(cfg.symbols.node, "o", "reset node symbol should be o")
    test.assert.equals(cfg.symbols.saved, "w", "reset saved symbol should be w")
    test.assert.equals(cfg.symbols.vertical, "|", "reset vertical symbol should be |")
end)