<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# Three Band Digital Equalizer with Biquad IIR Filter

Author: Tasmin Khan

Peripheral index: 10

## What it does

The peripheral is designed to be equivalent to hardware audio equalizer for digital audio signals of 16 bits. It utilizes three biquad IIR filters to boost or supress bass, mid or treble. It can be used with a DMA controller. The peripheral accepts input and generates output at every posedge of clock. It takes one cycle for the output to process and so output can be read from the output register at the next edge. 

There are three bands here with Lower cutoff at 300Hz adng higher cut off at 10kHz. The coefficients are dervied assuming a sampling frequency of 44Khz which is the standard for audio. The coeffcients are not writable but the gain values are writable in a range of 0-255. Gain value parameters can be described as follows 
Gain = 255: Unity gain (1.0×)  
Gain = 128: 0.5× (-6dB cut)
Gain = 64:  0.25× (-12dB cut)
Gain = 0:   Mute

The output is passed through each filter individually and then multiplied with gain before being summed.

## Register map

Document the registers that are used to interact with your peripheral

| Address | Name  | Access | Description                                                         |
|---------|-------|--------|---------------------------------------------------------------------|
| 0x00    | EQ OUTPUT | R  | Combined output from all three bands   |
| 0x04    | GAIN/CONTROL  |  R/W   |      Gain values as customized/ default and filter reset control |
| 0x08    | INPUT SAMPLE  |  R/W   |  Current active input    |
| 0x0C    | LFP OUTPUT |  W   | Output from the bass control filter  |
| 0x10    | BPF OUTPUT |  W  |  Output from the mid control filter |
| 0x14    | HPF OUTPUT |  W  |  Output from the treble control filter    |


## How to test

After resetting the peripheral, inputs can be given at any positive edge of the clock and output will be read at the next positive edge of the clock. Output can be read at any time from the eddge it is ready and onwards. Both the input and output hold their values unless new values come in or there is a filter or system reset. In the case of filter reset only delay registes will be cleared and in the case of system gain values will go back to default as well.

The input and output values are designed for be 16bits. So the audio signal needs to be quantized with 16 bits for the processing. Quantizing with smaller bitcount is okay but that may result in the signal being negligibly small to process.

Writing to gain registers for Lowpas, Bandpassa and Highpass filter can be done individually or as a group of two or three by controlling the data_in bit [26:24]. Additionally the filter delay registers can be reset without resetting the gain values by controlling the data_in bit [28] at the same address as gain registers.

## External hardware

No external hardware is needed. Input is assumed to be digital audio after being generated or being passed through an ADC.
