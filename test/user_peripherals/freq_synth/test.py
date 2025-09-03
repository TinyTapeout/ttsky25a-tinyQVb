# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 5

gate_level = 'GATES' in os.environ
integration = 'user_peripherals' in os.environ['MODULE']

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Interact with your design's registers through this TinyQV class.
    # This will allow the same test to be run when your design is integrated
    # with TinyQV - the implementation of this class will be replaces with a
    # different version that uses Risc-V instructions instead of the SPI test
    # harness interface to read and write the registers.
    tqv = TinyQV(dut, PERIPHERAL_NUM)

    # Reset
    await tqv.reset()

    dut._log.info("Test project behavior")

    # Test register write and read back

    for i in range(8):
        print(f"Testing register {i}")
        val = (0x2f7c9648b1d5ea03 >> i) & 0xffffffff
        await tqv.write_word_reg(4*i, val)
        if i == 4:
            val &= 0xf
        elif i > 4:
            val &= 0x1f
        assert await tqv.read_word_reg(4*i) == val

