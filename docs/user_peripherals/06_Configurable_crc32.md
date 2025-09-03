<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# CRC32 Peripheral

Author: Vicente Ramirez & Francisco Aguirre

Peripheral index: 06

## What it does

The peripheral is a configurable CRC engine designed to handle byte-oriented data streams. It receives incoming bytes, stores them in an internal FIFO buffer, and applies a Cyclic Redundancy Check (CRC) algorithm to the complete sequence.

The module supports configuration of the polynomial, reflection (RefIn/RefOut), and XOR output parameters, allowing compatibility with multiple CRC standards and paradigms. This flexibility makes it suitable for a wide range of protocols and validation schemes.

## Register map

Document the registers that are used to interact with your peripheral

| Address | Name             | Access | Description                                                         |
|---------|------------------|--------|---------------------------------------------------------------------|
| 0x00    | Enable register  | R/W    | When its value is 32'd1 it signals that following bytes written in the data\_in register should be taken in account for the current crc conversion, when it falls it signals the end of conversion and resets the internal crc value to 32'hFFFF_FFFF or 32´h0000_0000 depending on the configuration.
| 0x04    | Config register  | W    | If Config[0] is high Refin and RefOut are True, if its Low they are False. If Config[1] is high the resulting value of the CRC algorithm has an Xor operation with 32'hFFFF_FFFF, otherwise its made with 32'h0000_0000.If  Config[2] is high the Initial value of the CRC Register is set to  32'hFFFF_FFFF, else its 32'h0000_0000.|
| 0x0C   | Output_data  | R    | Output data register, it stores the current finished value of the CRC.|
| 0x10   | Poly  | R/W    | Generator polynomial, its default value is 32'h04C11DB7 (Asociated with ISO-HDLC)|


## How to test

The standard way to verify a CRC implementation is to use the reference input string "123456789". This sequence is widely adopted as the canonical test vector for CRC algorithms. Simply feed this string to your peripheral and compare the computed CRC value against the expected result (e.g., from a trusted CRC calculator or reference implementation).

It has been tested for the following protocols with the secuence "123456789" 

| CRC-32              | Result     | Poly       | Config[0] | Config[1] | Config[2] |
|---------------------|------------|------------|-----------|-----------|-----------|
| CRC-32/AIXM         | 0x3010BF7F | 0x814141AB |     0     |     0     |     0     |
| CRC-32/AUTOSAR      | 0x1697D06A | 0xF4ACFB13 |     1     |     1     |     1     |
| CRC-32/BASE91-D     | 0x87315576 | 0xA833982B |     1     |     1     |     1     |
| CRC-32/BZIP2        | 0xFC891918 | 0x04C11DB7 |     0     |     1     |     1     |
| CRC-32/CD-ROM-EDC   | 0x6EC2EDC4 | 0x8001801B |     1     |     0     |     0     |
| CRC-32/CKSUM        | 0x765E7680 | 0x04C11DB7 |     0     |     1     |     0     |
| CRC-32/ISCSI        | 0xE3069283 | 0x1EDC6F41 |     1     |     1     |     1     |
| CRC-32/ISO-HDLC     | 0xCBF43926 | 0x04C11DB7 |     1     |     1     |     1     |
| CRC-32/JAMCRC       | 0x340BC6D9 | 0x04C11DB7 |     1     |     0     |     1     |
| CRC-32/MEF          | 0xD2C22F51 | 0x741B8CD7 |     1     |     0     |     1     |	
| CRC-32/MPEG-2       | 0x0376E6E7 | 0x04C11DB7 |     0     |     0     |     1     |	
| CRC-32/XFER         | 0xBD0BE338 | 0x000000AF |     0     |     0     |     0     |	

## External hardware

There is no external Hardware necesary
