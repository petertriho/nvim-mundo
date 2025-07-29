local test = require("test_framework")

-- Setup test environment
package.path = package.path .. ";../lua/?.lua"

local tree_module
local NodesData

-- Spy on vim functions
local original_nvim_get_current_win
local original_nvim_set_current_win
local original_nvim_buf_get_lines
local original_changenr

test.describe("Tree Module", function()
    -- Setup before each test
    original_nvim_get_current_win = vim.api.nvim_get_current_win
    original_nvim_set_current_win = vim.api.nvim_set_current_win
    original_nvim_buf_get_lines = vim.api.nvim_buf_get_lines
    original_changenr = vim.fn.changenr

    vim.api.nvim_get_current_win = function()
        return 1
    end
    vim.api.nvim_set_current_win = function() end
    vim.api.nvim_buf_get_lines = function()
        return {}
    end
    vim.fn.changenr = function()
        return 1
    end

    -- Mock the core module to avoid circular dependency
    package.loaded["mundo.core"] = {
        setup_autocmds = function() end, -- Stub for setup_autocmds
        get_target_buffer = function()
            return 1
        end,
    }

    -- Mock utils module
    package.loaded["mundo.utils"] = {
        goto_buffer = function()
            return true
        end,
    }

    -- Reload tree module to use the mocks
    package.loaded["mundo.tree"] = nil
    tree_module = require("mundo.tree")
    NodesData = tree_module.NodesData
end, function()
    -- Teardown after each test
    vim.api.nvim_get_current_win = original_nvim_get_current_win
    vim.api.nvim_set_current_win = original_nvim_set_current_win
    vim.api.nvim_buf_get_lines = original_nvim_buf_get_lines
    vim.fn.changenr = original_changenr

    package.loaded["mundo.core"] = nil
    package.loaded["mundo.utils"] = nil
    package.loaded["mundo.tree"] = nil
end)

test.it("should create a new NodesData instance", function()
    local nodes_data = NodesData:new()

    test.assert.is_type(nodes_data.nodes, "table", "should initialize nodes as table")
    test.assert.is_type(nodes_data.nmap, "table", "should initialize nmap as table")
    test.assert.is_nil(nodes_data.target_n, "should initialize target_n as nil")
    test.assert.is_true(nodes_data.outdated, "should initialize as outdated")
end)

test.it("should report outdated status correctly", function()
    local nodes_data = NodesData:new()

    test.assert.is_true(nodes_data:is_outdated(), "should be outdated initially")

    nodes_data.outdated = false
    test.assert.is_false(nodes_data:is_outdated(), "should not be outdated when set to false")
end)

test.it("should return current change number", function()
    -- Mock changenr to return specific value
    _G.vim.fn.changenr = function()
        return 5
    end

    local nodes_data = NodesData:new()
    local current = nodes_data:current()

    test.assert.equals(current, 5, "should return current change number")
end)

test.it("should handle preview_diff with nil nodes", function()
    local nodes_data = NodesData:new()

    local diff = nodes_data:preview_diff(nil, nil)
    test.assert.contains(diff, "No changes to display", "should handle nil nodes")

    local node1 = { n = 1 }
    diff = nodes_data:preview_diff(node1, nil)
    test.assert.contains(diff, "No changes to display", "should handle one nil node")
end)

test.it("should generate diff for identical content", function()
    local nodes_data = NodesData:new()

    -- Mock identical content
    _G.vim.api.nvim_buf_get_lines = function()
        return { "line 1", "line 2", "line 3" }
    end

    local node1 = { n = 1 }
    local node2 = { n = 2 }

    local diff = nodes_data:preview_diff(node1, node2)
    test.assert.contains(diff, "No changes between these states", "should detect identical content")
end)

test.it("should generate diff for empty files", function()
    local nodes_data = NodesData:new()

    -- Mock empty content for both calls
    _G.vim.api.nvim_buf_get_lines = function()
        return {}
    end

    local node1 = { n = 1 }
    local node2 = { n = 2 }

    local diff = nodes_data:preview_diff(node1, node2)
    -- Empty files are considered identical, so should return "No changes between these states"
    test.assert.contains(diff, "No changes between these states", "should handle empty files as identical")
end)

