<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# VGA adapter for TinyQV

Author: ReJ aka Renaldas Zioma

Peripheral index: 12

## What it does

TODO: Explain what your peripheral does and how it works

## Register map

| Address    | Name       | Access      | Description                                                      |
|------------|------------|-------------|------------------------------------------------------------------|
| 0x00..0x27 | PIXELS     | W 32bit     | Pixel data VRAM contains either 320 1-bit or 160 2-bit pixels    |
| 0x30       | COLOR_0    | W 32/16/8bit| Background color: xxBBGGRR, default 010000 = dark blue           |
| 0x31       | COLOR_1    | W 8bit      | Foreground color: xxBBGGRR, default 001011 = golden yellow       |
| 0x32       | COLOR_2    | W 16/8bit   | 3rd color, when 4 color mode is enabled: xxBBGGRR                |
| 0x33       | COLOR_3    | W 8bit      | 4th color, when 4 color mode is enabled: xxBBGGRR                |
| 0x34       | PIXEL_SIZE | W 8bit      | Pixel size: width in clocks (bits 6..0), height in scanlines (bits 22..16) |
| 0x38       | VRAM_STRIDE| W 32/16bit	| VRAM bit stride per pixel row (bits 8..0), default 20. Setting -1 will reset VRAM index to 0 on the next pixel row |
| 0x3C	     | MODE	      | W	32/16/8bit| Interrupt: 0=frame, 1=scanline, 2=pixel row, 3=disabled (bits 1..0) |
|            |            |          | Pixel clock: 0=64 MHz 804 scanlines, 1=63.5 MHz 798 scanlines (bit 4) |
|            |            |          | Screen width: 0=1024, 1=960 clocks (bit 5) |
|            |            |          | Color mode: 0=2 colors, 1=4 color palette (bit 6) |

| Address | Name        | Access | Description                                                  |
|---------|-------------|--------|--------------------------------------------------------------|
| 0x00    | WAIT_HBLANK | R      | Block CPU waiting for Horizontal BLANK                       |
| 0x04    | WAIT_PIXEL0 | R      | Block CPU waiting for display to reach the 1st pixel of the buffer |
| 0x08    | SCANLINE    | R      | Returns current scanline: 0..767 visible portion of the screen, >=768 offscreen |

## How to test

TODO: Explain how to use your project

## External hardware

Tiny VGA Pmod
