# Specify the simulator
SIM ?= icarus  # Default to Icarus Verilog

# Verilog source file
VERILOG_SOURCES = tt_um_tpu.v tpu.v control.v array.v memory.v pe.v

# Top-level module in Verilog
TOPLEVEL = tt_um_tpu

# Python test module
MODULE = tpu_tb

# Include Cocotb makefile rules
include $(shell cocotb-config --makefiles)/Makefile.sim
