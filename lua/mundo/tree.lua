-- Undo tree data management and diff algorithms for nvim-mundo
local M = {}

local api = vim.api
local fn = vim.fn
local utils = require("mundo.utils")
local Node = require("mundo.node").Node

---@class NodesData
---@field nodes Node[] List of all nodes in the undo tree
---@field nmap table<number, Node> Map from sequence number to node
---@field target_n number? Target buffer number
---@field outdated boolean Whether the data needs to be refreshed
local NodesData = {}
NodesData.__index = NodesData

-- Create a new NodesData instance
---@return NodesData data The new NodesData instance
function NodesData:new()
    local obj = {
        nodes = {},
        nmap = {},
        target_n = nil,
        outdated = true,
    }
    setmetatable(obj, self)
    return obj
end

-- Check if the nodes data is outdated
---@return boolean outdated True if data needs to be refreshed
function NodesData:is_outdated()
    return self.outdated
end

-- Build the nodes and node map from the undo tree
---@return Node[] nodes List of all nodes
---@return table<number, Node> nmap Map from sequence number to node
function NodesData:make_nodes()
    local target_n = require("mundo.core").get_target_buffer()
    if not target_n or not fn.bufloaded(target_n) then
        return {}, {}
    end

    -- Switch to target buffer to get undo tree
    local current_win = api.nvim_get_current_win()
    if not utils.goto_buffer(target_n) then
        return {}, {}
    end

    -- Get undo tree using Vim's undotree() function
    local undotree = fn.undotree()
    local entries = undotree.entries or {}

    self.nodes = {}
    self.nmap = {}

    -- Create root node (represents the initial empty state)
    local root = Node:new(0, nil, 0)
    self.nodes[1] = root
    self.nmap[0] = root

    -- Create all nodes first (including alt entries recursively)
    local function create_nodes_recursive(entries_to_process)
        for _, entry in ipairs(entries_to_process) do
            -- Create node for this entry if it doesn't exist
            if not self.nmap[entry.seq] then
                local node = Node:new(entry.seq, nil, entry.time, entry.curhead)
                self.nodes[#self.nodes + 1] = node
                self.nmap[entry.seq] = node
            end

            -- Recursively process alt entries
            if entry.alt then
                create_nodes_recursive(entry.alt)
            end
        end
    end

    -- Create all nodes including deeply nested alt entries
    create_nodes_recursive(entries)

    -- Build parent-child relationships using Vim's undo tree structure
    --
    -- Vim's undotree structure works differently than initially assumed:
    -- - Each entry represents a change with a sequence number
    -- - Entries are ordered chronologically, not by tree structure
    -- - The 'alt' field contains alternative branches that diverged from this point
    -- - We need to build a proper tree by finding the correct parent for each entry
    --
    -- Algorithm:
    -- 1. Sort all entries by sequence number (chronological order)
    -- 2. For each entry, find its parent by looking at the previous entry
    --    or by checking if it's an alt branch of an earlier entry
    -- 3. Build the tree structure incrementally

    -- Build a map of all entries for quick lookup, including nested alt entries
    local entry_map = {}
    local function build_entry_map_recursive(entries_to_process)
        for _, entry in ipairs(entries_to_process) do
            entry_map[entry.seq] = entry
            -- Recursively process alt entries
            if entry.alt then
                build_entry_map_recursive(entry.alt)
            end
        end
    end

    build_entry_map_recursive(entries)

    -- Build parent relationships based on undotree branching logic
    -- Key insight: Distinguish between main sequence entries and alt entries

    local branch_starts = {} -- seq -> parent_seq (only for entries that start branches)
    local alt_sequences = {} -- parent_seq -> [seq1, seq2, seq3, ...] (ordered)
    local in_alt_of = {} -- seq -> parent_seq (which alt array this node is in)
    local is_main_entry = {} -- seq -> true (if this node is in the main entries array)

    -- Mark all main entries
    for _, entry in ipairs(entries) do
        is_main_entry[entry.seq] = true
    end

    local function identify_branch_relationships_recursive(entries_to_process)
        for _, entry in ipairs(entries_to_process) do
            if entry.alt and #entry.alt > 0 then
                -- Store the alt sequence for this entry
                alt_sequences[entry.seq] = {}
                for _, alt in ipairs(entry.alt) do
                    table.insert(alt_sequences[entry.seq], alt.seq)
                    in_alt_of[alt.seq] = entry.seq
                end

                -- Only the first entry in the alt array starts a branch from this entry
                local first_alt = entry.alt[1]
                branch_starts[first_alt.seq] = entry.seq

                -- Recursively process nested alt entries
                for _, alt in ipairs(entry.alt) do
                    if alt.alt then
                        identify_branch_relationships_recursive({ alt })
                    end
                end
            end
        end
    end

    identify_branch_relationships_recursive(entries)

    -- Collect all entries (including nested alt entries) and sort by sequence number
    local all_entries = {}
    local function collect_all_entries_recursive(entries_to_process)
        for _, entry in ipairs(entries_to_process) do
            table.insert(all_entries, entry)
            if entry.alt then
                collect_all_entries_recursive(entry.alt)
            end
        end
    end

    collect_all_entries_recursive(entries)
    table.sort(all_entries, function(a, b)
        return a.seq < b.seq
    end)

    -- Build the tree structure
    for _, entry in ipairs(all_entries) do
        local node = self.nmap[entry.seq]
        if not node then
            goto continue
        end

        -- Determine the parent of this node
        local parent_node = nil

        if branch_starts[entry.seq] then
            -- This node starts a branch from a specific parent
            parent_node = self.nmap[branch_starts[entry.seq]]
        elseif in_alt_of[entry.seq] then
            -- This node is part of an alt sequence - find its previous node in that sequence
            local alt_parent = in_alt_of[entry.seq]
            local alt_seq = alt_sequences[alt_parent]
            local position_in_alt = nil
            for i, seq in ipairs(alt_seq) do
                if seq == entry.seq then
                    position_in_alt = i
                    break
                end
            end

            if position_in_alt and position_in_alt > 1 then
                -- Connect to previous node in the alt sequence
                local prev_seq = alt_seq[position_in_alt - 1]
                parent_node = self.nmap[prev_seq]
            else
                -- This should be the first node (already handled by branch_starts)
                -- Fallback to alt parent
                parent_node = self.nmap[alt_parent]
            end
        elseif is_main_entry[entry.seq] then
            -- This node is part of the main sequence - connect to previous main entry
            local parent_seq = 0
            -- Look for the highest sequence number that is also a main entry
            for i = entry.seq - 1, 0, -1 do
                if self.nmap[i] and is_main_entry[i] then
                    parent_seq = i
                    break
                end
            end
            parent_node = self.nmap[parent_seq]
        else
            -- Fallback: sequential connection
            local parent_seq = entry.seq - 1
            if parent_seq >= 0 and self.nmap[parent_seq] then
                parent_node = self.nmap[parent_seq]
            else
                -- Look backwards for the highest available sequence number
                for i = entry.seq - 1, 0, -1 do
                    if self.nmap[i] then
                        parent_seq = i
                        parent_node = self.nmap[parent_seq]
                        break
                    end
                end
            end
        end

        -- Connect to parent (avoid circular references)
        if parent_node and parent_node.n ~= entry.seq then
            node.parent = parent_node
            parent_node:add_child(node)
        else
            -- Fallback: connect to root if no valid parent found
            node.parent = root
            root:add_child(node)
        end

        ::continue::
    end

    -- Restore original window
    api.nvim_set_current_win(current_win)

    self.target_n = target_n
    self.outdated = false

    return self.nodes, self.nmap
end

-- Get the current undo state number
---@return number state The current undo state number
function NodesData:current()
    local target_buffer = require("mundo.core").get_target_buffer()
    if not target_buffer then
        return 0
    end

    local current_win = api.nvim_get_current_win()
    if not utils.goto_buffer(target_buffer) then
        return 0
    end

    local changenr = fn.changenr()
    api.nvim_set_current_win(current_win)

    return changenr
end

---@class DiffChange
---@field type 'add'|'delete'|'equal'|'context' The type of change
---@field before_line? number Line number in before text
---@field after_line? number Line number in after text
---@field content string The line content

---@class DiffHunk
---@field before_start number Starting line number in before text
---@field after_start number Starting line number in after text
---@field changes DiffChange[] List of changes in this hunk

-- Simple LCS-based diff algorithm
---@param a string[] First array of lines
---@param b string[] Second array of lines
---@return number[][] dp The dynamic programming table
local function compute_lcs(a, b)
    local m, n = #a, #b
    local dp = {}

    -- Initialize DP table
    for i = 0, m do
        dp[i] = {}
        for j = 0, n do
            dp[i][j] = 0
        end
    end

    -- Fill DP table
    for i = 1, m do
        for j = 1, n do
            if a[i] == b[j] then
                dp[i][j] = dp[i - 1][j - 1] + 1
            else
                dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1])
            end
        end
    end

    return dp
