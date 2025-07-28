-- Graph rendering logic for nvim-mundo
local M = {}

local config = require("mundo.config")
local utils = require("mundo.utils")

---@class GraphLine
---@field [1] string The graph characters (e.g., 'o', '|', '@')
---@field [2] string The info text (e.g., '[1] 10:30:15')

-- Calculate the depth/column position for each node in the tree
---@param nodes Node[] List of all nodes
---@param root_node Node The root node
---@return table<number, number> node_depths Map from node sequence to depth/column
local function calculate_node_depths(nodes, root_node)
    local node_depths = {}
    local visited = {}

    -- BFS to assign depths
    local queue = { { node = root_node, depth = 0 } }
    node_depths[root_node.n] = 0
    visited[root_node.n] = true

    while #queue > 0 do
        local current = table.remove(queue, 1)
        local node = current.node
        local depth = current.depth

        -- Process children
        if #node.children > 0 then
            -- Sort children by sequence number to determine main line continuation
            local sorted_children = {}
            for _, child in ipairs(node.children) do
                table.insert(sorted_children, child)
            end
            table.sort(sorted_children, function(a, b)
                return a.n > b.n
            end)

            for i, child in ipairs(sorted_children) do
                if not visited[child.n] then
                    -- Child with highest sequence continues main line (same depth)
                    -- Others branch out (depth + 1)
                    local child_depth = depth
                    if i > 1 then
                        child_depth = depth + 1
                    end

                    node_depths[child.n] = child_depth
                    visited[child.n] = true
                    table.insert(queue, { node = child, depth = child_depth })
                end
            end
        end
    end

    return node_depths
end

