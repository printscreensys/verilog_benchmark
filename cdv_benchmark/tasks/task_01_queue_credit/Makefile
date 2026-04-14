TOPLEVEL_LANG = verilog
SIM ?= icarus
PWD := $(shell pwd)

VERILOG_SOURCES = $(PWD)/rtl/queue_credit_tracker.v
TOPLEVEL = queue_credit_tracker
MODULE = test_cdv
export PYTHONPATH := $(PWD)/tests:$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim
