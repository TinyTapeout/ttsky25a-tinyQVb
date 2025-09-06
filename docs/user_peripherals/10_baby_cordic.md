<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# tinyqv-cordic: Fast Trigonometry for TinyQV

Author: Dylan Toussaint, Justin Fok

Peripheral index: nn

## What it does

This peripheral uses the CORDIC algorithm to implement hardware acceleration for trigonometric functions (cosine, sine). It accepts any 32-bit floating point number θ between -π/2 and π/2, and produces a 32-bit floating point result cos(θ) or sin(θ). The user interrupt will be triggered by an invalid floating point input, and is cleared by writing a 1 to the low bit of address 0x08.

## Register map

Document the registers that are used to interact with your peripheral

| Address | Name    | Access | Width   | Description                           |
|---------|---------|--------|---------|---------------------------------------|
| 0x00    | THETA   | R/W    | 32 bits | input data θ                          |
| 0x01    | CONTROL | R/W    | 2 bits  | bit 1: cos/sin toggle, bit 0: start   |
| 0x02    | RESULT  | R      | 32 bits | output result cos(θ) or sin(θ)        |
| 0x03    | STATUS  | R      | 1 bit   | bit 0: done                           |

* THETA[31:0]: receives input data
* CONTROL[1]: set high to output cos(θ) as result, sin(θ) otherwise
* CONTROL[0]: set high to start trigonometric calculation
* RESULT[31:0]: outputs calculated value
* STATUS: set high by peripheral when calculation is complete

## How to test

Test on valid input: first load the input angle θ into the THETA register. Next use the CONTROl register to choose whether to output cos(θ) or sin(θ), the start signal can be set high in the same clock cycle. Use the STATUS register to determine when the calculation is complete, the result can then be extracted from the RESULT register.

<img src="test_example.png" alt="calculation test" width="300"/>

Test on invalid input: load an invalid input angle θ into the THETA register, the following example shows value nan, other possibilities include inf. tqv.is_interrupt_asserted() is used to check that the interrupt is correctly triggered. To clear the interrupt the least significant bit of address 0x08 is set high.

<img src="test_interrupt.png" alt="interrupt test" width="300"/>

