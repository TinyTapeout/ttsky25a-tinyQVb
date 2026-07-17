from machine import Pin
from tinyqv import read_byte_reg, write_byte_reg

PERIPHERAL_NUM = 18

# Select the PWM peripheral on out2
Pin(2, Pin.OUT, func_sel=PERIPHERAL_NUM)

# Write a non-zero duty cycle to PWM1, which is connected to out2
# you should see a square wave on out2
write_byte_reg(PERIPHERAL_NUM, 1, 100)

# Check the value can be read back
duty_cycle = read_byte_reg(PERIPHERAL_NUM, 1)
print(f"Read {duty_cycle} back from PWM peripheral")