-- Generate branching connectors between nodes
---@param from_node Node The parent node
---@param to_node Node The child node
---@param from_depth number Depth of parent node
---@param to_depth number Depth of child node
---@param max_depth number Maximum depth in the tree
---@return string[] connector_lines The connector lines
local function generate_connectors(from_node, to_node, from_depth, to_depth, max_depth)
    local lines = {}

    if from_depth == to_depth then
        -- Straight vertical line
        table.insert(lines, string.rep(" ", from_depth) .. "|" .. string.rep(" ", max_depth - from_depth))
    else
        -- Branching - need to show the split
        local min_depth = math.min(from_depth, to_depth)
        local max_local_depth = math.max(from_depth, to_depth)

        -- Create the branching line
        local branch_line = string.rep(" ", min_depth)

        if from_depth < to_depth then
            -- Branching to the right
            branch_line = branch_line .. "+"
            for d = min_depth + 1, max_local_depth - 1 do
                branch_line = branch_line .. "-"
            end
            if max_local_depth > min_depth then
                branch_line = branch_line .. "\\"
            end
        else
            -- Branching to the left (less common)
            for d = to_depth, from_depth - 1 do
                branch_line = branch_line .. "-"
            end
            branch_line = branch_line .. "+"
        end

        -- Pad to max width
        branch_line = branch_line .. string.rep(" ", max_depth - #branch_line + 1)
        table.insert(lines, branch_line)
    end

    return lines
end

-- Generate the visual graph representation of the undo tree
---@param nodes_data NodesData The nodes data object
---@param verbose boolean Whether to show verbose graph
---@param header_lines number Number of header lines
---@param first_visible number First visible line number
---@param last_visible number Last visible line number
---@param show_inline boolean Whether to show inline diffs
---@return GraphLine[] tree_lines The graph lines to display
function M.generate_graph(nodes_data, verbose, header_lines, first_visible, last_visible, show_inline)
    local nodes, nmap = nodes_data:make_nodes()
    if not nodes or #nodes == 0 then
        return {}
    end

    local current_seq = nodes_data:current()

    -- Get display order - use simple chronological order like undotree
    local display_nodes = {}

    -- Collect all nodes and sort by sequence number (descending for newest first)
    for n, node in pairs(nmap) do
        table.insert(display_nodes, node)
    end

    -- Sort by sequence number in descending order (newest first, like undotree)
    table.sort(display_nodes, function(a, b)
        return a.n > b.n
    end)

    if #display_nodes == 0 then
        return {}
    end

    -- Calculate proper depths for branching tree display
    local node_depths = {}
    local max_depth = 0

    local root_node = nmap[0]
    if root_node then
        -- We have a proper tree structure with root node
        local all_nodes = {}
        for _, node in pairs(nmap) do
            table.insert(all_nodes, node)
        end

        node_depths = calculate_node_depths(all_nodes, root_node)
        for _, depth in pairs(node_depths) do
            max_depth = math.max(max_depth, depth)
        end
    else
        -- Fallback for simple cases without root node (like tests)
        for _, node in ipairs(display_nodes) do
            node_depths[node.n] = 0 -- Simple linear layout
        end
        max_depth = 0
    end

    local tree_lines = {}

    -- Generate undotree-style branching tree lines
    for i, node in ipairs(display_nodes) do
        local curr_depth = node_depths[node.n] or 0
        local prev_node = i > 1 and display_nodes[i - 1] or nil
        local prev_depth = prev_node and (node_depths[prev_node.n] or 0) or 0

        -- Add connector lines between nodes
        if i > 1 then
            -- Check if we need to show a merge (branch coming back to main line)
            if curr_depth < prev_depth then
                -- This is a merge - show |/ pattern
                local merge_line = ""
                -- Add spacing for the current depth
                for d = 0, curr_depth - 1 do
                    merge_line = merge_line .. "| "
                end
                merge_line = merge_line .. "|/"
                table.insert(tree_lines, { merge_line, "" })
            else
                -- Regular connector line
                -- The connector should be at the depth of the previous node (the one we're connecting from)
                local connector_line = ""
                for d = 0, prev_depth - 1 do
                    connector_line = connector_line .. "| "
                end
                connector_line = connector_line .. "|"
                table.insert(tree_lines, { connector_line, "" })
            end
        end

        -- Add the node itself
        local node_char = "o"
        if node.n == current_seq then
            node_char = "@"
        elseif node.curhead then
            node_char = "w"
        end

        -- Build tree line with proper indentation
        local graph_line = ""
        for d = 0, curr_depth - 1 do
            graph_line = graph_line .. "| "
        end
        graph_line = graph_line .. node_char

        -- Node info
        local time_str = os.date("%H:%M:%S", node.time)
        local info_line = string.format("    [%d] %s", node.n, time_str)

        -- Add inline diff if enabled
        if show_inline and node.parent then
            local diff = nodes_data:preview_diff(node.parent, node)
            local changes = 0
            for _, line in ipairs(diff) do
                if line:match("^[+-]") then
                    changes = changes + 1
                end
            end
            if changes > 0 then
                info_line = info_line .. string.format(" (%d changes)", changes)
            end
        end

        table.insert(tree_lines, { graph_line, info_line })
    end

    return tree_lines
end

-- Format the graph output with proper spacing and mirroring
---@param tree_lines GraphLine[] The graph lines to format
---@param mirror_graph boolean Whether to mirror the graph horizontally
---@return string[] output The formatted output lines
function M.format_output(tree_lines, mirror_graph)
    local output = {}
    local dag_width = 1

    -- Calculate DAG width
    for _, line in ipairs(tree_lines) do
        if #line[1] > dag_width then
            dag_width = #line[1]
        end
    end

    -- Format output
    for _, line in ipairs(tree_lines) do
        if mirror_graph then
            -- Mirror branching characters for right-to-left display
            local dag_line =
                utils.reverse_string(line[1]):gsub("/", "TEMP_SLASH"):gsub("\\", "/"):gsub("TEMP_SLASH", "\\")
            local padded = string.rep(" ", dag_width - #dag_line) .. dag_line
            table.insert(output, padded .. " " .. line[2])
        else
            -- Simple concatenation without extra padding that might hide the graph chars
            table.insert(output, line[1] .. " " .. line[2])
        end
    end

    return output
end

-- Generate header lines for the graph
---@param target_buffer number The target buffer number
---@param show_help boolean Whether to show help text
---@return string[] header The header lines
function M.generate_header(target_buffer, show_help)
    local header = {}
    local cfg = config.get()

    if cfg.header then
        if show_help then
            header = {
                string.format('" Mundo (%d) - Press ? for Help:', target_buffer),
                '" j/k   Next/Prev undo state.',
                '" J/K   Next/Prev write state.',
                '" i     Toggle "inline diff" mode.',
                '" /     Find changes that match string.',
                '" n/N   Next/Prev undo that matches search.',
                '" P     Play current state to selected undo.',
                '" d     Vert diff of undo with current state.',
                '" p     Diff selected undo and current state.',
                '" r     Diff selected undo and prior undo.',
                '" q     Quit!',
                '" <cr>  Revert to selected state.',
                "",
            }
        else
            header = { string.format('" Mundo (%d) - Press ? for Help:', target_buffer), "" }
        end
    end

    return header
end

return M
