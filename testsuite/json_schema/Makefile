DIRECTORIES := dap lsp sarif
JSON_GEN := $(abspath ../../.objs/development/tools/gen_json)
GOT_FILE := $(shell mktemp -t got-XXXXXX.txt)

all: $(foreach dir,$(DIRECTORIES),$(dir)-run)

%-run:
	cd $*; $(JSON_GEN) `cat cmd.txt` > $(GOT_FILE)
	diff -u $*/expected.txt $(GOT_FILE)
	rm -f $(GOT_FILE)

compile: DIR := $(shell mktemp --directory)
compile: $(foreach dir,$(DIRECTORIES),$(dir)-compile)

%-compile:
	gnatchop -gnat2022 $*/expected.txt $(DIR)
	cp -v *.ad[sb] *.gpr $*/*.ads $(DIR)
	gprbuild -P $(DIR)/default.gpr
	rm -rf $(DIR)/*.ad[sb]
