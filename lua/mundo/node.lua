-- Undo tree node structure for nvim-mundo
local M = {}

---@class Node
---@field n number The sequence number of this undo state
---@field parent Node? The parent node in the undo tree
---@field children Node[] List of child nodes
---@field time number Timestamp when this undo state was created
---@field save number? The save number if this is a saved state (write state)
local Node = {}
Node.__index = Node

-- Create a new undo tree node
---@param n number The sequence number
---@param parent Node? The parent node
---@param time number The timestamp
---@param save? number The save number if this is a saved state
---@return Node node The new node
function Node:new(n, parent, time, save)
    local node = {
        n = n,
        parent = parent,
        children = {},
        time = time,
        save = save,
    }
    setmetatable(node, self)
    return node
end

-- Add a child node to this node
---@param child Node The child node to add
function Node:add_child(child)
    table.insert(self.children, child)
end

-- Export the Node class
M.Node = Node

return M
