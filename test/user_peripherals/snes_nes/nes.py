import random
import cocotb
from cocotb import logging
from cocotb.triggers import RisingEdge

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
