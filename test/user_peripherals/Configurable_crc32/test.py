# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

import binascii
from random import randbytes

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 6

# CRC testing function
async def crc32_test(tqv, dut, data, poly, ref, xor, init):
    # Step 1: reset peripheral via config
    await tqv.write_byte_reg(0x0,0x0)

    config = (ref) | (xor << 1) | (init << 2)
    await tqv.write_byte_reg(0x4, config) #RefIn RefOut high, XOR output
    await tqv.write_word_reg(0x10, poly)

    # Step 2: Enable peripheral input and start sending data
    await tqv.write_byte_reg(0x0, 0xFF)
    for byte in data:
        await tqv.write_byte_reg(0x8, int(byte))
        await ClockCycles(dut.clk, 10)
    return await tqv.read_word_reg(0xC)

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

    dut._log.info("Test protocols with same generic input")

    # crc_test signature:
    # tqv, dut, data, poly, ref, xor, init

    # AIXM
    out = await crc32_test(tqv, dut, b'123456789', 0x814141AB, 0, 0, 0)
    assert out == 0x3010BF7F, "AIXM"

    # AUTOSAR
    out = await crc32_test(tqv, dut, b'123456789', 0xF4ACFB13, 1, 1, 1)
    assert out == 0x1697D06A, "AUTOSAR"

    # BASE91-D
    out = await crc32_test(tqv, dut, b'123456789', 0xA833982B, 1, 1, 1)
    assert out == 0x87315576, "BASE91-D"

    # BZIP2
    out = await crc32_test(tqv, dut, b'123456789', 0x04C11DB7, 0, 1, 1)
    assert out == 0xFC891918, "BZIP2"

    # CD-ROM-EDC
    out = await crc32_test(tqv, dut, b'123456789', 0x8001801B, 1, 0, 0)
    assert out == 0x6EC2EDC4, "CD-ROM-EDC"

    # CKSUM
    out = await crc32_test(tqv, dut, b'123456789', 0x04C11DB7, 0, 1, 0)
    assert out == 0x765E7680, "CKSUM"

    # ISCSI 
    out = await crc32_test(tqv, dut, b'123456789', 0x1EDC6F41, 1, 1, 1)
    assert out == 0xE3069283, "ISCSI"

    # ISO-HDLC
    out = await crc32_test(tqv, dut, b'123456789', 0x04C11DB7, 1, 1, 1)
    assert out == 0xCBF43926, "ISO-HDLC"

    # JAMCRC
    out = await crc32_test(tqv, dut, b'123456789', 0x04C11DB7, 1, 0, 1)
    assert out == 0x340BC6D9, "JAMCRC"

    # MEF
    out = await crc32_test(tqv, dut, b'123456789', 0x741B8CD7, 1, 0, 1)
    assert out == 0xD2C22F51, "MEF"

    # MPEG-2
    out = await crc32_test(tqv, dut, b'123456789', 0x04C11DB7, 0, 0, 1)
    assert out == 0x0376E6E7, "MPEG-2"

    # XFER
    out = await crc32_test(tqv, dut, b'123456789', 0x000000AF, 0, 0, 0)
    assert out == 0xBD0BE338, "XFER"
    

@cocotb.test()
async def test_random_inputs(dut):
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

    dut._log.info("Test ISO-HDLC protocol with random inputs")

    TESTS=100

    for i in range(TESTS):
        data = randbytes(16)
        out = await crc32_test(tqv, dut, data, 0x04C11DB7, 1, 1, 1)
        crc_cmp = binascii.crc32(data)
        assert crc_cmp == out, f"Failed assertion on iteration {i}, data {data}"
