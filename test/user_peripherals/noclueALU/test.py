# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV


PERIPHERAL_NUM = 19

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

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

    dut._log.info("Test project behavior")

    # Testing register write and read back
    await tqv.write_reg(0, 20)
    await ClockCycles(dut.clk, 1)
    assert await tqv.read_reg(0) == 20
    await tqv.write_reg(1, 30)
    await ClockCycles(dut.clk, 1)
    assert await tqv.read_reg(1) == 30
    await tqv.write_reg(2, 40)
    await ClockCycles(dut.clk, 1)
    assert await tqv.read_reg(2) == 40

    
    #Testing ALU operations
    #Setting the operands
    await tqv.write_reg(0, 6)
    await tqv.write_reg(1, 9)
    #Testing ADD
    await tqv.write_reg(2, 0)
    await ClockCycles(dut.clk, 1)
    assert await tqv.read_reg(3) == 15
    #Testing SUB
    await tqv.write_reg(2, 1)
    await ClockCycles(dut.clk, 1)
    assert await tqv.read_reg(3) == 3
    #Testing AND
    await tqv.write_reg(2, 2)
    await ClockCycles(dut.clk, 1)
    assert await tqv.read_reg(3) == 0
    #Testing OR
    await tqv.write_reg(2, 3)
    await ClockCycles(dut.clk, 1)
    assert await tqv.read_reg(3) == 15
    
