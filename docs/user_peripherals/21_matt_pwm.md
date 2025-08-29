<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# 8 bit PWM generator with adjustable frequency

Author: Matt Venn

Peripheral index: 21

## What it does

Dual channel 8 bit PWM generator with adjustable period.

* The PWM generator will advance by one count every PWM_MULT+1 clocks.
* The default PWM_MULT is 0.
* With PWM_MULT as 0, a PWM0 value of 10 will result in 10 clocks high out of 256 clocks.
* With PWM_MULT as 1, a PWM0 value of 10 will result in 20 clocks high out of 512 clocks.

## Register map

Document the registers that are used to interact with your peripheral

| Address | Name       | Access | Description                                                         |
|---------|------------|--------|---------------------------------------------------------------------|
| 0x00    | PWM0       | R/W    | PWM 0 value                                                         |
| 0x01    | PWM1       | R/W    | PWM 1 value                                                         |
| 0x02    | PWM_MULT   | R/W    | PWM period multiplier                                               |

## How to test

Set the PWM values as required and check the resulting waveforms on the output pins.

## External hardware

LED, scope, something to check the output waveforms.
