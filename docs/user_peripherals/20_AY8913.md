<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# AY-3-819x

Author: ReJ aka Renaldas Zioma

Peripheral index: 20

## What it does

This is a replica of 8-bit classic **[AY-3-8910/AY-3-8912/AY-3-8913](https://en.wikipedia.org/wiki/General_Instrument_AY-3-8910)** 3-voice programmable sound generator (PSG) integrated into a modern RISC-V as a peripheral.

The AY-3-891x family of programmable sound generators was introduced by General Instrument in 1978. Variants of the AY-3-891x were broadly used in:

- home computers: Amstrad CPC, Atari ST, Oric-1, Sharp X1, MSX, ZX Spectrum 128/+2/+3
- game consoles: Intellivision, Vectrex
- and many arcade machines

### Technical capabilities

- **3 square wave** tone generators
- A single **white noise** generator
- A single **envelope** generator able to produce 10 different shapes
- Chip is capable to produce a range of waves from a **30 Hz** to **125 kHz**, defined by **12-bit** registers.
- **16** different volume levels on a logarithmic scale

## Register map

The behavior of the AY-3-891x is defined by 14 registers. The register map matches the original AY-3-891x and should be able to play the original tunes without modifications.

All registers are **read only** in this peripheral and start in **unknown** uninitialised state upon reset!

| Address | Access | Bits used      | Function         | Description            |
|---------|--------|----------------|------------------|------------------------|
| 0       | R      | ```xxxxxxxx``` | Channel A Tone   | 8-bit fine frequency   |
| 1       | R      | ```....xxxx``` | ---//---         | 4-bit coarse frequency |
| 2       | R      | ```xxxxxxxx``` | Channel B Tone   | 8-bit fine frequency   |
| 3       | R      | ```....xxxx``` | ---//---         | 4-bit coarse frequency |
| 4       | R      | ```xxxxxxxx``` | Channel C Tone   | 8-bit fine frequency   |
| 5       | R      | ```....xxxx``` | ---//---         | 4-bit coarse frequency |
| 6       | R      | ```...xxxxx``` | Noise            | 5-bit noise frequency  |
| 7       | R      | ```..CBACBA``` | Mixer            | Tone and/or Noise per channel |
| 8       | R      | ```...xxxxx``` | Channel A Volume | Envelope enable or 4-bit amplitude |
| 9       | R      | ```...xxxxx``` | Channel B Volume | Envelope enable or 4-bit amplitude |
| 10      | R      | ```...xxxxx``` | Channel C Volume | Envelope enable or 4-bit amplitude |
| 11      | R      | ```xxxxxxxx``` | Envelope         | 8-bit fine frequency |
| 12      | R      | ```xxxxxxxx``` | ---//---         | 8-bit coarse frequency |   
| 13      | R      | ```....xxxx``` | Envelope Shape   | 4-bit shape control |

### Square wave tone generators

Square waves are produced by counting down the 12-bit counters. Counter counts up from 0. Once the corresponsding register value is reached, counter is reset and
the output bit of the channel is flipped producing square waves.

### Noise generator

Noise is produced with 17-bit [Linear-feedback Shift Register (LFSR)](https://en.wikipedia.org/wiki/Linear-feedback_shift_register) that flips the output bit pseudo randomly.
The shift rate of the LFSR register is controller by the 5-bit counter.

### Envelope

The envelope shape is controlled with 4-bit register, but can take only 10 distinct patterns. The speed of the envelope is controlled with 16-bit counter. Only a single envelope is produced that can be shared by any combination of the channels.

### Volume
Each of the three AY-3-891x channels have dedicated DAC that converts 16 levels of volume to analog output. Volume levels are 3 dB apart in AY-3-891x.

## IO pins

There is a single PWM output signal that is connected to all the output pins uo_out[7:0].
The input pins are not used.

## How to test

All register state are in **unknown** uninitialised state upon reset. The very first thing you should do is to set them to zero!

In order to play a standard pitch A440 note you have to enable Channel A tone in the mixer:

	register[7] = 0b00_001_000

Set volume loud:

	register[8] = 0b0000_1111

Set A440 tone using the formulas:

	register[0] = (2_000_000 // (16 * 440)) & 0xFF
	register[1] = (2_000_000 // (16 * 440)) >> 8

## External hardware

(Tiny Tapeout Audio PMOD)[https://store.tinytapeout.com/products/Audio-Pmod-p716541601]
