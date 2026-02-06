export LUA_PATH := ../?.lua;;

.PHONY: build serve clean

build:
	pandoc-lua main.lua vault ../docs

serve:
	@rm -rf /tmp/ssglib-serve && mkdir -p /tmp/ssglib-serve
	@ln -s "$$(cd .. && pwd)/docs" /tmp/ssglib-serve/ssglib
	python3 -m http.server --directory /tmp/ssglib-serve

clean:
	rm -rf ../docs
