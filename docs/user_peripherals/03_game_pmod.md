<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# Gamepad Pmod peripheral

Author: Mike Bell

Peripheral index: 3

## What it does

This peripheral provides access to the [Gamepad Pmod](https://store.tinytapeout.com/products/Gamepad-Pmod-board-p741891425).

## Register map

| Address | Name  | Access | Description                                                         |
|---------|-------|--------|---------------------------------------------------------------------|
| 0x00    | ENABLE | R/W   | Enable reading the gamepad.  If disabled, the stored inputs will not be updated.  |
| 0x02    | CTRL_1_PRESENT | R | Whether controller 1 is present. |
| 0x03    | CTRL_2_PRESENT | R | Whether controller 2 is present. |
| 0x04    | CTRL_1_STATE   | R | The state of controller 1 in bits 11-0, bit order from MSB to LSB: b, y, select, start, up, down, left, right, a, x, l, r. |
| 0x06    | CTRL_2_STATE   | R | The state of controller 2 in bits 11-0, bit order from MSB to LSB: b, y, select, start, up, down, left, right, a, x, l, r. |
| 0x20    | CTRL_1_R   | R | Whether controller 1 R is pressed. |
| 0x21    | CTRL_1_L   | R | Whether controller 1 L is pressed. |
| 0x22    | CTRL_1_X   | R | Whether controller 1 X is pressed. |
| 0x23    | CTRL_1_A   | R | Whether controller 1 A is pressed. |
| 0x24    | CTRL_1_RIGHT   | R | Whether controller 1 right is pressed. |
| 0x25    | CTRL_1_LEFT   | R | Whether controller 1 left is pressed. |
| 0x26    | CTRL_1_DOWN   | R | Whether controller 1 down is pressed. |
| 0x27    | CTRL_1_UP   | R | Whether controller 1 up is pressed. |
| 0x28    | CTRL_1_START   | R | Whether controller 1 start is pressed. |
| 0x29    | CTRL_1_SELECT   | R | Whether controller 1 select is pressed. |
| 0x2A    | CTRL_1_Y   | R | Whether controller 1 Y is pressed. |
| 0x2B    | CTRL_1_B   | R | Whether controller 1 B is pressed. |
| 0x2C    | CTRL_2_R   | R | Whether controller 2 R is pressed. |
| 0x2D    | CTRL_2_L   | R | Whether controller 2 L is pressed. |
| 0x2E    | CTRL_2_X   | R | Whether controller 2 X is pressed. |
| 0x2F    | CTRL_2_A   | R | Whether controller 2 A is pressed. |
| 0x30    | CTRL_2_RIGHT   | R | Whether controller 2 right is pressed. |
| 0x31    | CTRL_2_LEFT   | R | Whether controller 2 left is pressed. |
| 0x32    | CTRL_2_DOWN   | R | Whether controller 2 down is pressed. |
| 0x33    | CTRL_2_UP   | R | Whether controller 2 up is pressed. |
| 0x34    | CTRL_2_START   | R | Whether controller 2 start is pressed. |
| 0x35    | CTRL_2_SELECT   | R | Whether controller 2 select is pressed. |
| 0x36    | CTRL_2_Y   | R | Whether controller 2 Y is pressed. |
| 0x37    | CTRL_2_B   | R | Whether controller 2 B is pressed. |

Addresses 0 and 4 support word, halfword and byte reads.
Addresses 2 and 6 support halfword and byte reads.
Addresses 3 and 0x20-0x37 only support byte reads.

## How to test

Connect one or two SNES style controllers to the Pmod and check the registers read as expected.

## External hardware

One or two SNES style controllers and the Gamepad Pmod.