end

-- Generate unified diff format
---@param before_lines string[] Lines from before state
---@param after_lines string[] Lines from after state
---@param context_lines? number Number of context lines (default: 3)
---@return string[] diff_lines The unified diff lines
local function generate_unified_diff(before_lines, after_lines, context_lines)
    context_lines = context_lines or 3

    local diff_lines = {}
    local lcs_table = compute_lcs(before_lines, after_lines)
    local m, n = #before_lines, #after_lines

    -- Backtrack to find the actual diff
    local changes = {}
    local i, j = m, n

    while i > 0 or j > 0 do
        if i > 0 and j > 0 and before_lines[i] == after_lines[j] then
            table.insert(changes, 1, { type = "equal", before_line = i, after_line = j, content = before_lines[i] })
            i = i - 1
            j = j - 1
        elseif j > 0 and (i == 0 or lcs_table[i][j - 1] >= lcs_table[i - 1][j]) then
            table.insert(changes, 1, { type = "add", after_line = j, content = after_lines[j] })
            j = j - 1
        elseif i > 0 and (j == 0 or lcs_table[i][j - 1] < lcs_table[i - 1][j]) then
            table.insert(changes, 1, { type = "delete", before_line = i, content = before_lines[i] })
            i = i - 1
        end
    end

    -- Group changes into hunks with context
    local hunks = {}
    local current_hunk = nil

    for idx, change in ipairs(changes) do
        if change.type ~= "equal" then
            -- Start a new hunk if needed
            if not current_hunk then
                current_hunk = {
                    before_start = math.max(1, (change.before_line or change.after_line or 1) - context_lines),
                    after_start = math.max(1, (change.after_line or change.before_line or 1) - context_lines),
                    changes = {},
                }

                -- Add context before
                local ref_line = change.before_line or change.after_line or 1
                local context_start = math.max(1, ref_line - context_lines)
                local context_end = ref_line - 1

                for line_num = context_start, context_end do
                    if line_num > 0 and before_lines[line_num] then
                        table.insert(current_hunk.changes, { type = "context", content = before_lines[line_num] })
                    end
                end
            end

            table.insert(current_hunk.changes, change)
        else
            -- Equal line - might be context or end of hunk
            if current_hunk then
                table.insert(current_hunk.changes, { type = "context", content = change.content })

                -- Check if we should end this hunk
                local context_after = 0
                for next_idx = idx + 1, math.min(idx + context_lines * 2, #changes) do
                    if changes[next_idx].type == "equal" then
                        context_after = context_after + 1
                    else
                        break
                    end
                end

                if context_after >= context_lines * 2 or idx == #changes then
                    -- End current hunk
                    table.insert(hunks, current_hunk)
                    current_hunk = nil
                end
            end
        end
    end

    -- Add final hunk if exists
    if current_hunk then
        table.insert(hunks, current_hunk)
    end

    -- Generate unified diff output
    for _, hunk in ipairs(hunks) do
        local before_count = 0
        local after_count = 0

        -- Count lines in hunk
        for _, change in ipairs(hunk.changes) do
            if change.type == "delete" or change.type == "context" then
                before_count = before_count + 1
            end
            if change.type == "add" or change.type == "context" then
                after_count = after_count + 1
            end
        end

        -- Add hunk header
        table.insert(
            diff_lines,
            string.format("@@ -%d,%d +%d,%d @@", hunk.before_start, before_count, hunk.after_start, after_count)
        )

        -- Add hunk content
        for _, change in ipairs(hunk.changes) do
            if change.type == "delete" then
                table.insert(diff_lines, "-" .. change.content)
            elseif change.type == "add" then
                table.insert(diff_lines, "+" .. change.content)
            elseif change.type == "context" then
                table.insert(diff_lines, " " .. change.content)
            end
        end
    end

    return diff_lines
end

-- Generate a preview diff between two nodes
---@param node_before Node? The before node
---@param node_after Node? The after node
---@return string[] diff_lines The diff lines to display
function NodesData:preview_diff(node_before, node_after)
    if not node_before or not node_after then
        return { "No changes to display" }
    end

    local target_buffer = require("mundo.core").get_target_buffer()
    local current_win = api.nvim_get_current_win()
    if not utils.goto_buffer(target_buffer) then
        return { "Cannot access target buffer" }
    end

    -- Save current state
    local current_changenr = fn.changenr()

    -- Get content at node_before
    if node_before.n > 0 then
        vim.cmd("silent undo " .. node_before.n)
    else
        vim.cmd("silent earlier 999999")
    end
    local before_lines = api.nvim_buf_get_lines(0, 0, -1, false)

    -- Get content at node_after
    if node_after.n > 0 then
        vim.cmd("silent undo " .. node_after.n)
    else
        vim.cmd("silent earlier 999999")
    end
    local after_lines = api.nvim_buf_get_lines(0, 0, -1, false)

    -- Restore original state
    if current_changenr > 0 then
        vim.cmd("silent undo " .. current_changenr)
    end

    api.nvim_set_current_win(current_win)

    -- Check if there are any differences
    if #before_lines == #after_lines then
        local identical = true
        for i = 1, #before_lines do
            if before_lines[i] ~= after_lines[i] then
                identical = false
                break
            end
        end
        if identical then
            return { "No changes between these states" }
        end
    end

    -- Handle empty files
    if #before_lines == 0 and #after_lines == 0 then
        return { "Both states are empty" }
    end

    -- Generate proper unified diff
    local diff_lines = {}
    table.insert(diff_lines, string.format("--- a/buffer (undo %d)", node_before.n))
    table.insert(diff_lines, string.format("+++ b/buffer (undo %d)", node_after.n))

    local unified_diff = generate_unified_diff(before_lines, after_lines, 3)
    for _, line in ipairs(unified_diff) do
        table.insert(diff_lines, line)
    end

    return diff_lines
end

-- Reverse the tree by swapping children of all nodes
---@param self NodesData
function NodesData:reverse_tree()
    -- Reverse the order of nodes
    local reversed_nodes = {}
    for i = #self.nodes, 1, -1 do
        table.insert(reversed_nodes, self.nodes[i])
    end
    self.nodes = reversed_nodes

    -- Reverse the children of each node
    for _, node in ipairs(self.nodes) do
        if node.children and #node.children > 0 then
            local function reverse_table(tbl)
                local reversed = {}
                for i = #tbl, 1, -1 do
                    table.insert(reversed, tbl[i])
                end
                return reversed
            end

            node.children = reverse_table(node.children)
        end
    end
end
-- Export the NodesData class
M.NodesData = NodesData

-- Convenience function for creating tree from undotree data
function M.create(undotree_data)
    local nodes_data = NodesData:new()

    -- Mock the undotree() function for this test
    local original_undotree = vim.fn.undotree
    vim.fn.undotree = function()
        return undotree_data
    end

    local nodes, nmap = nodes_data:make_nodes()

    -- Restore original function
    vim.fn.undotree = original_undotree

    return { nodes = nmap, root = nodes[0] or nodes_data.nodes[0] }
end

return M
