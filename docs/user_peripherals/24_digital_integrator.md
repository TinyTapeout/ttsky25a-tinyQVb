<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->


# Digital Integrator Peripheral

Author: Kushal

Peripheral index: 24

## What it does

This project implements a digital integrator peripheral for TinyQV.  
It accumulates signed 8-bit input samples, supports leaky integration, saturation, and threshold detection.  
The accumulator is 16 bits wide, and the peripheral exposes control, status, and configuration registers for flexible operation.

## Register map

| Address | Name        | Access | Description                                                      |
|---------|-------------|--------|------------------------------------------------------------------|
| 0x00    | CTRL        | R/W    | Control: bit0=enable, bit1=sample strobe, bit3=saturation enable |
| 0x01    | STATUS      | R      | Status: bit0=overflow, bit1=threshold                            |
| 0x02    | INPUT       | W      | Input sample (signed 8-bit)                                      |
| 0x03    | ACC_LOW     | R      | Accumulator low byte                                             |
| 0x04    | ACC_HIGH    | R      | Accumulator high byte                                            |
| 0x05    | THRESH      | R/W    | Threshold value for status flag                                  |
| 0x06    | DECAY_SHIFT | R/W    | Leaky integrator decay shift (0=pure, k>0=leaky)                 |

## How to test

1. Run the cocotb testbench in `test/test.py`:
		
		```sh
		cd test 
		make -B
		```
2. The testbench will:
		- Reset the peripheral
		- Enable integration and add samples
		- Check accumulator and status flags
		- Test threshold and overflow behavior

See `test/test.py` for detailed test scenarios.

### How to use this peripheral

- **Enable the integrator:**  
	Write `0x1` to the `CTRL` register (address `0x00`) to enable the integrator.

- **Provide an input sample:**  
	Write your signed 8-bit sample to the `INPUT` register (address `0x02`).

- **Trigger a sample:**  
	Set both enable and strobe bits in `CTRL` (`0x3`) to accept the input sample.

- **Read the accumulator:**  
	Read `ACC_LOW` (`0x03`) and `ACC_HIGH` (`0x04`) to get the 16-bit accumulator value.

- **Set threshold:**  
	Write your desired threshold value to the `THRESH` register (`0x05`).  
	The status register (`0x01`) bit1 will be set when the accumulator exceeds this threshold.

- **Enable leaky integration:**  
	Write a nonzero value to `DECAY_SHIFT` (`0x06`).  
	The accumulator will decay by `1/2^k` each sample.

- **Enable saturation:**  
	Set bit3 in `CTRL` (`0x08`) to enable saturation.  
	The status register bit0 will be set if overflow occurs.

- **Input/output via IOs:**  
	You can also provide input samples through the `ui_in` port (dedicated input PMOD pins), and read the accumulator output from the `uo_out` port (dedicated output PMOD pins).  
	

See `test/test.py` for example usage and more details.

## External hardware

No external hardware required.  
Inputs/outputs are mapped to PMOD pins for integration and demonstration.
