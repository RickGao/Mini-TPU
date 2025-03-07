import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.binary import BinaryValue
import random


@cocotb.test()
async def test_memory_basic(dut):
    """
    Basic test for memory module:
    - Initialize and reset
    - Write a value to a specific location
    - Read back from the same location
    - Verify read value matches written value
    """
    # Create a clock and start it
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the memory
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0  # Active low reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Initialize all inputs
    dut.write_enable.value = 0
    dut.write_line.value = 0
    dut.write_elem.value = 0
    dut.data_in.value = 0
    dut.read_enable.value = 0
    dut.read_elem.value = 0  # Single 8-bit bus now

    await RisingEdge(dut.clk)

    # Write test values to different memory locations
    test_values = []
    for line in range(4):
        for elem in range(4):
            test_value = random.randint(0, 2 ** 8 - 1)  # Random 8-bit value
            test_values.append((line, elem, test_value))

            # Set write signals
            dut.write_enable.value = 1
            dut.write_line.value = line
            dut.write_elem.value = elem
            dut.data_in.value = test_value

            await RisingEdge(dut.clk)

    dut.write_enable.value = 0
    await RisingEdge(dut.clk)

    # Read and verify each location
    for line, elem, expected_value in test_values:
        # Enable read for specific line and set read_elem
        dut.read_enable.value = (1 << line)  # Set bit for the line we want to read

        # Set the read_elem value for the specific line
        # Each line's read_elem is 2 bits, positioned at [2*line+1:2*line]
        read_elem_value = 0
        for i in range(4):
            if i == line:
                read_elem_value |= (elem << (i * 2))
            else:
                read_elem_value |= (0 << (i * 2))
        dut.read_elem.value = read_elem_value

        # Wait a small time for combinational logic to propagate
        await Timer(1, units="ns")

        # Extract the correct segment from data_out
        # Each output is 8 bits, positioned at [8*line+7:8*line]
        actual_value = (dut.data_out.value >> (line * 8)) & 0xFF
        assert actual_value == expected_value, f"Read mismatch at line={line}, elem={elem}: expected {expected_value}, got {actual_value}"

    dut.log.info("All memory read/write tests passed!")


@cocotb.test()
async def test_memory_concurrent_read(dut):
    """
    Test concurrent read from different locations:
    - Write different values to multiple locations
    - Read from multiple locations simultaneously
    - Verify all read values match expected values
    """
    # Create a clock and start it
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the memory
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Fill memory with known test pattern
    test_matrix = []
    for line in range(4):
        row = []
        for elem in range(4):
            value = (line * 16) + (elem * 4) + 10  # Simple pattern
            row.append(value)

            # Write to memory
            dut.write_enable.value = 1
            dut.write_line.value = line
            dut.write_elem.value = elem
            dut.data_in.value = value
            await RisingEdge(dut.clk)
        test_matrix.append(row)

    dut.write_enable.value = 0
    await RisingEdge(dut.clk)

    # Test concurrent read from all lines
    # Read different elements from each line simultaneously
    test_reads = [
        (0, 1),  # Line 0, Element 1
        (1, 2),  # Line 1, Element 2
        (2, 0),  # Line 2, Element 0
        (3, 3)  # Line 3, Element 3
    ]

    # Enable all reads
    dut.read_enable.value = 0b1111

    # Set read_elem for each line using the packed format
    read_elem_value = 0
    for line, (_, elem) in enumerate(test_reads):
        read_elem_value |= (elem << (line * 2))
    dut.read_elem.value = read_elem_value

    # Wait for combinational logic
    await Timer(1, units="ns")

    # Verify all outputs
    for line, (_, elem) in enumerate(test_reads):
        expected = test_matrix[line][elem]
        actual = (dut.data_out.value >> (line * 8)) & 0xFF
        assert actual == expected, f"Concurrent read failed: line={line}, elem={elem}, expected={expected}, got={actual}"

    dut.log.info("Concurrent read test passed!")


@cocotb.test()
async def test_memory_reset(dut):
    """
    Test memory reset functionality:
    - Write values to memory
    - Apply reset
    - Verify all memory locations are cleared to zero
    """
    # Create a clock and start it
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize without reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Write non-zero values to all memory locations
    for line in range(4):
        for elem in range(4):
            dut.write_enable.value = 1
            dut.write_line.value = line
            dut.write_elem.value = elem
            dut.data_in.value = 0xFF  # Write all 1s
            await RisingEdge(dut.clk)

    dut.write_enable.value = 0
    await RisingEdge(dut.clk)

    # Apply reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Read and verify all locations are zero
    dut.read_enable.value = 0b1111

    for line in range(4):
        for elem in range(4):
            # Set read element for all lines (we're only checking one element at a time)
            read_elem_value = 0
            for i in range(4):
                if i == line:
                    read_elem_value |= (elem << (i * 2))
            dut.read_elem.value = read_elem_value

            # Wait for combinational logic
            await Timer(1, units="ns")

            # Verify output is zero for the specific line
            actual = (dut.data_out.value >> (line * 8)) & 0xFF
            assert actual == 0, f"Reset failed: memory[{line}][{elem}] is not zero"

    dut.log.info("Reset test passed!")


@cocotb.test()
async def test_memory_read_enable(dut):
    """
    Test read enable functionality:
    - Write values to memory
    - Test different read_enable patterns
    - Verify that only enabled lines output data, disabled lines output zero
    """
    # Create a clock and start it
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Write unique values to all memory locations
    for line in range(4):
        for elem in range(4):
            value = (line + 1) * (elem + 1) * 10  # Unique pattern

            dut.write_enable.value = 1
            dut.write_line.value = line
            dut.write_elem.value = elem
            dut.data_in.value = value & 0xFF  # Ensure 8-bit value
            await RisingEdge(dut.clk)

    dut.write_enable.value = 0
    await RisingEdge(dut.clk)

    # Test different read_enable patterns
    test_patterns = [
        0b0001,  # Only line 0 enabled
        0b0010,  # Only line 1 enabled
        0b0100,  # Only line 2 enabled
        0b1000,  # Only line 3 enabled
        0b1010,  # Lines 1 and 3 enabled
        0b0101,  # Lines 0 and 2 enabled
        0b1111  # All lines enabled
    ]

    for pattern in test_patterns:
        dut.read_enable.value = pattern

        # Set all read_elem to 2 (same as original test)
        read_elem_value = 0
        for line in range(4):
            read_elem_value |= (2 << (line * 2))  # Set element 2 for all lines
        dut.read_elem.value = read_elem_value

        # Wait for combinational logic
        await Timer(1, units="ns")

        # Check outputs
        for line in range(4):
            # Extract the correct segment from data_out
            actual = (dut.data_out.value >> (line * 8)) & 0xFF

            if pattern & (1 << line):
                # This line should output the value at mem[line][2]
                expected = (line + 1) * (2 + 1) * 10 & 0xFF
                assert actual == expected, f"Read failed with pattern {bin(pattern)}: line={line}, expected={expected}, got={actual}"
            else:
                # This line should output zeros
                assert actual == 0, f"Line {line} not properly disabled: expected 0, got {actual}"

    dut.log.info("Read enable test passed!")