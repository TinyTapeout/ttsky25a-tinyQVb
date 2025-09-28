
# Copyright (c) 2025 Tasmin Khan
# SPDX-License-Identifier: Apache-2.0

import cocotb
import random
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 10


@cocotb.test()
async def test_reset_and_default_values(dut):
    dut._log.info("Starting reset and default values test")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Interact with your design's registers through this TinyQV class.
    # This will allow the same test to be run when your design is integrated
    # with TinyQV - the implementation of this class will be replaces with a
    # different version that uses Risc-V instructions instead of the SPI test
    # harness interface to read and write the registers.
    tqv = TinyQV(dut, PERIPHERAL_NUM)

    # Reset the design
    await tqv.reset()
    await ClockCycles(dut.clk, 5)


    # Address 0x00: yout_reg should be 0
    yout_default = await tqv.read_word_reg(0x00) 
    dut._log.info(f"Default yout_reg: {yout_default}")
    assert yout_default == 0, f"Expected yout_reg=0, got {yout_default}"

    # Address 0x04: Gain register should have gL=gM=gH=255
    gain_default = await tqv.read_word_reg(0x04)  
    dut._log.info(f"Default gain register: 0x{gain_default:08x}")

    # Extract individual gains: {8'h0, gH, gM, gL}
    gL = gain_default & 0xFF
    gM = (gain_default >> 8) & 0xFF  
    gH = (gain_default >> 16) & 0xFF
    
    dut._log.info(f"Default gains - gL: {gL}, gM: {gM}, gH: {gH}")
    assert gL == 255, f"Expected gL=255, got {gL}"
    assert gM == 255, f"Expected gM=255, got {gM}" 
    assert gH == 255, f"Expected gH=255, got {gH}"

    # Address 0x08: x[0] should be 0
    x0_default = await tqv.read_word_reg(0x08) 
    dut._log.info(f"Default x[0]: {x0_default}")
    assert x0_default == 0, f"Expected x[0]=0, got {x0_default}"
    
    # Address 0x0C: yL[1] should be 0  
    yl_default = await tqv.read_word_reg(0x0C)  
    dut._log.info(f"Default yL[1]: {yl_default}")
    assert yl_default == 0, f"Expected yL[1]=0, got {yl_default}"

    # Address 0x10: yM[1] should be 0
    ym_default = await tqv.read_word_reg(0x10)  
    dut._log.info(f"Default yM[1]: {ym_default}")
    assert ym_default == 0, f"Expected yM[1]=0, got {ym_default}"

    # Address 0x14: yH[1] should be 0
    yh_default = await tqv.read_word_reg(0x14)  
    dut._log.info(f"Default yH[1]: {yh_default}")
    assert yh_default == 0, f"Expected yH[1]=0, got {yh_default}"

    dut._log.info("Reset and default values test PASSED")


@cocotb.test() 
async def test_gain_write_and_register_clear(dut):
    dut._log.info("Gain write/read and data register clear test")
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()
    await ClockCycles(dut.clk, 5)
    
    # Generate random gain values (1-255 to avoid zero gains)
    random_gL = random.randint(1, 255)
    random_gM = random.randint(1, 255) 
    random_gH = random.randint(1, 255)
    dut._log.info(f"Generated random gains - gL: {random_gL}, gM: {random_gM}, gH: {random_gH}")

    # Write random gains using control bits [26:24] = 111 to update all gains
    gain_control_word = (0x7 << 24) | (random_gH << 16) | (random_gM << 8) | random_gL
    dut._log.info(f"Writing gain control word: 0x{gain_control_word:08x}")

    await tqv.write_word_reg(0x04, gain_control_word)
    await ClockCycles(dut.clk, 5)

    # Verify gains were written correctly
    gain_readback = await tqv.read_word_reg(0x04)
    read_gL = gain_readback & 0xFF
    read_gM = (gain_readback >> 8) & 0xFF
    read_gH = (gain_readback >> 16) & 0xFF

    dut._log.info(f"Readback gains - gL: {read_gL}, gM: {read_gM}, gH: {read_gH}")
    assert read_gL == random_gL, f"gL mismatch: expected {random_gL}, got {read_gL}"
    assert read_gM == random_gM, f"gM mismatch: expected {random_gM}, got {read_gM}"
    assert read_gH == random_gH, f"gH mismatch: expected {random_gH}, got {read_gH}"
    
    # Generate random input data (non-zero to ensure processing)
    random_input = random.randint(100, 32000)  # Reasonable range for 16-bit signed
    dut._log.info(f"Generated random input: {random_input}")
    
    # Write input data to trigger processing
    await tqv.write_word_reg(0x08, random_input)

    # Read output and verify it's non-zero (filter should produce some output)
    output_result = await tqv.read_word_reg(0x00)
    dut._log.info(f"Filter output: {output_result}")
    assert output_result != 0, f"Expected non-zero output, got {output_result}"

    # Test register clear (bit 28) - should clear filter delays but keep gains
    dut._log.info("Testing register clear functionality...")
    clear_control_word = (1 << 28)  # Only set bit 28 for register clear
    await tqv.write_word_reg(0x04, clear_control_word)

    # After clear, output should be zero (no signal in delay line)
    cleared_output = await tqv.read_word_reg(0x00)
    dut._log.info(f"Output after clear: {cleared_output}")
    assert cleared_output == 0, f"Expected zero output after clear, got {cleared_output}"

    # Verify input register x[0] is also cleared
    cleared_input = await tqv.read_word_reg(0x08)  
    dut._log.info(f"Input x[0] after clear: {cleared_input}")
    assert cleared_input == 0, f"Expected x[0]=0 after clear, got {cleared_input}"

    # Verify filter outputs are cleared
    filter_outputs = []
    for addr in [0x0C, 0x10, 0x14]:  # yL[1], yM[1], yH[1]
        output = await tqv.read_word_reg(addr)
        filter_outputs.append(output)
    dut._log.info(f"Filter outputs after clear: yL[1]={filter_outputs[0]}, yM[1]={filter_outputs[1]}, yH[1]={filter_outputs[2]}")
    for i, output in enumerate(filter_outputs):
        assert output == 0, f"Expected filter output {i} = 0 after clear, got {output}"

    # Most importantly: verify gains are UNCHANGED after register clear
    final_gain_check = await tqv.read_word_reg(0x04)
    final_gL = final_gain_check & 0xFF
    final_gM = (final_gain_check >> 8) & 0xFF
    final_gH = (final_gain_check >> 16) & 0xFF

    dut._log.info(f"Final gain check - gL: {final_gL}, gM: {final_gM}, gH: {final_gH}")
    assert final_gL == random_gL, f"Gain gL changed after clear: expected {random_gL}, got {final_gL}"
    assert final_gM == random_gM, f"Gain gM changed after clear: expected {random_gM}, got {final_gM}"
    assert final_gH == random_gH, f"Gain gH changed after clear: expected {random_gH}, got {final_gH}"
    

