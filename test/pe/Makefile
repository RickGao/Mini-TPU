# Specify the simulator
SIM ?= icarus  # Default to Icarus Verilog

# Verilog source file
VERILOG_SOURCES = pe.v

# Top-level module in Verilog
TOPLEVEL = pe

# Python test module
MODULE = pe_tb

# Include Cocotb makefile rules
include $(shell cocotb-config --makefiles)/Makefile.sim
