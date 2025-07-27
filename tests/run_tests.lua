#!/usr/bin/env lua

-- Test runner for nvim-mundo
-- Usage: lua tests/run_tests.lua [test_file]

-- Setup environment
local function setup_test_environment()
    -- Add current directory to package path
    local current_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
    package.path = package.path .. ";" .. current_dir .. "?.lua"
    package.path = package.path .. ";" .. current_dir .. "../lua/?.lua"

    -- Mock vim environment for headless testing
    if not _G.vim then
        _G.vim = {
            api = {},
            fn = {},
            cmd = function() end,
            bo = {},
            wo = {},
            o = {},
            opt = {},
            loop = {
                hrtime = function()
                    return os.clock() * 1000000000
                end,
            },
            inspect = function(obj)
                if type(obj) == "table" then
                    local function serialize(tbl, depth)
                        if depth > 5 then
                            return "{...}"
                        end
                        local items = {}
                        for k, v in pairs(tbl) do
                            local key = tostring(k)
                            local value = type(v) == "table" and serialize(v, depth + 1) or tostring(v)
                            table.insert(items, key .. "=" .. value)
                        end
                        return "{" .. table.concat(items, ", ") .. "}"
                    end
                    if obj == nil then
                        return "nil"
                    elseif type(obj) == "string" then
                        return string.format('"%s"', obj)
                    elseif type(obj) == "number" or type(obj) == "boolean" then
                        return tostring(obj)
                    else
                        return serialize(obj, 1)
                    end
                end
            end,

            tbl_deep_extend = function(behavior, ...)
                local result = {}
                for _, tbl in ipairs({ ... }) do
                    if type(tbl) == "table" then
                        for k, v in pairs(tbl) do
                            if type(v) == "table" and type(result[k]) == "table" then
                                result[k] = vim.tbl_deep_extend(behavior, result[k], v)
                            else
                                result[k] = v
                            end
                        end
                    end
                end
                return result
            end,
        }
    end
end

-- Load and run a specific test file
local function run_test_file(test_file)
    print(string.format("Loading test file: %s", test_file))

    local success, err = pcall(require, test_file)
    if not success then
        print(string.format("❌ Failed to load test file %s: %s", test_file, err))
        return false
    end

    return true
end

-- Main test runner
local function main()
    setup_test_environment()

    local test_framework = require("test_framework")
    if not test_framework then
        print("Error: test_framework module could not be loaded.")
        os.exit(1)
    end

    -- Get command line argument for specific test file
    local specific_test = arg and arg[1]

    if specific_test then
        -- Run specific test file
        local test_file = specific_test:gsub("%.lua$", ""):gsub("^tests/", "tests.")
        if not run_test_file(test_file) then
            os.exit(1)
        end
    else
        -- Run all test files
        local test_files = {
            "tests.test_config",
            "tests.test_utils",
            "tests.test_node",
            "tests.test_tree",
            "tests.test_graph",
            "tests.test_integration",
        }

        for _, test_file in ipairs(test_files) do
            if not run_test_file(test_file) then
                os.exit(1)
            end
        end
    end

    -- Run all loaded tests
    local results = test_framework.run_tests()
    if not results then
        print("Error: Test results are nil.")
        os.exit(1)
    end
end

-- Run if this file is executed directly
arg = arg or { [0] = "run_tests.lua" }
print("Warning: Simulated 'arg' table.")
main()

return {
    setup_test_environment = setup_test_environment,
    run_test_file = run_test_file,
    main = main,
}
