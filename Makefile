

.PHONY: test

test:
	pandoc-lua tests/test_elements.lua
	pandoc-lua tests/test_paths.lua
	pandoc-lua tests/test_vault.lua
