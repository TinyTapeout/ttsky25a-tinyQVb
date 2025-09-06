# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import random
from random import randint
import cocotb
from cocotb import logging
from cocotb.triggers import RisingEdge, Edge

from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, RisingEdge, FallingEdge
from tqv import TinyQV

async def posedge(vector, bit):
    prev = (int(vector) >> bit) & 1
    while True:
        await Edge(vector)            # wake on any change to the bus
        cur = (int(vector) >> bit) & 1
        if prev == 0 and cur == 1:
            return                    # rising edge detected
        prev = cur 

class NES_Controller:
    

    # NES controller button order: A, B, Select, Start, Up, Down, Left, Right
    BUTTONS = ["A", "B", "Select", "Start", "Up", "Down", "Left", "Right"]

    def __init__(self, dut):
        self.dut = dut
        global_nes_controller_id = getattr(NES_Controller, "global_id", 0)
        self.id = global_nes_controller_id
        NES_Controller.global_id = global_nes_controller_id + 1
        self.log = logging.getLogger(f"cocotb.tb.nes_controller_{self.id}")
        self.log.setLevel("INFO")  # Optional: set log level per class
        self.button_states = {btn: False for btn in self.BUTTONS}
        self.shift_register = [0] * 8
        self.shift_index = 0

    def reset(self):
        self.button_states = {btn: False for btn in self.BUTTONS}
        self.shift_register = [0] * 8
        self.shift_index = 0

    def press(self, button=None):
        if button is None:
            button = random.choice(self.BUTTONS)
            self.log.info(f"pressing random button: {button}")
            self.button_states[button] = True
        elif button in self.BUTTONS:
            self.log.info(f"pressing button: {button}")
            self.button_states[button] = True
       
        return button

    def release(self, button):
        if button in self.BUTTONS:
            self.log.info(f"releasing button: {button}")
            self.button_states[button] = False

    # modelling methods
    @cocotb.coroutine
    async def model_nes(self):
        cocotb.start_soon(self.nes_latch())
        cocotb.start_soon(self.nes_shift())

    # model the NES latch behavior
    @cocotb.coroutine
    async def nes_latch(self):
        while True:
            await posedge(self.dut.uo_out, 6)
            self.latch()

    def latch(self):
        # Latch button states into shift register
        self.shift_register = [int(not self.button_states[btn]) for btn in self.BUTTONS]
        self.shift_index = 0
        data_val = self.shift_register[self.shift_index]
        self.log.info(f"latching nes latch: output: {data_val}")
        self.dut.ui_un[1].value = data_val

    # model the NES shift behavior
    @cocotb.coroutine
    async def nes_shift(self):
        while True:
            await posedge(self.dut.uo_out, 7)
            data_val = self.shift()
            self.log.info(f"shifting nes clk: output: {data_val}")
            self.dut.ui_un[1].value = data_val

    def shift(self):
        # Return current bit and advance shift register
        if self.shift_index < 8:
            self.shift_index += 1
            value = self.shift_register[self.shift_index]
            return value
        else:
            # After 8 reads, NES controllers return 1 (open bus)
            return 1

# When submitting your design, change this to 16 + the peripheral number
PERIPHERAL_NUM = 41


@cocotb.test()
async def test_nes(dut):
    dut._log.info("Start")
    nes = NES_Controller(dut)
    # Set the clock period to 16 ns (~64 MHz)
    clock = Clock(dut.clk, 16, units="ns")
    cocotb.start_soon(clock.start())

    dut._log.info("Test project behavior")
    cocotb.start_soon(nes.model_nes())

    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()

    pressed_button = nes.press()

    await ClockCycles(dut.clk, 10)

    # wait for a full timer cycle for the input to be registerd
    await Timer(randint(400, 800), units="us")

    # The following assertion is just an example of how to check the output values.
    # Map pressed_button to a binary value in descending powers of 2 from 128

    # Active high output
    button_map = {
        "A":     0b10000000,
        "B":     0b01000000,
        "Select":0b00100000,
        "Start": 0b00010000,
        "Up":    0b00001000,
        "Down":  0b00000100,
        "Left":  0b00000010,
        "Right": 0b00000001
    }

    dut._log.info(f"Read value from std_buttons: {button_map[pressed_button]:08b}")
    assert await tqv.read_reg(0) == button_map[pressed_button]