test.it("should generate unified diff for different content", function()
    local nodes_data = NodesData:new()
    local call_count = 0

    -- Mock different content for before and after
    _G.vim.api.nvim_buf_get_lines = function()
        call_count = call_count + 1
        if call_count == 1 then
            -- Before content
            return { "line 1", "line 2", "line 3" }
        else
            -- After content
            return { "line 1", "modified line 2", "line 3", "new line 4" }
        end
    end

    local node1 = { n = 1 }
    local node2 = { n = 2 }

    local diff = nodes_data:preview_diff(node1, node2)

    test.assert.contains(diff, "--- a/buffer (undo 1)", "should have diff header")
    test.assert.contains(diff, "+++ b/buffer (undo 2)", "should have diff header")

    -- Should contain unified diff markers
    local has_hunk_header = false
    local has_deletion = false
    local has_addition = false

    for _, line in ipairs(diff) do
        if line:match("^@@") then
            has_hunk_header = true
        elseif line:match("^%-") and not line:match("^%-%-%-") then
            has_deletion = true
        elseif line:match("^%+") and not line:match("^%+%+%+") then
            has_addition = true
        end
    end

    test.assert.is_true(has_hunk_header, "should have hunk header")
end)

test.it("should handle make_nodes with no target buffer", function()
    -- Mock no target buffer
    package.loaded["mundo.core"].get_target_buffer = function()
        return nil
    end

    local nodes_data = NodesData:new()
    local nodes, nmap = nodes_data:make_nodes()

    test.assert.equals(#nodes, 0, "should return empty nodes")
    test.assert.equals(next(nmap), nil, "should return empty nmap")
end)

test.it("should handle make_nodes with valid undotree", function()
    -- Mock target buffer and undotree
    package.loaded["mundo.core"].get_target_buffer = function()
        return 1
    end
    _G.vim.fn.bufloaded = function()
        return true
    end
    _G.vim.fn.undotree = function()
        return {
            entries = {
                { seq = 1, time = 1234567890, save = nil },
                { seq = 2, time = 1234567891, save = 1 },
            },
        }
    end

    local nodes_data = NodesData:new()
    local nodes, nmap = nodes_data:make_nodes()

    test.assert.equals(#nodes, 3, "should create root + 2 nodes")
    test.assert.is_not_nil(nmap[0], "should have root node")
    test.assert.is_not_nil(nmap[1], "should have node 1")
    test.assert.is_not_nil(nmap[2], "should have node 2")
    test.assert.equals(nmap[1].n, 1, "node 1 should have correct sequence")
    test.assert.equals(nmap[2].n, 2, "node 2 should have correct sequence")
    test.assert.equals(nmap[2].save, 1, "node 2 should be saved state")
end)

test.it("should handle complex nested alt branches", function()
    package.loaded["mundo.core"].get_target_buffer = function()
        return 1
    end
    _G.vim.fn.bufloaded = function()
        return true
    end
    _G.vim.fn.undotree = function()
        return {
            entries = {
                {
                    seq = 1,
                    time = 1000,
                    alt = {
                        { seq = 2, time = 1100 },
                        { seq = 3, time = 1200 },
                        {
                            seq = 4,
                            time = 1300,
                            save = 1,
                            alt = {
                                { seq = 5, time = 1400 },
                            },
                        },
                    },
                },
                { seq = 6, time = 2000, save = 2 },
            },
        }
    end

    local nodes_data = NodesData:new()
    local nodes, nmap = nodes_data:make_nodes()

    test.assert.equals(#nodes, 7, "should create root + 6 nodes for complex structure")
    test.assert.is_not_nil(nmap[0], "should have root node")
    test.assert.is_not_nil(nmap[1], "should have node 1")
    test.assert.is_not_nil(nmap[2], "should have node 2 (alt of 1)")
    test.assert.is_not_nil(nmap[3], "should have node 3 (alt of 1)")
    test.assert.is_not_nil(nmap[4], "should have node 4 (alt of 1)")
    test.assert.is_not_nil(nmap[5], "should have node 5 (alt of 4)")
    test.assert.is_not_nil(nmap[6], "should have node 6 (main sequence)")

    -- Check parent-child relationships for nested alt branches
    test.assert.equals(nmap[2].parent.n, 1, "node 2 should be child of node 1")
    test.assert.equals(nmap[3].parent.n, 2, "node 3 should be child of node 2")
    test.assert.equals(nmap[4].parent.n, 3, "node 4 should be child of node 3")
    test.assert.equals(nmap[5].parent.n, 4, "node 5 should be child of node 4")
    test.assert.equals(nmap[6].parent.n, 1, "node 6 should be child of node 1 (main sequence)")
end)

test.it("should handle save markers correctly", function()
    package.loaded["mundo.core"].get_target_buffer = function()
        return 1
    end
    _G.vim.fn.bufloaded = function()
        return true
    end
    _G.vim.fn.undotree = function()
        return {
            entries = {
                { seq = 1, time = 1000 },
                { seq = 2, time = 1100, save = 1 },
                { seq = 3, time = 1200 },
                { seq = 4, time = 1300, save = 2 },
                { seq = 5, time = 1400, save = 3 },
            },
            save_cur = 3,
            save_last = 3,
        }
    end

    local nodes_data = NodesData:new()
    local nodes, nmap = nodes_data:make_nodes()

    test.assert.equals(#nodes, 6, "should create root + 5 nodes")
    -- Note: save markers are metadata, the tree structure should still be sequential
    test.assert.equals(nmap[1].parent.n, 0, "node 1 should be child of root")
    test.assert.equals(nmap[2].parent.n, 1, "node 2 should be child of node 1")
    test.assert.equals(nmap[3].parent.n, 2, "node 3 should be child of node 2")
    test.assert.equals(nmap[4].parent.n, 3, "node 4 should be child of node 3")
    test.assert.equals(nmap[5].parent.n, 4, "node 5 should be child of node 4")
end)

test.it("should handle newhead marker correctly", function()
    package.loaded["mundo.core"].get_target_buffer = function()
        return 1
    end
    _G.vim.fn.bufloaded = function()
        return true
    end
    _G.vim.fn.undotree = function()
        return {
            entries = {
                { seq = 1, time = 1000 },
                { seq = 2, time = 1100 },
                { seq = 3, time = 1200, newhead = 1, save = 1 },
            },
            seq_cur = 3,
            seq_last = 3,
        }
    end

    local nodes_data = NodesData:new()
    local nodes, nmap = nodes_data:make_nodes()

    test.assert.equals(#nodes, 4, "should create root + 3 nodes")
    test.assert.equals(nmap[3].save, 1, "node 3 should be marked as saved state")
end)

test.it("should handle deeply nested alt branches like undotree.txt", function()
    package.loaded["mundo.core"].get_target_buffer = function()
        return 1
    end
    _G.vim.fn.bufloaded = function()
        return true
    end
    -- Simplified version of the complex structure from undotree.txt
    _G.vim.fn.undotree = function()
        return {
            entries = {
                {
                    alt = {
                        { seq = 1, time = 1753578244 },
                        { seq = 2, time = 1753578350 },
                        { seq = 3, time = 1753578664 },
                        { seq = 4, time = 1753578665, save = 1 },
                        { seq = 5, time = 1753578716 },
                        { seq = 6, time = 1753578720, save = 2 },
                        { seq = 7, time = 1753578751, save = 3 },
                        { seq = 8, time = 1753578752 },
                        { seq = 9, time = 1753578753, save = 4 },
                        {
                            seq = 11,
                            time = 1753578763,
                            save = 5,
                            alt = {
                                { seq = 10, time = 1753578760 },
                            },
                        },
                        { seq = 12, time = 1753579021 },
                        {
                            seq = 14,
                            time = 1753579035,
                            alt = {
                                { seq = 13, time = 1753579031 },
                            },
                        },
                        { seq = 15, time = 1753579036, save = 6 },
                        { seq = 16, time = 1753579182 },
                        { seq = 17, time = 1753579397 },
                        { seq = 18, time = 1753579397, save = 7 },
                        { seq = 19, time = 1753579514 },
                    },
                    save = 8,
                    seq = 20,
                    time = 1753597375,
                },
                { seq = 21, time = 1753597378 },
                { seq = 22, time = 1753599322, save = 9 },
                { seq = 23, time = 1753599327, save = 10 },
                { seq = 24, time = 1753599355, save = 11 },
                { seq = 25, time = 1753599368, save = 12 },
                { seq = 26, time = 1753600169 },
                { seq = 27, time = 1753615920, newhead = 1, save = 13 },
            },
            save_cur = 12,
            save_last = 12,
            seq_cur = 27,
            seq_last = 27,
            synced = 1,
            time_cur = 1753615920,
        }
    end

    local nodes_data = NodesData:new()
    local nodes, nmap = nodes_data:make_nodes()

    -- Should handle all 27 sequence numbers plus root (28 total)
    test.assert.equals(#nodes, 28, "should create root + 27 nodes for complex undotree structure")

    -- Verify critical nodes exist
    test.assert.is_not_nil(nmap[0], "should have root node")
    test.assert.is_not_nil(nmap[20], "should have main entry node 20")
    test.assert.is_not_nil(nmap[27], "should have final saved node 27")
    test.assert.is_not_nil(nmap[10], "should have nested alt node 10")
    test.assert.is_not_nil(nmap[13], "should have nested alt node 13")

    -- Verify save is set correctly
    test.assert.equals(nmap[27].save, 13, "node 27 should be saved state")

    -- Verify some key parent-child relationships
    test.assert.equals(nmap[21].parent.n, 20, "node 21 should be child of node 20")
    test.assert.equals(nmap[10].parent.n, 11, "nested alt node 10 should be child of node 11")
    test.assert.equals(nmap[13].parent.n, 14, "nested alt node 13 should be child of node 14")
end)

test.it("should handle empty alt arrays", function()
    package.loaded["mundo.core"].get_target_buffer = function()
        return 1
    end
    _G.vim.fn.bufloaded = function()
        return true
    end
    _G.vim.fn.undotree = function()
        return {
            entries = {
                { seq = 1, time = 1000, alt = {} },
                { seq = 2, time = 1100 },
            },
        }
    end

    local nodes_data = NodesData:new()
    local nodes, nmap = nodes_data:make_nodes()

    test.assert.equals(#nodes, 3, "should create root + 2 nodes despite empty alt")
    test.assert.equals(nmap[2].parent.n, 1, "node 2 should be child of node 1")
end)

test.it("should handle missing sequence numbers gracefully", function()
    package.loaded["mundo.core"].get_target_buffer = function()
        return 1
    end
    _G.vim.fn.bufloaded = function()
        return true
    end
    _G.vim.fn.undotree = function()
        return {
            entries = {
                { seq = 1, time = 1000 },
                { seq = 5, time = 1100 }, -- Gap in sequence
                { seq = 7, time = 1200 }, -- Another gap
            },
        }
    end

    local nodes_data = NodesData:new()
    local nodes, nmap = nodes_data:make_nodes()

    test.assert.equals(#nodes, 4, "should create root + 3 nodes")
    test.assert.is_not_nil(nmap[1], "should have node 1")
    test.assert.is_not_nil(nmap[5], "should have node 5")
    test.assert.is_not_nil(nmap[7], "should have node 7")
    test.assert.is_nil(nmap[2], "should not have node 2")
    test.assert.is_nil(nmap[3], "should not have node 3")
    test.assert.is_nil(nmap[4], "should not have node 4")
    test.assert.is_nil(nmap[6], "should not have node 6")
end)

test.it("should handle complex diff with large line changes", function()
    local nodes_data = NodesData:new()
    local call_count = 0

    _G.vim.api.nvim_buf_get_lines = function()
        call_count = call_count + 1
        if call_count == 1 then
            -- Before: large file
            local lines = {}
            for i = 1, 100 do
                table.insert(lines, "line " .. i)
            end
            return lines
        else
            -- After: modified large file
            local lines = {}
            for i = 1, 50 do
                table.insert(lines, "modified line " .. i)
            end
            for i = 51, 150 do
                table.insert(lines, "new line " .. i)
            end
            return lines
        end
    end

    local node1 = { n = 1 }
    local node2 = { n = 2 }

    local diff = nodes_data:preview_diff(node1, node2)

    test.assert.contains(diff, "--- a/buffer (undo 1)", "should have correct before header")
    test.assert.contains(diff, "+++ b/buffer (undo 2)", "should have correct after header")

    -- Should contain hunk headers and changes
    local has_hunk = false
    local has_deletions = false
    local has_additions = false

    for _, line in ipairs(diff) do
        if line:match("^@@") then
            has_hunk = true
        elseif line:match("^%-") and not line:match("^%-%-%-") then
            has_deletions = true
        elseif line:match("^%+") and not line:match("^%+%+%+") then
            has_additions = true
        end
    end

    test.assert.is_true(has_hunk, "should have hunk headers")
    test.assert.is_true(has_deletions, "should have deletions")
    test.assert.is_true(has_additions, "should have additions")
end)

test.it("should reverse tree structure correctly", function()
    package.loaded["mundo.core"].get_target_buffer = function()
        return 1
    end
    _G.vim.fn.bufloaded = function()
        return true
    end
    _G.vim.fn.undotree = function()
        return {
            entries = {
                {
                    seq = 1,
                    time = 1000,
                    alt = {
                        { seq = 2, time = 1100 },
                        { seq = 3, time = 1200 },
                    },
                },
                { seq = 4, time = 2000 },
            },
        }
    end

    local nodes_data = NodesData:new()
    local nodes, nmap = nodes_data:make_nodes()

    -- Store original order
    local original_children = {}
    if nmap[1] and nmap[1].children then
        for i, child in ipairs(nmap[1].children) do
            original_children[i] = child.n
        end
    end

    -- Reverse the tree
    nodes_data:reverse_tree()

    -- Check that nodes are reversed
    local first_node = nodes_data.nodes[1]
    local last_node = nodes_data.nodes[#nodes_data.nodes]

    test.assert.is_not_nil(first_node, "should have first node after reverse")
    test.assert.is_not_nil(last_node, "should have last node after reverse")

    -- Check that children are reversed if they exist
    if nmap[1] and nmap[1].children and #original_children > 1 then
        local reversed_children = {}
        for i, child in ipairs(nmap[1].children) do
            reversed_children[i] = child.n
        end

        -- Children should be in reverse order
        for i = 1, #original_children do
            test.assert.equals(
                reversed_children[i],
                original_children[#original_children - i + 1],
                "children should be reversed"
            )
        end
    end
end)
