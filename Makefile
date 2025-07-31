# Makefile for nvim-mundo

.PHONY: test test-unit test-integration test-config test-utils test-node test-tree test-graph test-symbols clean format help

# Default target
help:
	@echo "Available targets:"
	@echo "  test           - Run all tests"
	@echo "  test-unit      - Run unit tests only"
	@echo "  test-integration - Run integration tests only"
	@echo "  test-config    - Run config module tests"
	@echo "  test-utils     - Run utils module tests"
	@echo "  test-node      - Run node module tests"
	@echo "  test-tree      - Run tree module tests"
	@echo "  test-graph     - Run graph module tests"
	@echo "  test-symbols   - Run symbols module tests"
	@echo "  format         - Format all Lua files with stylua"
	@echo "  clean          - Clean test artifacts"

# Variables
LUA_PATH := ./lua/?.lua;./tests/?.lua;;
NVIM_CMD := nvim --headless -c

# Run all tests
test:
	@echo "Running all nvim-mundo tests..."
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!"

# Run unit tests (all except integration)
test-unit:
	@echo "Running unit tests..."
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_config
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_utils
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_node
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_tree
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_graph
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_symbols

# Run integration tests only
test-integration:
	@echo "Running integration tests..."
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_integration

# Run specific module tests
test-config:
	@echo "Running config module tests..."
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_config

test-utils:
	@echo "Running utils module tests..."
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_utils

test-node:
	@echo "Running node module tests..."
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_node

test-tree:
	@echo "Running tree module tests..."
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_tree

test-graph:
	@echo "Running graph module tests..."
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_graph

test-symbols:
	@echo "Running symbols module tests..."
	@LUA_PATH="$(LUA_PATH)" $(NVIM_CMD) "lua require('tests.run_tests')" -c "qa!" tests.test_symbols

# Format all Lua files with stylua
format:
	@echo "Formatting Lua files with stylua..."
	@stylua --config-path .stylua.toml lua/ tests/ plugin/ *.lua

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@find . -name "*.log" -delete 2>/dev/null || true

# Test with verbose output
test-verbose:
	@echo "Running tests with verbose output..."
	@LUA_PATH="./lua/?.lua;./tests/?.lua;;" lua tests/run_tests.lua