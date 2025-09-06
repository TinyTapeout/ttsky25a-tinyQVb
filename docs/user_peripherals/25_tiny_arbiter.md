<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.
You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# Tiny Arbiter
Author: Aakarshitha Suresh

Peripheral index: nn

## What it does

Tiny Arbiter is a weighted round-robin arbiter with configurable per-master weights, ready/valid handshaking, and register-mapped control for fair and programmable request scheduling for the Tiny Tapeout Risc-V challenge.

## Register map

Document the registers that are used to interact with your peripheral

| Address | Name     |  Access | Description                                                      |

| ------- | -------- | ------- |------------------------------------------------------------------|

| 0x0     | N/A      | —       | Unused (reads 0).                                                |

| 0x1     | N/A      | —       | Unused (reads 0).                                                |

| 0x2     | WEIGHT0  | R/W     | Requester 0 weight (1..7 recommended; 0 allowed = “off/lowest”). |

| 0x3     | WEIGHT1  | R/W     | Requester 1 weight.                                              |

| 0x4     | WEIGHT2  | R/W     | Requester 2 weight.                                              |

| 0x5     | WEIGHT3  | R/W     | Requester 3 weight.                                              |

| 0x6–0xD | N/A      | —       | Unused (reads 0).                                                |

| 0xE     | STATUS0  | R       | Snapshot of internal state. `busy=1` when arbiter not in IDLE.   |

| 0xF     | STATUS1  | R       | One-hot grant vector of current winner (or 0 if none).           |

                                                    

## How to test
Use the test.py to run it and see the output on the waveform using gtkwave. Observe data_out when addres is 0xE and 0xF when it shows the busy and grant.

## External hardware
NA

