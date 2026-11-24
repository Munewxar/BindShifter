LUA_DIR := .lua
BUSTED := $(LUA_DIR)/bin/busted
LUACHECK := $(LUA_DIR)/bin/luacheck
VERSION := $(shell grep '^.. Version:' BindShifter/BindShifter.toc | sed 's/.*: *//')

.PHONY: deps test lint dist clean

deps:
	uvx hererocks $(LUA_DIR) -l5.1 -rlatest
	$(LUA_DIR)/bin/luarocks install busted
	$(LUA_DIR)/bin/luarocks install luacheck

test:
	$(BUSTED)

lint:
	$(LUACHECK) BindShifter spec

dist:
	mkdir -p dist
	rm -f dist/BindShifter-$(VERSION).zip
	zip -rq dist/BindShifter-$(VERSION).zip BindShifter -x '*.DS_Store'
	@echo "dist/BindShifter-$(VERSION).zip"

clean:
	rm -rf dist
