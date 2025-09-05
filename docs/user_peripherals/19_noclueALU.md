<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# A teeny tiny ALU that can ADD, SUB, AND and OR two 8 bit numbers
"Why?" You might ask. "Why not", I would say:)
(Even though I am aware that there is a better ALU already inside TinyQV like all other CPUs, I wanted to have my design
tapped out for the first ever time, and given my time (and probably skills) I chose the simplest design I could make in 2 days-and thats why.)

Author: Aditya Vikram Singh

Peripheral index: 19

## What it does

A simple ALU designed to be able to do the following operations:
* ADD - Numeric addition (opcode:0)
* SUB - Numeric substraction (opcode:1)
* AND - Bitwise and operation (opcode:2)
* OR  - Bitwise or operation (opcode:3)

## Register map

Total four registers are used to store the two operands, the opcode and the result of operation

| Address | Name       | Access | Description                                                         |
|---------|------------|--------|---------------------------------------------------------------------|
| 0x00    | A          | R/W    | Operand A                                                           |
| 0x01    | B          | R/W    | Operand B                                                           |
| 0x02    | OPC        | R/W    | The opcode (from 0 to 3)                                            |
| 0x03    | RESULT     | R      | The result of operation is stored here (read only).

## How to test

Set the address to 00 and data_in to provide 1st operand. Similarly put 2nd operator and opcode into the registers.
The resultant value can then be obtained by putting the address as 03 and reading the data_out.
Remember to assert data_write while writing A,B and OPC registers.

## External hardware
The noclueALU has no clue about how to interact with external hardware xd.
