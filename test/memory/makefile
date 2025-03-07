# Specify the simulator
SIM ?= icarus  # Default to Icarus Verilog

# Verilog source file
VERILOG_SOURCES = memory.v

# Top-level module in Verilog
TOPLEVEL = memory

# Python test module
MODULE = memory_tb

# Include Cocotb makefile rules
include $(shell cocotb-config --makefiles)/Makefile.sim
