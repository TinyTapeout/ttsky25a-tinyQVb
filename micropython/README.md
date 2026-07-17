# Micropython testing on TinyQV

Connect the QSPI Pmod to the BIDIR socket on the TinyTapeout demo board, and load the Micropython binary with [the programmer](https://program.tinyqv.com).  The design number defaults to the right value for "Asteroids", so change it to 687 to run the "Berzerk" version of TinyQV.  Then select Micropython and click FLASH AND RUN.

A Micropython REPL should appear in a text box at the top of the page.

## First steps - GPIO

Try flashing the bottom segment on the seven segment display, by typing or copy-pasting the following:

    from machine import Pin

    out3 = Pin(3)
    out3.on()
    out3.off()

`Pin(n)` with no extra arguments and n from 0-7 will initialize the output pin for general purpose IO use, meaning you can set it high or low using `on()` and `off()`, or equivalently `value(0)` and `value(1)` methods.

Don't use `Pin(0)` as that is used by the UART to send data to the Micropython REPL.

## Assigning output pins to peripherals

This is the [list of peripherals](../docs/info.md#contributed-peripherals) on TinyQV "Asteroids".  Many of them are able to transmit data on the output pins.  Only one peripheral can be in control of an output pin at any one time.  To select which, use e.g.:

    Pin(2, func_sel=21)

to set out2 to be controlled by Matt's PWM peripheral.

## Reading and writing peripheral registers

The tinyqv module provides access functions for the peripheral registers.  For example, to set register at address 1 on the PWM peripheral to 100:

    import tinyqv
    tinyqv.write_byte_reg(21, 1, 100)

The functions are named:

- `read_byte_reg(peripheral_num, address)` read a byte register
- `write_byte_reg(peripheral_num, address, value)` write `value` to a byte register
- `read_hword_reg(peripheral_num, address)` read a half-word (16 bit) register
- `write_hword_reg(peripheral_num, address, value)` write `value` to a half-word (16 bit) register
- `read_word_reg(peripheral_num, address)` read a word (32 bit) register
- `write_word_reg(peripheral_num, address, value)` write `value` to a word (32 bit) register

See the [tinyqv module source](https://github.com/MichaelBell/micropython/blob/tinyqv-sky25a/ports/tinyQV/modules/tinyqv.py) for full details.

## Reading input pins

The input pins in0-in7 have pin numbers 8-15 in Micropython.  So for example:

    from machine import Pin

    print(Pin(9).value())

Will print 0 or 1 depending on whether in1 reads low or high.

## Pasting larger amounts of code

You can go into "paste mode" at the Micropython into the REPL by pressing Ctrl-E.  This ensures formatting is preserved during the paste.  Press Ctrl-D to exit paste mode, the pasted code will be interpreted when you press Ctrl-D.

## Tests

See the python tests in this directory for tests of some peripherals.  Note that some of this code has not yet been tested - let us know in the Discord when you get peripherals working, and please make PRs to contribute more tests!

## Using mpremote with TinyQV

If you want to go beyond what can easily be done through the web interface, you can setup the TinyTapeout demo board to act as a USB bridge to allow mpremote to control Micropython on TinyQV.

First you need to do this one time setup - with your demoboard connected run 

    mpremote mip install usb-device
    mpremote mip install usb-device-cdc 
    
this installs the micropython-lib USB drivers to the demoboard

Use the [USB bridge script](tqv_usb_bridge.py) and run it with mpremote: 

    mpremote run tqv_usb_bridge.py

mpremote will give an error because the existing USB port disconnected, but the script should run OK.

You should now see two new ttys, one is the demoboard and the other is TinyQV micropython.  TinyQV should be on the higher numbered one and mpremote should work against it as normal.

As you now have two ttys you'll need to specify which tty mpremote should use, e.g. `mpremote a2 repl` if TinyQV ends up on ttyACM2.  If you get the demoboard then nothing will happen when you press Enter or Ctrl-D, if you're connected to TinyQV you should get the Micropython prompt.

Try running the scripts from this directory with e.g. `mpremote a2 run 13_vga_console.py` (adjusting the tty accordingly).

Be aware that TinyQV doesn't have a persistent Micropython filesystem.  Files are stored in PSRAM so will be lost when you power off the demoboard.
