# SPDX-FileCopyrightText: © 2024 Michael Bell
# SPDX-License-Identifier: MIT

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, Edge
import cocotb.utils

from test_util import reset

from user_peripherals.ledstrip.test import get_GRB

async def receive_string(dut, str):
    for char in str:
        dut._log.debug(f"Wait for: {char}")

        for _ in range(5000):
            await ClockCycles(dut.clk, 8)
            if dut.uart_tx.value == 0:
                break
        else:
            # Should have started by now
            assert dut.uart_tx.value == 0
        
        uart_byte = ord(char)
        bit_time = 8680
        await Timer(bit_time / 2, "ns")
        assert dut.uart_tx.value == 0
        for i in range(8):
            await Timer(bit_time, "ns")
            assert dut.uart_tx.value == (uart_byte & 1)
            uart_byte >>= 1
        await Timer(bit_time, "ns")
        assert dut.uart_tx.value == 1

async def read_string(dut):
    str = ""
    while not str.endswith('\r'):
        for _ in range(25000):
            await ClockCycles(dut.clk, 8)
            if dut.uart_tx.value == 0:
                break
        else:
            # Should have started by now
            dut._log.info(f"Received before fail: {str}")
            assert dut.uart_tx.value == 0
        
        uart_byte = 0
        bit_time = 8680
        await Timer(bit_time / 2, "ns")
        assert dut.uart_tx.value == 0
        for i in range(8):
            await Timer(bit_time, "ns")
            uart_byte |= dut.uart_tx.value << i
        await Timer(bit_time, "ns")
        assert dut.uart_tx.value == 1
        str += chr(uart_byte)
        dut._log.debug(f"Recvd: {chr(uart_byte)}")
    return str

@cocotb.test()
async def test_ledstrip(dut):
    dut._log.debug("Start")
  
    # Our example module doesn't use clock and reset, but we show how to use them here anyway.
    clock = Clock(dut.clk, 15.624, units="ns")
    cocotb.start_soon(clock.start())

    await reset(dut, 2)

    hello = cocotb.start_soon(receive_string(dut, "Hello, world!\r\n"))

    while dut.uo_out[1].value == 1:
        await Edge(dut.uo_out)

    for i in range(1, 6):
        bitseq = await get_GRB(dut, dut.uo_out[1])
        assert bitseq[:8] == [  0, 0, 0, 0, 0, 0, 0, 0 ]   # G: 0
        for j in range(8):
            assert bitseq[8+j] == (1 if (i & (1 << (7 - j))) else 0)
            assert bitseq[16+j] == (1 if (i & (1 << (7 - j))) else 0)
        dut._log.info(f"Purple LED {i} ok")

        bitseq = await get_GRB(dut, dut.uo_out[1])
        assert bitseq[8:16] == [  0, 0, 0, 0, 0, 0, 0, 0 ]   # R: 0
        assert bitseq[16:24] == [  0, 0, 0, 0, 0, 0, 0, 0 ]   # B: 0
        for j in range(8):
            assert bitseq[j] == (1 if (i & (1 << (7 - j))) else 0)
        dut._log.info(f"Green LED {i} ok")

    await hello

