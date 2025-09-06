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

This is a replica of 8-bit classic **[AY-3-8913](https://en.wikipedia.org/wiki/General_Instrument_AY-3-8910)** 3-voice programmable sound generator (PSG) chip from General Instruments. The AY-3-8913 is a smaller variant of AY-3-8910 or its analog YM2149.


## Register map

The behavior of the AY-3-891x is defined by 14 registers. All registers are READ ONLY!


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

## How to test

TODO: Explain how to use your project

## External hardware

Tiny Tapeout Audio PMOD