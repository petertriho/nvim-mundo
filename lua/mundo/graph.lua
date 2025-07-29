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
        elseif node.save then
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
---Helper function to find keys mapped to a specific action
---@param mappings table<string, string> The mappings table
---@param action string The action to find keys for
---@return string[] keys List of keys mapped to the action
local function find_keys_for_action(mappings, action)
    local keys = {}
    for key, mapped_action in pairs(mappings) do
        if mapped_action == action then
            table.insert(keys, key)
        end
    end
    return keys
end

---Helper function to format keys for display
---@param keys string[] List of keys
---@return string formatted_keys Formatted key string
local function format_keys(keys)
    if #keys == 0 then
        return "none"
    elseif #keys == 1 then
        return keys[1]
    else
        -- Sort keys for consistent display
        table.sort(keys)
        return table.concat(keys, "/")
    end
end

---@param target_buffer number The target buffer number
---@param show_help boolean Whether to show help text
---@return string[] header The header lines
function M.generate_header(target_buffer, show_help)
    local header = {}
    local cfg = config.get()

    if cfg.header then
        if show_help then
            local mappings = cfg.mappings
            
            -- Find keys for each action, prioritizing traditional keys
            local move_keys = {}
            local move_older_keys = find_keys_for_action(mappings, "move_older")
            local move_newer_keys = find_keys_for_action(mappings, "move_newer")
            if #move_older_keys > 0 and #move_newer_keys > 0 then
                -- Prioritize j/k if they exist
                local newer_key = "k"
                local older_key = "j"
                local has_j = false
                local has_k = false
                
                for _, key in ipairs(move_newer_keys) do
                    if key == "k" then has_k = true end
                end
                for _, key in ipairs(move_older_keys) do
                    if key == "j" then has_j = true end
                end
                
                if has_j and has_k then
                    move_keys = "j/k"
                else
                    move_keys = format_keys(move_newer_keys) .. "/" .. format_keys(move_older_keys)
                end
            end
            
            local write_keys = ""
            local move_older_write_keys = find_keys_for_action(mappings, "move_older_write")
            local move_newer_write_keys = find_keys_for_action(mappings, "move_newer_write")
            if #move_older_write_keys > 0 and #move_newer_write_keys > 0 then
                -- Prioritize J/K if they exist
                local newer_key = "K"
                local older_key = "J"
                local has_J = false
                local has_K = false
                
                for _, key in ipairs(move_newer_write_keys) do
                    if key == "K" then has_K = true end
                end
                for _, key in ipairs(move_older_write_keys) do
                    if key == "J" then has_J = true end
                end
                
                if has_J and has_K then
                    write_keys = "J/K"
                else
                    write_keys = format_keys(move_newer_write_keys) .. "/" .. format_keys(move_older_write_keys)
                end
            end
            
            local toggle_inline_keys = format_keys(find_keys_for_action(mappings, "toggle_inline"))
            local search_keys = format_keys(find_keys_for_action(mappings, "search"))
            
            local search_nav_keys = {}
            local next_match_keys = find_keys_for_action(mappings, "next_match")
            local prev_match_keys = find_keys_for_action(mappings, "previous_match")
            if #next_match_keys > 0 and #prev_match_keys > 0 then
                search_nav_keys = format_keys(next_match_keys) .. "/" .. format_keys(prev_match_keys)
            end
            
            local play_to_keys = format_keys(find_keys_for_action(mappings, "play_to"))
            local diff_keys = find_keys_for_action(mappings, "diff")
            local diff_current_keys = format_keys(find_keys_for_action(mappings, "diff_current_buffer"))
            local quit_keys = format_keys(find_keys_for_action(mappings, "quit"))
            
            local preview_keys = {}
            local preview_action_keys = find_keys_for_action(mappings, "preview")
            if #preview_action_keys > 0 then
                preview_keys = format_keys(preview_action_keys)
            end

            header = {
                string.format('" Mundo (%d) - Press ? for Help:', target_buffer),
            }
            
            -- Only add help lines for actions that have mapped keys
            if move_keys ~= "" then
                table.insert(header, string.format('" %s   Next/Prev undo state.', move_keys))
            end
            if write_keys ~= "" then
                table.insert(header, string.format('" %s   Next/Prev write state.', write_keys))
            end
            if toggle_inline_keys ~= "none" then
                table.insert(header, string.format('" %s     Toggle "inline diff" mode.', toggle_inline_keys))
            end
            if search_keys ~= "none" then
                table.insert(header, string.format('" %s     Find changes that match string.', search_keys))
            end
            if search_nav_keys ~= "" then
                table.insert(header, string.format('" %s   Next/Prev undo that matches search.', search_nav_keys))
            end
            if play_to_keys ~= "none" then
                table.insert(header, string.format('" %s     Play current state to selected undo.', play_to_keys))
            end
            
            -- Handle diff keys specially - separate 'd' and 'r' even though they map to same action
            local d_keys = {}
            local r_keys = {}
            for _, key in ipairs(diff_keys) do
                if key == "d" then
                    table.insert(d_keys, key)
                elseif key == "r" then
                    table.insert(r_keys, key)
                else
                    table.insert(d_keys, key) -- default other diff keys to 'd' behavior
                end
            end
            
            if #d_keys > 0 then
                table.insert(header, string.format('" %s     Vert diff of undo with current state.', format_keys(d_keys)))
            end
            if diff_current_keys ~= "none" then
                table.insert(header, string.format('" %s     Diff selected undo and current state.', diff_current_keys))
            end
            if #r_keys > 0 then
                table.insert(header, string.format('" %s     Diff selected undo and prior undo.', format_keys(r_keys)))
            end
            if quit_keys ~= "none" then
                table.insert(header, string.format('" %s     Quit!', quit_keys))
            end
            if preview_keys ~= "" then
                table.insert(header, string.format('" %s  Revert to selected state.', preview_keys))
            end
            
            table.insert(header, "")
        else
            header = { string.format('" Mundo (%d) - Press ? for Help:', target_buffer), "" }
        end
    end

    return header
end

return M
