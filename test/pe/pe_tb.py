import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock


DATA_WIDTH = 8
ACC_WIDTH = 16

async def input(dut, a_in, b_in, we=1):
    dut.a_in.value = a_in
    dut.b_in.value = b_in
    dut.we.value = we  # Enable writing
    dut._log.info("a_in={}, b_in={}, we={}".format(a_in, b_in, we))
    await Timer(1, units="us")
    c_out = dut.c_out.value
    dut._log.info("c_out={}".format(c_out))
    await ClockCycles(dut.clk, 1)
    c_out = dut.c_out.value
    dut._log.info("c_out={}".format(c_out))
    await Timer(1, units="us")
    c_out = dut.c_out.value
    dut._log.info("c_out={}".format(c_out))




@cocotb.test()
async def test_pe(dut):
    """ Test Processing Element (PE) """

    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.rst_n.value = 0
    dut.a_in.value = 0
    dut.b_in.value = 0
    dut.we.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)


    # Running multiply-accumulate tests
    expected_c = 0  # Accumulated value

    await input(dut, 1, 2)

