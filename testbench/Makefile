# SPDX-FileCopyrightText: 2023 CERN (home.cern)
#
# SPDX-License-Identifier: CERN-OHL-W-2.0+


# This Makefile can be called by the Continuous Integration (CI) tool to execute all
# testbenches added for CI

# AXI4 cores
TB_DIRS+=axi/axi4lite_wb_bridge
TB_DIRS+=axi/z7_axi_gpio_expander
TB_DIRS+=axi/axi4lite32_axi4full64_bridge
TB_DIRS+=axi/axi4lite_axi4full_bridge

.PHONY: $(TB_DIRS)

all: $(TB_DIRS) summary

$(TB_DIRS):
	@echo "Run HDLMAKE"
	@cd "$@"; \
	hdlmake 2>&1
	@echo "Run make"
	@$(MAKE) -C $@ $(TARGET)

	@echo "Run ghdl"
	@cd "$@" ;\
	./run.sh
	@echo "ghdl returned $$?"

summary: $(TB_DIRS)
	@echo "-------------------------------------------------------------------"
	@echo "Summary:"
	@for d in $(TB_DIRS); do \
		if [ -f $$d/transcript ]; then \
			echo "Warnings for $$d:"; \
			cat $$d/transcript | grep Warning; \
			if [ $$? -eq 1 ]; then echo "None"; fi ;\
			echo "Errors for $$d:"; \
			cat $$d/transcript | grep Error; \
			if [ $$? -eq 1 ]; then echo "None"; fi ;\
		else \
			echo "No transcript file for $$d"; \
		fi \
	done

clean:
	@for d in $(TB_DIRS); do \
		if [ -f $$d/Makefile ]; then \
			$(MAKE) -C $$d $@; \
			rm -f $$d/Makefile; \
		fi \
	done
