<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# NES/SNES Receiver

Author: Kwashie Andoh, James Ashie Kotey

Peripheral index: nn

## What it does

This module is an interface for the NES and SNES controllers that constantly reads the button state and exposes the relevant regs trhough three registers:


## Register map

Document the registers that are used to interact with your peripheral

| Address | Name        | Access | Description                                                         |
|---------|-------------|--------|---------------------------------------------------------------------|
| 0x00    | STD_BTNS    | R      | NES buttons (UP,DOWN,LEFT,RIGHT,B,A, START,SELECT)                  |
| 0x01    | EXT_BTNS    | R      | Additional SNES buttons (X,Y,L,R)                                   |
| 0x02    | STATUS      | R      | A single bit showing whether a snes controller has been connected   |

## How to test

Plug in a SNES or nes controller and read the associated data address to find out which buttons have been pressed.

## External hardware

SNES PMOD
SNES CONTROLLER
NES CONTROLLER
NES CONTROLLER ADAPTER
