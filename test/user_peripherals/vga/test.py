# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 12

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
    # await tqv.write_word_reg(0,  0) #x82345678)
    await tqv.write_word_reg(0,  0)
    await tqv.write_word_reg(4,  0x01010101)
    await tqv.write_word_reg(8,  0x08080808)
    await tqv.write_word_reg(12, 0x0A0A0A0A) # 128
    await tqv.write_word_reg(16, 0x0F0F0F0F)
    await tqv.write_word_reg(20, 0x10101010)
    await tqv.write_word_reg(24, 0x80808080)
    await tqv.write_word_reg(28, 0xFFFFFFFF) # 256
    await tqv.write_word_reg(32, 0x1AAAAAAA)
    await tqv.write_word_reg(36, 0x2A1A1A1A)
    await tqv.write_word_reg(40, 0x3A8A8A8A)
    await tqv.write_word_reg(44, 0x4AFAFAFA) # 320
    # await ClockCycles(dut.clk, 1)

    async def measure_hsync():
        cycles_pre = 0
        out_pre = dut.uo_out.value
        while (dut.uo_out.value & 0x80 == 0x80):
            await ClockCycles(dut.clk, 1)
            cycles_pre += 1
        cycles = 0
        out_mid = dut.uo_out.value
        while (dut.uo_out.value & 0x80 != 0x80):
            await ClockCycles(dut.clk, 1)
            cycles += 1
        print("pre-hsync out:", out_pre, "cycles:", cycles_pre, "hsync out:", out_mid, "cycles:", cycles)
        return cycles
    Y=1
    assert await tqv.read_word_reg(0x0) == Y+0
    await measure_hsync()

    assert await tqv.read_word_reg(0x0)  == Y+1
    assert await tqv.read_word_reg(0x10) == Y+1
    await measure_hsync()
    assert await tqv.read_word_reg(0x0) == Y+2
    await measure_hsync()
    assert await tqv.read_word_reg(0x0) == Y+3
    await measure_hsync()
    assert await tqv.read_word_reg(0x0) == Y+4
    await measure_hsync()

    while ((await tqv.read_word_reg(0x0)) < 32):
        y = (await tqv.read_word_reg(0x10))
        if (y % 16 == 0):
            print(y)
        await measure_hsync()

    return

    while ((await tqv.read_word_reg(0x0)) < 64):
        y = (await tqv.read_word_reg(0x10))
        if (y % 16 == 0):
            print(y)
        await measure_hsync()

    await tqv.write_word_reg(60, 0b0000_1000) # color mode 

    while ((await tqv.read_word_reg(0x0)) < 128):
        y = (await tqv.read_word_reg(0x10))
        if (y % 16 == 0):
            print(y)
        await measure_hsync()

    await tqv.write_word_reg(52, 320) # vram stride
    await tqv.write_word_reg(56, (2<<16) | (960//320-1)) # pixel size
    await tqv.write_word_reg(60, 0b0000_1100) # color + 960 mode 

    while ((await tqv.read_word_reg(0x0)) < 140):
        y = (await tqv.read_word_reg(0x10))
        if (y % 16 == 0):
            print(y)
        await measure_hsync()

