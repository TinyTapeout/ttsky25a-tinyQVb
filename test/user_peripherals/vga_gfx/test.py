# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 4

async def reset_all_registers(tqv):
    for i in range(0, 64, 4):
        await tqv.write_word_reg(i, 0)

    # Interrupt every 4th line at the end of the line
    await tqv.write_byte_reg(1, 0xc)
        
    # Colours are red, green and blue
    await tqv.write_byte_reg(5, 0x30)
    await tqv.write_byte_reg(6, 0x0c)
    await tqv.write_byte_reg(7, 0x03)

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 15.624 ns (64 MHz)
    clock = Clock(dut.clk, 15.624, units="ns")
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

    await reset_all_registers(tqv)

    # Test register write and read back
    await tqv.write_word_reg(0, 0x82345678)
    assert await tqv.read_byte_reg(0) == 0x78
    assert await tqv.read_hword_reg(0) == 0x5678
    assert await tqv.read_word_reg(0) == 0x82345678

    # Wait for line 4
    while True:
        y_low = await tqv.read_byte_reg(2)
        assert y_low <= 4
        if y_low == 4: break

    # Clear and then wait for interrupt
    assert await tqv.read_byte_reg(1) == 0xc
    await tqv.write_byte_reg(1, 0x1c)

    while True:
        y_low = await tqv.read_byte_reg(2)
        assert y_low < 8
        interrupt_asserted = await tqv.is_interrupt_asserted()
        if y_low < 7: assert not interrupt_asserted
        if interrupt_asserted: break
        await ClockCycles(dut.clk, 64)

    # Read interrupt reg to clear
    assert await tqv.read_byte_reg(1) == 0x1c
    assert not await tqv.is_interrupt_asserted()

    # Check colour generation
    for i in range(0, 64, 4):
        await tqv.write_word_reg(i, 0x39393939)

    # Wait for hsync
    while True:
        if dut.uo_out[7].value == 0: break
        await ClockCycles(dut.clk, 64)

    while True:
        assert dut.uo_out[6].value == 0
        assert dut.uo_out[5].value == 0
        assert dut.uo_out[4].value == 0
        assert dut.uo_out[3].value == 1
        assert dut.uo_out[2].value == 0
        assert dut.uo_out[1].value == 0
        assert dut.uo_out[0].value == 0
        if dut.uo_out[7].value == 1: break
        await ClockCycles(dut.clk, 1)
    
    for k in range(3):
        # Should now be 160 clocks before the first pixel
        for i in range(160):
            assert dut.uo_out.value == 0b10001000
            await ClockCycles(dut.clk, 1)

        for i in range(0, 1024, 16):
            for j in range(4):
                assert dut.uo_out.value == 0b10011001 # Red
                await ClockCycles(dut.clk, 1)
            for j in range(4):
                assert dut.uo_out.value == 0b10101010 # Green
                await ClockCycles(dut.clk, 1)
            for j in range(4):
                assert dut.uo_out.value == 0b11001100 # Blue
                await ClockCycles(dut.clk, 1)
            for j in range(4):
                assert dut.uo_out.value == 0b10001000 # Black
                await ClockCycles(dut.clk, 1)

        # Should now be 24 clocks before sync
        for i in range(24):
            assert dut.uo_out.value == 0b10001000
            await ClockCycles(dut.clk, 1)

        # Should now be 136 clocks of sync
        for i in range(136):
            assert dut.uo_out.value == 0b00001000
            await ClockCycles(dut.clk, 1)
