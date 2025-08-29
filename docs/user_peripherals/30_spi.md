<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# SPI controller

Author: Mike Bell

Peripheral index: 30

## What it does

This peripheral is a general SPI controller, with hardware support for a Data/Command line as needed by devices such as ST7789 LCD displays.

The controller can automatically control CS, setting it low when a byte is about to be transferred.  CS is set high after the byte is transferred if END_TXN is set.  This allows multi-byte transactions to be handled easily.

One byte of data to transmit is buffered to improve throughput when transmitting data.  Received data is not buffered.

### Pinout

The IOs used match the top row of the "SPI CTRL" PMOD on the demo board:

    MISO: in2
    MOSI: out3
    CLK : out5
    CSn : out4

D/C is on out2.

CSn is also connected to outputs 0, 1, 6 and 7.  This allows the SPI bus to be shared by multiple devices, by switching the desired CS to be controlled by the SPI controller, and all others to be set high by GPIO.

## Register map

| Address | Name  | Access | Description                                                         |
|---------|-------|--------|---------------------------------------------------------------------|
| 0x00    | CTRL  | R/W    | Control / status register.  Individual bits documented below.  |
| 0x01    | TX_DATA | R/W | Data to transmit, transmission starts on write.  Write only when TX pending is low. |
| 0x02    | RX_DATA | R/W | Data received, valid when SPI busy is low. |
| 0x04    | DIVIDER   | W | The low 7 bits set the clock divider, the SPI clock is the system clock divided by 2 * (value + 1).  The top bit controls RX sampling latency, if it is set incoming data is sampled half an SPI clock cycle later - this may be required for high frequencies to work reliably. |

### Control / status register

| Bit | Name  | Access | Description                                                         |
|-----|-------|--------|---------------------------------------------------------------------|
| 0   | SPI_BUSY  | R  | High when an SPI transaction is in progress.  |
| 1   | TX_PENDING  | R  | High when TX data is buffered, waiting to be sent to the SPI controller. |
| 2   | END_TXN  | R/W | Whether to raise CS after the next byte of data is transmitted. |
| 3   | DC_CTRL  | R/W | Value to set DC to before the next byte of data is transmitted. |

## How to test

Use an ST7789 LCD, SD card, or any other SPI device.

## External hardware

An SPI device.
