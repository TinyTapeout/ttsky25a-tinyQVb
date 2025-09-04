# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

# When submitting your design, change this to 16 + the peripheral number
# in peripherals.v.  e.g. if your design is i_user_simple00, set this to 16.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 24

# @cocotb.test()
# async def test_project(dut):
#     dut._log.info("Start")

#     # Set the clock period to 100 ns (10 MHz)
#     clock = Clock(dut.clk, 100, units="ns")
#     cocotb.start_soon(clock.start())

#     # Interact with your design's registers through this TinyQV class.
#     # This will allow the same test to be run when your design is integrated
#     # with TinyQV - the implementation of this class will be replaces with a
#     # different version that uses Risc-V instructions instead of the SPI 
#     # interface to read and write the registers.
#     tqv = TinyQV(dut, PERIPHERAL_NUM)

#     # Reset, always start the test by resetting TinyQV
#     await tqv.reset()

#     dut._log.info("Test project behavior")

#     # Test register write and read back
#     await tqv.write_reg(0, 20)
#     assert await tqv.read_reg(0) == 20

#     # Set an input value, in the example this will be added to the register value
#     dut.ui_in.value = 30

#     # Wait for two clock cycles to see the output values, because ui_in is synchronized over two clocks,
#     # and a further clock is required for the output to propagate.
#     await ClockCycles(dut.clk, 3)

#     # The following assertion is just an example of how to check the output values.
#     # Change it to match the actual expected output of your module:
#     assert dut.uo_out.value == 50

#     # Keep testing the module by changing the input values, waiting for
#     # one or more clock cycles, and asserting the expected output values.
# SPDX-FileCopyrightText: © 2025 Kushal
# SPDX-License-Identifier: Apache-2.0

# import cocotb
# from cocotb.clock import Clock
# from cocotb.triggers import ClockCycles

# from tqv import TinyQV

# PERIPHERAL_NUM = 16
# Register addresses (byte-wide, match Verilog)

REG_CTRL       = 0x0
REG_STATUS     = 0x1
REG_INPUT      = 0x2
REG_ACC_LOW    = 0x3
REG_ACC_HIGH   = 0x4
REG_THRESH     = 0x5
REG_DECAYSHIFT = 0x6


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start Integrator Peripheral Test")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Interact with your design's registers through this TinyQV class.
    # This will allow the same test to be run when your design is integrated
    # with TinyQV - the implementation of this class will be replaces with a
    # different version that uses Risc-V instructions instead of the SPI 
    # interface to read and write the registers.
    tqv = TinyQV(dut, PERIPHERAL_NUM)

    # Reset, always start the test by resetting TinyQV
    await tqv.reset()

    # Reset, always start with reset
    await tqv.reset()
    await ClockCycles(dut.clk, 5)

    dut._log.info("Check reset state")
    assert await tqv.read_reg(REG_CTRL) == 0
    assert await tqv.read_reg(REG_STATUS) == 0
    assert await tqv.read_reg(REG_ACC_LOW) == 0
    assert await tqv.read_reg(REG_ACC_HIGH) == 0

    # Enable integrator
    dut._log.info("Enable integrator and add +5 repeatedly")
    await tqv.write_reg(REG_CTRL, 0x1)   # bit0 = enable

    for i in range(5):
        await tqv.write_reg(REG_CTRL, 0x0)    # BOTH enable and strobe low -- "idle"
        await ClockCycles(dut.clk, 1)         # Wait clk (idle)
        await tqv.write_reg(REG_INPUT, 5)     # Set sample
        await tqv.write_reg(REG_CTRL, 0x3)    # Assert enable+strobe
        await ClockCycles(dut.clk, 1)         # Sample
        await tqv.write_reg(REG_CTRL, 0x1)    # Clear strobe (enable only)
        await ClockCycles(dut.clk, 1)         # Wait

    acc_lo = await tqv.read_reg(REG_ACC_LOW)
    acc_hi = await tqv.read_reg(REG_ACC_HIGH)
    acc_val = (acc_hi << 8) | acc_lo
    dut._log.info(f"Accumulator after 5 samples of +5 = {acc_val}")
    assert acc_val == 25

    # Apply a negative input (-5 = 0xFB in 8-bit two's complement)
    dut._log.info("Add -5 to accumulator")
    await tqv.write_reg(REG_INPUT, 0xFB)
    await tqv.write_reg(REG_CTRL, 0x3)
    await ClockCycles(dut.clk, 1)
    await tqv.write_reg(REG_CTRL, 0x1)

    acc_lo = await tqv.read_reg(REG_ACC_LOW)
    acc_hi = await tqv.read_reg(REG_ACC_HIGH)
    acc_val = (acc_hi << 8) | acc_lo
    dut._log.info(f"Accumulator after adding -5 = {acc_val}")
    assert acc_val == 20

    # Test threshold
    dut._log.info("Check threshold flag")
    await tqv.write_reg(REG_THRESH, 15)
    status = await tqv.read_reg(REG_STATUS)
    dut._log.info(f"STATUS = {status:02x}")
    assert (status & 0x2) != 0  # bit1 = threshold flag

    # Test overflow/saturation
    dut._log.info("Check overflow flag with saturation")
    await tqv.write_reg(REG_CTRL, 0x9)  # enable + sat_enable
    for _ in range(260):
        await tqv.write_reg(REG_INPUT, 127)
        await tqv.write_reg(REG_CTRL, 0xB)  # enable+strobe+sat
        await ClockCycles(dut.clk, 1)
        await tqv.write_reg(REG_CTRL, 0x9)

    status = await tqv.read_reg(REG_STATUS)
    dut._log.info(f"STATUS after saturation = {status:02x}")
    assert (status & 0x1) != 0  # bit0 = overflow flag

    dut._log.info("Integrator peripheral test PASSED")