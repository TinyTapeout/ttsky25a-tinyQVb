# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

from tqv import TinyQV

# When submitting your design, change this to 16 + the peripheral number
# in peripherals.v.  e.g. if your design is i_user_simple00, set this to 16.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 21
ASSERT = 1

async def pin_change(dut, pin, value, timeout=10000):
    for i in range(timeout):
        await ClockCycles(dut.clk, 1)
        if pin == value:
            break
    else:
        dut._log.error("timeout waiting for pin")
        exit(1)

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

    pwm_strobes = [(0, 1), (2, 3), (5,6)]
    # Test PWM
    for pwm_strobe, clock_cycles in pwm_strobes:
        for pwm_value in [1, 10, 100, 200]:
            dut._log.info(f"set PWM channels to {pwm_value}")
            await tqv.write_reg(0, pwm_value)
            assert await tqv.read_reg(0) == pwm_value 
            await tqv.write_reg(1, pwm_value)
            assert await tqv.read_reg(1) == pwm_value 
            dut._log.info(f"set PWM strobe to {pwm_strobe} == {clock_cycles} clocks")
            await tqv.write_reg(2, pwm_strobe)
            assert await tqv.read_reg(2) == pwm_strobe 

            # wait for at least 2 full PWM cycles to ensure everything is ready
            await ClockCycles(dut.clk, 256)
            # do the test
            await test_pwm(dut, pwm_value, clock_cycles)

async def test_pwm(dut, pwm_value, pwm_strobe):
    
    dut._log.info(f"sync to PWM rising edge")
    # sync to pwm gen
    await pin_change(dut, dut.uo_out[0], 1)
    await pin_change(dut, dut.uo_out[0], 0)
    await pin_change(dut, dut.uo_out[0], 1)
    dut._log.info(f"assert {pwm_strobe * pwm_value} clocks of PWM high")
    # assert the PWM is on for the length of time
    for i in range(pwm_value):
        if ASSERT: assert dut.uo_out[0] == 1, f"failed on cycle {i}"
        if ASSERT: assert dut.uo_out[1] == 1, f"failed on cycle {i}"
        await ClockCycles(dut.clk, pwm_strobe)
    dut._log.info(f"assert {pwm_strobe * (255 - pwm_value)} clocks of PWM low")
    for i in range(255 - pwm_value):
        if ASSERT: assert dut.uo_out[0] == 0, f"failed on cycle {i}"
        if ASSERT: assert dut.uo_out[1] == 0, f"failed on cycle {i}"
        await ClockCycles(dut.clk, pwm_strobe)
