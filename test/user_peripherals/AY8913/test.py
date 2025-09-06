# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

# When submitting your design, change this to 16 + the peripheral number
# in peripherals.v.  e.g. if your design is i_user_simple00, set this to 16.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 20

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

    for reg in range(15):
        await set_register(tqv, reg, 0)

    await set_mixer(tqv, tones_on='A')
    await set_volume(tqv, 'A', 15)
    await set_tone(tqv, 'A', period=1)

    await ClockCycles(dut.clk, 10000)

    await set_mixer(tqv, tones_on='A')
    await set_volume(tqv, 'A', 8)
    await set_tone(tqv, 'A', period=2)

    await ClockCycles(dut.clk, 10000)

    await set_mixer(tqv, tones_on='ABC')
    await set_volume(tqv, 'A', 10)
    await set_volume(tqv, 'B', 11)
    await set_volume(tqv, 'C', 12)
    await set_tone(tqv, 'A', period=10)
    await set_tone(tqv, 'B', period=20)
    await set_tone(tqv, 'C', period=40)

    await ClockCycles(dut.clk, 30000)

    # # Test register write and read back
    # await tqv.write_reg(0, 20)
    # assert await tqv.read_reg(0) == 20

    # # Set an input value, in the example this will be added to the register value
    # dut.ui_in.value = 30

    # # Wait for two clock cycles to see the output values, because ui_in is synchronized over two clocks,
    # # and a further clock is required for the output to propagate.
    # await ClockCycles(dut.clk, 3)

    # # The following assertion is just an example of how to check the output values.
    # # Change it to match the actual expected output of your module:
    # assert dut.uo_out.value == 50

    # # Keep testing the module by changing the input values, waiting for
    # # one or more clock cycles, and asserting the expected output values.


# async def reset(dut):
#     master_clock = MASTER_CLOCK # // 8
#     cycle_in_nanoseconds = 1e9 / master_clock # 1 / 2Mhz / nanosecond
#     dut._log.info("start")
#     clock = Clock(dut.clk, cycle_in_nanoseconds, units="ns")
#     cocotb.start_soon(clock.start())

#     dut.uio_in.value =       0b1111_1111 # Emulate pull-ups on BIDIRECTIONAL pins

#     dut._log.info("reset")
#     dut.rst_n.value = 0
#     await ClockCycles(dut.clk, 10)
#     dut.rst_n.value = 1

async def set_register(tqv, reg, val):
    await tqv.write_reg(reg, val)

def channel_index(channel):
    if channel == 'A' or channel == 'a':
        channel = 0
    elif channel == 'B' or channel == 'b':
        channel = 1
    elif channel == 'C' or channel == 'c':
        channel = 2
    assert 0 <= channel and channel <= 2
    return channel

def inverted_channel_mask(channels):
    mask = 0
    if isinstance(channels, str):
        mask |= 1 if 'A' in channels or 'a' in channels else 0
        mask |= 2 if 'B' in channels or 'b' in channels else 0
        mask |= 4 if 'C' in channels or 'c' in channels else 0
    else:
        mask = channels
    assert 0 <= mask and mask <= 7
    return ~mask & 7

async def set_tone(dut, channel, frequency=-1, period=-1):
    channel = channel_index(channel)
    if frequency > 0:
        period = MASTER_CLOCK // (16 * frequency)
    assert 0 <= period  and period <= 4095
    await set_register(dut, channel*2+0, period & 0xFF)         # Tone A/B/C: set fine tune period
    if period > 0xFF:
        await set_register(dut, channel*2+1, period >> 8)       # Tone A/B/C: set coarse tune period

async def set_noise(dut, frequency=-1, period=-1):
    if frequency > 0:
        period = MASTER_CLOCK // (16 * frequency)
    assert 0 <= period and period <= 31
    await set_register(dut, 6, period & 31)                     # Noise: set period

async def set_mixer(dut, noises_on=0b000, tones_on=0b000):
    await set_register(dut, 7, (inverted_channel_mask(noises_on) << 3) | inverted_channel_mask(tones_on))

async def set_mixer_off(dut):
    await set_mixer(dut, noises_on=0, tones_on=0)

async def set_volume(dut, channel, vol=0, envelope=False):
    channel = channel_index(channel)
    if vol < 0:
        envelope = True
        vol = 0
    assert 0 <= channel and channel <= 2
    assert 0 <= vol     and vol <= 15
    await set_register(dut, 8+channel, (16 if envelope else 0) | vol)

async def set_envelope(dut, frequency=-1, period=-1, shape=-1):
    if frequency > 0:
        period = MASTER_CLOCK // (256 * frequency)
    if period >= 0:
        assert 0 <= period and period <= 65535
        await set_register(dut, 11, period & 0xFF)          # Envelope: set fine tune period
        if period > 0xFF:
            await set_register(dut, 12, period >> 8)        # Envelope: set coarse tune period
    if isinstance(shape, str):
        shape ={r"\_ ": 0,
                r"\_ ": 1,
                r"\_ ": 2,
                r"\_ ": 3,
                r"/_ ": 4,
                r"/_ ": 5,
                r"/_ ": 6,
                r"/_ ": 7,
                r"\\ ": 8,
                r"\_ ": 9,
                r"\/ ":10,
                r"\` ":11,
                r"// ":12,
                r"/` ":13,
                r"/\ ":14,
                r"/_ ":15}[shape[:2]+' ']
    if shape >= 0:
        assert 0 <= shape and shape <= 15
        await set_register(dut, 13, shape)                      # Envelope: set shape

