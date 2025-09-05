<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# 

Author: Gerardo Huerta

Peripheral index: 16

## What it does

This peripheral implements an 1 byte Gray coder/decoder. It encode/decode a byte per cycle clock. Gray code is a binary numeral system where two successive values differ in only one bit. Its primary use is in reducing errors and power consumption in digital systems. 

Important to notice:
Data Input:
data_in | from CPU

Data Output:
data_out | back to CPU
uo_out   | to pmod

Both outputs are connected.

## Register map

Document the registers that are used to interact with your peripheral

| Address | Name        | Access | Description                                                         |
|---------|-------------|--------|---------------------------------------------------------------------|
| 0x00    | clear_output|        | Clear any output                                                    |
| 0x01    | Bin_2_Gray  | R/W    | Convert from binary to Gray a byte                                  |
| 0x02    | Gray_2_Bin  | R/W    | Convert from Gray to binary a byte                                  |

## How to test

You can feed any binary number to the data_in input with the data_write set and adrress == "1". It will output Gray encoded binary to data_out and uo_out

For Gray decoder, You can feed any Gray number to the data_in input with the data_write set and adrress == "2". It will output Binary decoded to data_out and uo_out

Output is driven by 'data_write' and 'rst_n'. Each time you set 'data_write' means a new convertion and output, you can clear out by 'rst_n' or writing any data to 'clear_output' address.

## External hardware

You can connect output from this peripheral to any input wich can encod/decod gray or need any gray interface for communication.
