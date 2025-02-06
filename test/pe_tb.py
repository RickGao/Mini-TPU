import cocotb
from cocotb.triggers import RisingEdge, FallingEdge
import random

@cocotb.test()
async def test_pe(dut):
    """Test Processing Element of Systolic Array"""

    # Reset the DUT
    dut.rst_n.value = 0
    dut.we.value = 0
    dut.a_in.value = 0
    dut.b_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1  # Release reset
    await RisingEdge(dut.clk)

    # Check reset values
    assert dut.a_out.value == 0, "A register did not reset correctly!"
    assert dut.b_out.value == 0, "B register did not reset correctly!"
    assert dut.c_out.value == 0, "C register did not reset correctly!"

    # Apply test values
    test_data = [
        (3, 2),  # A=3, B=2  --> Expected C = 3*2 = 6
        (1, 4),  # A=1, B=4  --> Expected C = 6 + 1*4 = 10
        (2, 5),  # A=2, B=5  --> Expected C = 10 + 2*5 = 20
    ]

    for a_val, b_val in test_data:
        dut.a_in.value = a_val
        dut.b_in.value = b_val
        dut.we.value = 1  # Enable write
        await RisingEdge(dut.clk)
        dut.we.value = 0  # Disable write after one cycle
        await RisingEdge(dut.clk)

        expected_c = sum(a * b for a, b in test_data[:test_data.index((a_val, b_val)) + 1])
        assert dut.c_out.value == expected_c, f"Error: Expected C={expected_c}, but got {int(dut.c_out.value)}"

    cocotb.log.info("Test completed successfully!")
