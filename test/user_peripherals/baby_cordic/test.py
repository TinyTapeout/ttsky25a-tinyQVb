# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV
import math
import struct
import random

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 8

def float_to_spi_word(x: float) -> int:
    if math.isnan(x):
        return 0x7FC00000
    if math.isinf(x):
        return 0x7F800000 if x > 0 else 0xFF800000
    return struct.unpack(">I", struct.pack(">f", x))[0]

def spi_word_to_float(u: int) -> float:
    return struct.unpack(">f", struct.pack(">I", u & 0xFFFFFFFF))[0]

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    tqv = TinyQV(dut, PERIPHERAL_NUM)

    rng = random.Random(12345)

    valid_angles = [rng.uniform(-math.pi, math.pi) for i in range(100)]

    # Reset
    await tqv.reset()
    await ClockCycles(dut.clk, 3)

    # We shouldn't block on a read before a write...
    r0 = await tqv.read_word_reg(0x02)
    assert r0 == 0x00000000, f"Empty read should return 0x0: actual {r0:08X}"

    dut._log.info("Started testing valid angles.")
    for idx, a in enumerate(valid_angles):
        # --- VALID SIN INPUTS ---
        await tqv.write_byte_reg(0x01, 0x01)            # CTRL: 1=cos
        await tqv.write_word_reg(0x00, float_to_spi_word(a))      
        spi_out = await tqv.read_word_reg(0x02) 
        cos_res = spi_word_to_float(spi_out)    
        assert abs(cos_res - math.cos(a)) < 2e-3, f"cos mismatch -  \n angle: {a:.4f} \n expected: {math.cos(a):.4f} \n actual: {cos_res: .4f} "  

        # --- VALID COS INPUTS ---
        await tqv.write_byte_reg(0x01, 0x00)            # CTRL: 0=sin
        await tqv.write_word_reg(0x00, float_to_spi_word(a))      
        spi_out = await tqv.read_word_reg(0x02) 
        sin_res = spi_word_to_float(spi_out)        
        assert abs(sin_res - math.sin(a)) < 2e-3, f"sin mismatch - \n angle: {a:.4f} \n expected: {math.sin(a):.4f} \n actual: {sin_res: .4f} " 

    # --- INVALID INPUTS ---
    invalid_angles = [math.nan, math.inf, -math.inf] + [(math.pi*1.01)*(1 if rng.random()<0.5 else -1)*rng.uniform(1,10) for _ in range(100)]

    dut._log.info("Started testing invalid angles.")
    for idx, a in enumerate(invalid_angles):
        # --- VALID SIN INPUTS ---
        await tqv.write_byte_reg(0x01, 0x01)            # CTRL: 1=cos
        await tqv.write_word_reg(0x00, float_to_spi_word(a))      
        spi_out = await tqv.read_word_reg(0x02)  
        assert spi_out == 0x7FC00000, f"Invalid angle mismatch (cos): \n input: {a:.4f} \n {spi_word_to_float(spi_out):.4f}"

        # --- VALID COS INPUTS ---
        await tqv.write_byte_reg(0x01, 0x00)            # CTRL: 0=sin
        await tqv.write_word_reg(0x00, float_to_spi_word(a))      
        spi_out = await tqv.read_word_reg(0x02) 
        spi_out = await tqv.read_word_reg(0x02)  
        assert spi_out == 0x7FC00000, f"Invalid angle mismatch (sin): \n input: {a:.4f} \n {spi_word_to_float(spi_out):.4f}"
