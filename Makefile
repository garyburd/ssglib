
export LUA_PATH := ssglib/?.lua;;

.PHONY: test api api-check

test:
	pandoc-lua tests/test_elements.lua
	pandoc-lua tests/test_paths.lua
	pandoc-lua tests/test_vault.lua
	pandoc-lua tests/test_filters.lua
	pandoc-lua tests/test_site.lua
	pandoc-lua docgen/main.lua --check

api:
	pandoc-lua docgen/main.lua

api-check:
	pandoc-lua docgen/main.lua --check
