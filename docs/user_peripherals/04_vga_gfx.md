<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# VGA Graphics

Author: Mike Bell

Peripheral index: 04

## What it does

This peripheral is designed to allow a 4 colour (3 plus black) VGA display at 256x192 resolution, although vertical resolutions of 768, 384, 96 and 48 are also supported.

The peripheral stores one line of colour data (256 x 2 bits), and interrupts at the end of a configurable number of lines so the CPU can update the data with the next line.

## Register map

Note that registers are in an undefined state after reset so should all be configured before use.

| Address | Name  | Access | Description                                                         |
|---------|-------|--------|---------------------------------------------------------------------|
| 0x00-0x3c | PIXEL_DATA  | R/W    | Pixel data, can only be accessed at word aligned addresses. |
| 0x1 | INTERRUPT_CFG  | R/W    | Interrupt configuration - see below. |
| 0x2 | Y_LOW  | R    | The row mod 48.  Halfword access to Y_LOW and Y_HIGH together is supported. |
| 0x3 | Y_HIGH  | R    | The row divided by 48. |
| 0x5 | COLOUR1  | R/W  | Colour 1 in RRGGBB. |
| 0x6 | COLOUR2  | R/W  | Colour 2 in RRGGBB. |
| 0x7 | COLOUR3  | R/W  | Colour 3 in RRGGBB. |

### Interrupt configuration

| Bits | Name | Description |
| ---- | ---- | ------- |
| 3-0  | Y_MASK | Interrupt is generated when (row | Y_MASK) == 0xf.  Set to 0xf to interrupt every line, set to 0xc to interrupt every 4th line. |
| 5-4  | X_OFFSET | The position in the line to generate the interrupt, see below. |

| X_OFFSET | Meaning |
| -------- | ------- |
| 0        | Interrupt at x == 1024 (end of line). |
| 1        | Interrupt at x == 256. |
| 2        | Interrupt at x == 512. |
| 3        | Interrupt at x == 768. |

A read from the INTERRUPT_CFG register clears the interrupt.

## How to test

Connect the TinyVGA Pmod and use the firmware library that hopefully I will have written!

## External hardware

TinyVGA Pmod.
