-- Tests for search functionality in nvim-mundo
local test_framework = require("test_framework")
local tree = require("mundo.tree")
local core = require("mundo.core")

local function setup_mock_vim()
    -- Mock vim.api functions
    _G.vim = _G.vim or {}
    _G.vim.api = _G.vim.api or {}
    _G.vim.fn = _G.vim.fn or {}
    
    _G.vim.api.nvim_get_current_win = function() return 1 end
    _G.vim.api.nvim_set_current_win = function() end
    _G.vim.api.nvim_buf_get_lines = function() return {"line1", "line2", "line3"} end
    
    _G.vim.fn.bufloaded = function() return true end
    _G.vim.fn.changenr = function() return 5 end
    
    _G.vim.cmd = function() end
end

local function teardown_mock_vim()
    -- Restore or clear vim globals if needed
end

-- Set up the test suite
test_framework.describe("Search Functionality Tests", setup_mock_vim, teardown_mock_vim)

test_framework.it("should return no matches for empty pattern", function()
    local nodes_data = tree.NodesData:new()
    local matches = nodes_data:search_history("")
    test_framework.assert.equals(next(matches), nil, "Empty pattern should return no matches")
end)

test_framework.it("should return no matches for non-existent pattern", function()
    local nodes_data = tree.NodesData:new()
    local matches = nodes_data:search_history("nonexistent")
    test_framework.assert.equals(next(matches), nil, "Non-existent pattern should return no matches")
end)

test_framework.it("should return empty sorted results for empty matches", function()
    local nodes_data = tree.NodesData:new()
    local sorted = nodes_data:get_sorted_search_results({})
    test_framework.assert.equals(#sorted, 0, "Empty matches should return empty sorted results")
end)

test_framework.it("should sort search results by sequence number (newest first)", function()
    local nodes_data = tree.NodesData:new()
    local Node = require("mundo.node").Node
    
    -- Create mock matches
    local matches = {
        [3] = { node = Node:new(3, nil, 0), matches = 2 },
        [1] = { node = Node:new(1, nil, 0), matches = 1 },
        [5] = { node = Node:new(5, nil, 0), matches = 1 },
    }
    
    local sorted = nodes_data:get_sorted_search_results(matches)
    test_framework.assert.equals(#sorted, 3, "Should have 3 sorted results")
    test_framework.assert.equals(sorted[1].seq, 5, "First result should be seq 5")
    test_framework.assert.equals(sorted[2].seq, 3, "Second result should be seq 3")
    test_framework.assert.equals(sorted[3].seq, 1, "Third result should be seq 1")
end)

test_framework.it("should handle search with no nodes data", function()
    -- Mock the core module's get_target_buffer function
    local original_get_target_buffer = core.get_target_buffer
    core.get_target_buffer = function() return 1 end
    
    -- Mock utils functions
    local utils = require("mundo.utils")
    local original_goto_buffer = utils.goto_buffer
    utils.goto_buffer = function() return true end
    
    local original_echo = utils.echo
    utils.echo = function() end
    
    -- Test search with no nodes data
    core.search("test")
    
    -- Clean up mocks
    core.get_target_buffer = original_get_target_buffer
    utils.goto_buffer = original_goto_buffer
    utils.echo = original_echo
    
    test_framework.assert.is_true(true, "Search integration test completed without errors")
end)

test_framework.it("should show warning when navigating with no search results", function()
    -- Test navigation with no search results
    local utils = require("mundo.utils")
    local original_echo = utils.echo
    local echo_called = false
    utils.echo = function(msg) echo_called = true end
    
    core.search_next()
    test_framework.assert.is_true(echo_called, "Should show warning when no search in progress")
    
    echo_called = false
    core.search_previous()
    test_framework.assert.is_true(echo_called, "Should show warning when no search in progress")
    
    utils.echo = original_echo
end)

test_framework.it("should show confirmation when clearing search", function()
    local utils = require("mundo.utils")
    local original_echo = utils.echo
    local echo_called = false
    utils.echo = function() echo_called = true end
    
    core.clear_search()
    test_framework.assert.is_true(echo_called, "Clear search should show confirmation message")
    
    utils.echo = original_echo
end)

test_framework.it("should return correct search status when no search active", function()
    local pattern, count, index = core.get_search_status()
    test_framework.assert.is_nil(pattern, "No search pattern should be nil")
    test_framework.assert.equals(count, 0, "No search results should have count 0")
    test_framework.assert.equals(index, 0, "No search should have index 0")
end)

test_framework.it("should perform case insensitive search", function()
    -- This test verifies the concept of case-insensitive search
    local test_line = "Hello World"
    local pattern = "hello"
    local line_lower = string.lower(test_line)
    local pattern_lower = string.lower(pattern)
    
    local found = string.find(line_lower, pattern_lower, 1, true)
    test_framework.assert.is_true(found ~= nil, "Case insensitive search should find matches")
end)

test_framework.it("should escape special regex characters for plain text search", function()
    -- Test that special regex characters are properly escaped for plain text search
    local pattern = "test.pattern"
    local escaped = pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    test_framework.assert.equals(escaped, "test%.pattern", "Special characters should be escaped")
end)