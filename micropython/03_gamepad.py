import time
from machine import Pin
from tinyqv import read_byte_reg, write_byte_reg

PERIPHERAL_NUM = 3

def read_reg(addr):
    return read_byte_reg(PERIPHERAL_NUM, addr)

def write_reg(addr, value):
    write_byte_reg(PERIPHERAL_NUM, addr, value)

# Enable the gamepad
write_reg(0, 1)

# Pad 1 button registers
UP=0x27
DOWN=0x26
LEFT=0x25
RIGHT=0x24

while True:
    if read_reg(UP):
        Pin(6).on()
    else:
        Pin(6).off()

    if read_reg(DOWN):
        Pin(3).on()
    else:
        Pin(3).off()

    if read_reg(LEFT):
        Pin(4).on()
    else:
        Pin(4).off()

    if read_reg(RIGHT):
        Pin(2).on()
    else:
        Pin(2).off()

    time.sleep(0.05)
