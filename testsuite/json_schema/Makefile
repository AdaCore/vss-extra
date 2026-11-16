DIRECTORIES := dap lsp sarif boolean_defaults typescript
CHECKS := boolean_defaults typescript numeric_constants constant_aliases null_properties
JSON_GEN := $(abspath ../../.objs/development/tools/gen_json)
GOT_FILE := $(shell mktemp -t got-XXXXXX.txt)

all: $(foreach dir,$(DIRECTORIES),$(dir)-run)

check: $(foreach dir,$(CHECKS),$(dir)-check)

%-check:
	bash $*/test.sh $(JSON_GEN)

%-run:
	cd $*; $(JSON_GEN) `cat cmd.txt` > $(GOT_FILE)
	diff -u $*/expected.txt $(GOT_FILE)
	rm -f $(GOT_FILE)

compile: DIR := $(shell mktemp --directory)
compile: $(foreach dir,$(DIRECTORIES),$(dir)-compile)

%-compile:
	gnatchop -gnat2022 $*/expected.txt $(DIR)
	cp -v *.ad[sb] *.gpr $*/*.ad[sb] $(DIR)
	gprbuild -P $(DIR)/default.gpr
	rm -rf $(DIR)/*.ad[sb]
