# Specify the simulator
SIM ?= icarus  # Default to Icarus Verilog

# Verilog source file
VERILOG_SOURCES = control.v

# Top-level module in Verilog
TOPLEVEL = control

# Python test module
MODULE = control_tb

# Include Cocotb makefile rules
include $(shell cocotb-config --makefiles)/Makefile.sim
