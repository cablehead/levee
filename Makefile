PREFIX := /usr/local

OS := $(shell uname)
PROJECT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BUILD ?= $(PROJECT)/build

SRC := $(PROJECT)/src
OBJ := $(BUILD)/obj
BIN := $(BUILD)/bin
TMP := $(BUILD)/tmp

TEST_SRC := $(PROJECT)/tests
TEST_OBJ := $(BUILD)/test
TEST_BIN := $(BUILD)/test
ifneq (,$(MEMCHECK))
	TEST_RUN:= valgrind --error-exitcode=2 -q --leak-check=full
endif

OBJS_COMMON := $(OBJ)/heap.o $(OBJ)/http.o
OBJS_LEVEE := \
	$(OBJS_COMMON) \
	$(OBJ)/task.o \
	$(OBJ)/liblevee.o \
	$(OBJ)/levee.o

TESTS := $(patsubst $(PROJECT)/tests/c/%.c,%,$(wildcard $(TEST_SRC)/c/*.c))

export MACOSX_DEPLOYMENT_TARGET=10.8

LUAJIT_SRC := $(PROJECT)/src/luajit
LUAJIT_DST := $(BUILD)/luajit
LUAJIT_ARG := \
	XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT \
	BUILDMODE=static \
	MACOSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET) \
	INSTALL_TNAME=luajit

LUAJIT := $(LUAJIT_DST)/bin/luajit

CFLAGS:= -Wall -Wextra -Werror -pedantic -std=c99 -O2 -march=native -I$(PROJECT)/src -I$(TMP) -I$(LUAJIT_DST)/include/luajit-2.1
ifeq (Darwin,$(OS))
  LDFLAGS:= $(LDFLAGS) -pagezero_size 10000 -image_base 100000000 -Wl,-export_dynamic
endif
ifeq (Linux,$(OS))
  CFLAGS:= $(CFLAGS) -D_BSD_SOURCE
  LDFLAGS:= -Wl,-export-dynamic -lm -ldl
endif

all: $(BIN)/levee

test: test-c test-lua

test-c:
	@for name in $(TESTS); do $(MAKE) $$name || break; done

test-lua:
	$(PROJECT)/bin/lua.test $(PROJECT)/tests

%: $(TEST_BIN)/%
	$(TEST_RUN) $<

luajit: $(LUAJIT) $(LUAJIT_DST)/lib/libluajit-5.1.a

-include $(wildcard $(OBJ)/*.d)

$(BIN)/levee: $(LUAJIT_DST)/lib/libluajit-5.1.a $(OBJS_LEVEE)
	@mkdir -p $(BIN)
	$(CC) $(LDFLAGS) $(OBJS_LEVEE) $(LUAJIT_DST)/lib/libluajit-5.1.a -o $@

$(OBJ)/%.o: $(SRC)/%.c
	@mkdir -p $(OBJ)
	$(CC) $(CFLAGS) -MMD -MT $@ -MF $@.d -c $< -o $@

$(OBJ)/%.o: $(TMP)/%.c
	@mkdir -p $(OBJ)
	$(CC) $(CFLAGS) -MMD -MT $@ -MF $@.d -c $< -o $@

$(TMP)/liblevee.c: $(LUAJIT) $(TMP)/levee_cdef.h $(PROJECT)/bin/bundle.lua \
		$(shell find $(PROJECT)/levee -type f)
	@mkdir -p $(TMP)
	$(LUAJIT) $(PROJECT)/bin/bundle.lua $(PROJECT) levee > $@

$(TMP)/levee_cdef.h: $(LUAJIT) $(shell find $(PROJECT)/cdef -type f)
	@mkdir -p $(TMP)
	echo "const char levee_cdef[] = {" > $@
	$(LUAJIT) $(PROJECT)/cdef/manifest.lua | xxd -i >> $@
	echo ", 0};" >> $@

$(LUAJIT_SRC)/Makefile:
	git submodule update --init $(LUAJIT_SRC)

$(LUAJIT) $(LUAJIT_DST)/lib/libluajit-5.1.a: $(LUAJIT_SRC)/Makefile
	@mkdir -p $(LUAJIT_DST)
	$(MAKE) -C $(LUAJIT_SRC) amalg $(LUAJIT_ARG) PREFIX=$(PREFIX)
	$(MAKE) -C $(LUAJIT_SRC) install $(LUAJIT_ARG) PREFIX=$(LUAJIT_DST)

$(TEST_OBJ)/%.o: $(TEST_SRC)/c/%.c
	@mkdir -p $(TEST_OBJ)
	$(CC) $(CFLAGS) -MMD -MT $@ -MF $@.d -c $< -o $@

$(TEST_BIN)/%: $(TEST_OBJ)/%.o $(OBJS_COMMON)
	@mkdir -p $(TEST_BIN)
	$(CC) $^ -o $@

clean:
	rm -rf $(BUILD)
	cd $(LUAJIT_SRC) && git clean -xdf

.PHONY: test test-c test-lua clean
.SECONDARY:

