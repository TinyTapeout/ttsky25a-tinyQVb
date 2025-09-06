# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import random
from random import randint
import cocotb
from cocotb import logging
from cocotb.triggers import RisingEdge

from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, RisingEdge, FallingEdge
from tqv import TinyQV

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
            await RisingEdge(self.dut.nes_latch)
            self.latch()

    def latch(self):
        # Latch button states into shift register
        self.shift_register = [int(not self.button_states[btn]) for btn in self.BUTTONS]
        self.shift_index = 0
        data_val = self.shift_register[self.shift_index]
        self.log.info(f"latching nes latch: output: {data_val}")
        self.dut.nes_data.value = data_val

    # model the NES shift behavior
    @cocotb.coroutine
    async def nes_shift(self):
        while True:
            await RisingEdge(self.dut.nes_clk)
            data_val = self.shift()
            self.log.info(f"shifting nes clk: output: {data_val}")
            self.dut.nes_data.value = data_val

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

expected_buttons_pressed_list = []

async def nes_sequence(dut, nes, tqv, num_presses=10):

    buttons = ["A", "B", "Select", "Start", "Up", "Down", "Left", "Right"]

    print(f"pressing {num_presses} buttons..")
    
    # Hold for start time
    start_delay = randint(0,1)
    await Timer(start_delay, units="ns")

    pressed = set()
    pressed_buttons = []

    for _ in range(num_presses):
        
        # Choose 1 or 2 unique buttons to press
        num_buttons = randint(0, 2)
        
        if len(expected_buttons_pressed_list) < 2:
            # Add a one or two or zero buttons that are not already pressed
            if len(expected_buttons_pressed_list) < 1:
                for _ in range(num_buttons):
                    available_buttons = [b for b in buttons if b not in pressed]
                    if available_buttons:
                            pressed.add(buttons.index(available_buttons[randint(0, len(available_buttons)-1)]))
                    pressed_buttons = [buttons[i] for i in pressed]
            # Add a one or zero buttons that are not already pressed
            else:
                if randint(1,2) == 2:
                    available_buttons = [b for b in buttons if b not in pressed]
                    if available_buttons:
                        pressed.add(buttons.index(available_buttons[randint(0, len(available_buttons)-1)]))
                        pressed_buttons = [buttons[i] for i in pressed]
            
        for button in pressed_buttons:
            nes.press(button)

        await RisingEdge(dut.nes_latch)
        # print(f"adding button {pressed_buttons} to list.")
        
        for button in pressed_buttons:
            expected_buttons_pressed_list.append(button)

        # Hold for random time
        hold_time = randint(50, 500)
        await Timer(hold_time, units="us")

        # Randomly release 1 or both buttons
        num_release = randint(1, max(len(pressed_buttons),1))
        
        for button in pressed_buttons[:num_release]:
            nes.release(button)
            expected_buttons_pressed_list.remove(button)
        
async def check_data(dut, tqv):
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

    # Wait for the complete transmission cycle
    
    # If no button was queued, skip this cycle
    if len(expected_buttons_pressed_list) == 0:
        return

    expected_data_out = 0
    
    for b in expected_buttons_pressed_list:
        expected_data_out |= button_map[b]

    # Small random wait to simulate async timing
    await Timer(randint(10, 50), units="ns")

    val = await tqv.read_reg(0)
    dut._log.info(f"Async check: std_buttons={val:08b}, expected={expected_data_out:08b}")

    assert val == expected_data_out , f"Mismatch for {expected_buttons_pressed_list}"

@cocotb.test()
async def test_nes(dut):
    dut._log.info("Start")
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    nes = NES_Controller(dut)
    # Set the clock period to 16 ns (~64 MHz)
    clock = Clock(dut.clk, 16, units="ns")
    cocotb.start_soon(clock.start())

    dut._log.info("Test project behavior")
    cocotb.start_soon(nes.model_nes())
    await tqv.reset()
    
    await nes_sequence(dut, nes, tqv, num_presses=1)

    await ClockCycles(dut.clk, 10)

