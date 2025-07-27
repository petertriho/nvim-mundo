local tree_module = require("mundo.tree")

local nodes_data = tree_module.NodesData:new()
nodes_data.tree_order = "desc"

-- Create mock nodes
local root = { n = 0, children = {} }
local child1 = { n = 1, children = {} }
local child2 = { n = 2, children = {} }
local child3 = { n = 3, children = {} }

root.children = { child1, child2, child3 }
nodes_data.nodes = { root }

-- Reverse the tree
nodes_data:reverse_tree()

-- Print results
print("Root children after reversal:", vim.inspect(nodes_data.nodes[1].children))
print("Debug: Full nodes_data:", vim.inspect(nodes_data))
