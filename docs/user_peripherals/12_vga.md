<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# 4 color flexible resolution VGA adapter for TinyQV

Author: ReJ aka Renaldas Zioma

Peripheral index: 12

## What it does

Flexible VGA framebuffer that allows multiple resolutions, up to 4 colors per scanline, 64 unique colors per frame and provides 1024x768 60Hz video signal (64 MHz pixel clock) suitable for a [TinyVGA PMOD](https://github.com/mole99/tiny-vga).

By default it is configured to display **20 x 16 pixels** choosing colors from a 2 entrees palette. Each pixel is 1 bit where 0 selects background and 1 foreground color. In this configuration CPU is completely free to attend to other tasks.

### Racing the Beam

This peripheral is inspired by the 8-bit era designs when Video RAM (VRAM) was prohibitively expensive and there was not enough memory worth of the whole screen resolution - frankly the situation is similar with Tiny Tapeout and TinyQV peripherals where the amount of memory bits is very limited.

Instead of large framebuffers, **Racing the Beam** technique was utilised to synchronize CPU with video signal and allow CPU to modify pixels in VRAM immediately after they have been displayed, forming the image of high resolution line by line.

**Racing the Beam** means that CPU has to run in tandem with video signal:
- **interrupts** can be used for a coarse wait - for the start of the frame or scanline,
- **blocking reads** for precise syncronisation - for scanline or even in the middle of the scanline.

Racing the Beam requires high CPU utilisation to support high screen resolutions. In the case of game, CPU could be processing game-pad inputs and executing gameplay logic only during the vertical blanking. The vertical blanking happens between scanlines 768 and 804 - roughly just 5% of the whole frame.

Of course sacrifice up to 95% of CPU time is significant, but it might be worth for games or graphical demos. With this peripheral, it is up to you to decide!

### Technical capabilities

A very wide range of possible resolutions:
- from 16 x 10 4-color to 1024 x 768 2-color modes,
- vertical and horizontal counters define the size of the pixel,
- visible portion of the horizontal line can be set to 960 or 1024 clock cycles.

The resolution of the screen, as well as 2 or 4 color mode can be changed at any point of the frame providing extra flexibility.

Video RAM and color palette:
- **320 bit** of Video RAM worth of 320 or 160 pixels depending on the color mode,
- configurable stride in bits for each new row of visible pixels,
- up to 4 color palette, can be modified at any point of the frame.

**Coarse** and **precise** syncronisation primitives:
- interrupts,
- cycle accurate blocking of the CPU,
- register to read out the current scanline number of the video signal.

### Syncronisation primitives

Syncronisation between CPU and video signal can be used either to update 

User interrupts can be triggered by:
- end of the frame,
- end of the visible portion of the scanline,
- end of the row of pixels

CPU can be blocked with cycle level precision until:
- end of the visible portion of the scanline and start of the horizontal blanking is reached - `WAIT_HBLANK`
- the first pixel of the Video RAM was visualized and can be safely be modified by CPU again - `WAIT_PIXEL0`

Read-only register to access the current scanline number - `SCANLINE`.

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

### Default 20 x 16 pixels

By default VGA peripheral is configured to display screen resolution of 20 x 16 pixels.
Write to `PIXELS` register to change the pixels. Each pixel is 1 bit and CPU is free to attend to other tasks.

### 4-color 160 x 192

By default VGA peripheral will count 1024 cycles per visible line, however 1024 is not divisible by intended resolution of 160 pixels. You can shorten the screen width to 960 clocks instead since 960 are nicely divisible by 320. This is achieved by setting the **5th bit** of `MODE` register.

4 colors mode is enabled by setting the **6th bit** of `MODE` register.

The whole 160 pixel row nicely fits into the 320-bit VRAM and every new row of pixels will start from the very beginning of VRAM, therefore `VRAM_STRIDE` will be 0 (-1 will have the same effect reseting VRAM address to 0 at every row).

Finally, calculated pixel horizontal and vertical counters dividing 960x768 the visible VGA resolution by the inteded frame resolution 160x192 and subtract 1. Write counter values in `PIXEL_SIZE` register.

	register[MODE] = 0b0011_0000
	register[VRAM_STRIDE] = 0
	register[PIXEL_SIZE] = (960 // 320 - 1) | ((768 // 192 - 1) << 16)

To **Race the Beam** block CPU until the next horizontal blank reading from `WAIT_HBLANK` registe, then write into the `PIXELS` as fast you can!

	y = register[WAIT_HBLANK]
	register[PIXELS] = ...

## External hardware

[TinyVGA PMOD](https://github.com/mole99/tiny-vga)
