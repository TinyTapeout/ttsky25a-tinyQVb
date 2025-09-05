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

| Address | Name    | Access | Description                                                      |
|---------|---------|--------|------------------------------------------------------------------|
| 0x00    | PIXDAT0 | W      | Pixel data (1-bit per pixel)   0..31                             |
| 0x04    | PIXDAT1 | W      | Pixel data (1-bit per pixel)  32..63                             |
| 0x08    | PIXDAT2 | W      | Pixel data (1-bit per pixel)  64..xx                             |
| 0x0C    | PIXDAT3 | W      | Pixel data (1-bit per pixel)  xx..xx                             |
| 0x10    | PIXDAT4 | W      | Pixel data (1-bit per pixel)  xx..xx                             |
| 0x14    | PIXDAT5 | W      | Pixel data (1-bit per pixel)  xx..xx                             |
| 0x18    | PIXDAT6 | W      | Pixel data (1-bit per pixel)  xx..xx                       		|
| 0x1C    | PIXDAT7 | W      | Pixel data (1-bit per pixel) 224..255                            |
| 0x20    | PIXDAT8 | W      | Pixel data (1-bit per pixel)  xx..xx                             |
| 0x24    | PIXDAT9 | W      | Pixel data (1-bit per pixel) 288..x319                           |
| 0x30	  | BGCOLOR | W	     | Background color: xxBBGGRR, default 010000 = dark blue			|
| 0x31	  | FGCOLOR	| W		 | Foreground color: xxBBGGRR, default 001011 = golden yellow		|
| 0x32	  | P2COLOR	| W		 | 3rd color, if 4 color palette enabled: xxBBGGRR |
| 0x33	  | P3COLOR	| W		 | 3th color, if 4 color palette enabled: xxBBGGRR |
| 0x34	  | STRIDE	| W		 | VRAM bit stride per pixel row (bits 8..0), default 20. Setting -1 will reset VRAM index to 0 on the next pixel row |
| 0x38	  | PIXSIZE	| W		 | Pixel size: width in clocks (bits 6..0), height in scanlines (bits 22..16) |
| 0x3C	  | MODE	| W		 | Interrupt: 0=frame, 1=scanline, 2=pixel row, 3=disabled (bits 1..0) |
|    	  |     	|  		 | Screen width: 0=1024, 1=960 clocks (bit 2) |
|		  |         |        | Color mode: 0=2 colors, 1=4 color palette |

| Address | Name        | Access | Description                                                  |
|---------|-------------|--------|--------------------------------------------------------------|
| 0x00    | WAIT_HBLANK | R      | Block CPU waiting for Horizontal BLANK                       |
| 0x04    | WAIT_PIXEL0 | R      | Block CPU waiting for display to reach the 1st pixel of the buffer |
| 0x08    | SCANLINE    | R      | Returns current scanlineL: 0..767 visible portion of the screen, >=768 offscreen |

## How to test

TODO: Explain how to use your project

## External hardware

Tiny VGA Pmod
