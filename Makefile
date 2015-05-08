PREFIX := /usr/local

OS := $(shell luajit -e 'print(require("ffi").os:lower())')
PROJECT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BUILD ?= $(PROJECT)/build
SRC := $(PROJECT)/src
OBJ := $(BUILD)/obj
BIN := $(BUILD)/bin
TMP := $(BUILD)/tmp

CFLAGS:= -Wall -Wextra -Werror -pedantic -Os
ifeq (osx,$(OS))
	LDFLAGS:= $(LDFLAGS) -pagezero_size 10000 -image_base 100000000
endif

LUAJIT_SRC := $(PROJECT)/dep/luajit
LUAJIT_DST := $(BUILD)/dep/luajit
LUAJIT_ARG := 
	XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT \
	MACOSX_DEPLOYMENT_TARGET=10.8 \
	CC="$(CC)" \
	BUILDMODE=static \
	INSTALL_TNAME=luajit \

LUAJIT := $(LUAJIT_DST)/bin/luajit

all: $(BIN)/levee

test: $(BIN)/levee
	$(PROJECT)/bin/lua.test $(PROJECT)/tests

luajit: $(LUAJIT) $(LUAJIT_DST)/lib/libluajit-5.1.a

-include $(wildcard $(OBJ)/*.d)

$(BIN)/levee: $(LUAJIT_DST)/lib/libluajit-5.1.a $(OBJ)/task.o $(OBJ)/liblevee.o $(OBJ)/levee.o
	@mkdir -p $(BIN)
	$(CC) $(LDFLAGS) $^ -o $@

$(OBJ)/%.o: $(SRC)/%.c
	@mkdir -p $(OBJ)
	$(CC) $(CFLAGS) -MMD -MT $@ -MF $@.d -c $< -o $@

$(OBJ)/%.o: $(TMP)/%.c
	@mkdir -p $(OBJ)
	$(CC) $(CFLAGS) -MMD -MT $@ -MF $@.d -c $< -o $@

$(TMP)/liblevee.c: $(LUAJIT) $(PROJECT)/bin/bundle.lua $(shell find $(PROJECT)/levee -type f)
	@mkdir -p $(TMP)
	$(LUAJIT) $(PROJECT)/bin/bundle.lua $(PROJECT) levee > $@

$(LUAJIT_SRC)/Makefile:
	git submodule update --init $(LUAJIT_SRC)

$(LUAJIT) $(LUAJIT_DST)/lib/libluajit-5.1.a: $(LUAJIT_SRC)/Makefile
	@mkdir -p $(LUAJIT_DST)
	$(MAKE) -C $(LUAJIT_SRC) amalg $(LUAJIT_ARG) PREFIX=$(PREFIX)
	$(MAKE) -C $(LUAJIT_SRC) install $(LUAJIT_ARG) PREFIX=$(LUAJIT_DST)

clean:
	rm -rf $(BUILD)
	#cd $(LUAJIT_SRC) && git clean -xdf

.PHONY: clean
