<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# NES/SNES Receiver

Authors: [Kwashie Andoh](https://github.com/Kwash67), [James Ashie Kotey](https://github.com/Enjimneering)

Peripheral index: 15

## What it does

This peripheral provides an interface for reading NES and SNES gamepad controller states. It automatically detects which controller type is connected and exposes debounced button states through memory-mapped registers.

> For complete technical specification, see the [full documentation](https://docs.google.com/document/d/1l_B4vgzqy5NGJJAfXMa3Ju-xB-0VwFmkBfVjibhVOlY/edit?usp=sharing).

**Key Features**
- Supports both NES (8 buttons) and SNES (12 buttons) controllers
- Auto-detection between controller types (falls back to NES if SNES not present)
- Single controller support (either 1 NES or 1 SNES at a time)
- The SNES interface uses [CH32V003-based SNES-compatible controller interface PMOD](https://store.tinytapeout.com/products/Gamepad-Pmod-board-p741891425)
- Clean memory-mapped interface with status and button registers
- Compatible with TinyQV demoboard I/O constraints (3.3V, inputs not 5V tolerant)

## Register map

| Address | Name              | Access | Description                                           |
|---------|-------------------|--------|-------------------------------------------------------|
| 0x00    | Controller Status | R      | Bit 0: controller type (1=SNES active, 0=NES active) |
| 0x01    | Standard Buttons  | R      | Standard 8-button state (available on both NES/SNES) |
| 0x02    | SNES Extended     | R      | SNES-only buttons (reads 0 when NES active)          |

### Controller Status Register (0x00)
| Bit | Field | Description |
|-----|-------|-------------|
| 7-1 | Reserved | Always 0 |
| 0   | controller_status | 1=SNES active, 0=NES active |

### Standard Buttons Register (0x01)
| Bit | Button | Description        |
|-----|--------|--------------------|
| 7   | A      | A button (1=pressed) |
| 6   | B      | B button (1=pressed) |
| 5   | Select | Select button (1=pressed) |
| 4   | Start  | Start button (1=pressed) |
| 3   | Up     | Up button (1=pressed) |
| 2   | Down   | Down button (1=pressed) |
| 1   | Left   | Left button (1=pressed) |
| 0   | Right  | Right button (1=pressed) |

### SNES Extended Buttons Register (0x02)
| Bit | Button | Description        |
|-----|--------|--------------------|
| 7-4 | Reserved | Always 0        |
| 3   | X      | X button (1=pressed) |
| 2   | Y      | Y button (1=pressed) |
| 1   | L      | L button (1=pressed) |
| 0   | R      | R button (1=pressed) |

*Note: SNES extended buttons read as 0 when NES controller is active*

## How to test

Plug in the [SNES PMOD + Controller] or [NES controller + adapter] and read the associated data address:

1. **Basic Controller Detection:**
   - Read address 0x00 to check controller status
   - Bit 0: 1 = SNES detected, 0 = NES mode

2. **Button Reading:**
   - Read address 0x01 for standard 8-button state
   - Read address 0x02 for SNES extended buttons (if SNES active)
   - Button state: 1 = pressed, 0 = released

- **Example Code:**
   ```c
   // Check controller type
   uint8_t status = read_peripheral(0x00);
   bool is_snes = (status & 0x01);
   
   // Read standard buttons
   uint8_t buttons = read_peripheral(0x01);
   bool a_pressed = (buttons & 0x80);
   bool start_pressed = (buttons & 0x10);
   
   // Read SNES extended buttons (if applicable)
   if (is_snes) {
       uint8_t ext_buttons = read_peripheral(0x02);
       bool x_pressed = (ext_buttons & 0x08);
   }
   ```

## External hardware

**For NES Controller:**
- Standard NES gamepad + Adapter
- 3 wire connection: Data (ui_in[1]), Latch (uo_out[6]), Clock (uo_out[7])

**For SNES Controller:**  
- SNES gamepad
- CH32V003-based SNES-compatible controller interface PMOD  
  (Available at: https://github.com/psychogenic/gamepad-pmod)
- 3 wire PMOD connection: Data (ui_in[2]), Clock (ui_in[3]), Latch (ui_in[4])

## Verification Plan

**FPGA Prototyping:**
- Real hardware validation on both NES and SNES controllers
- Recorded demonstration videos available: [NES FPGA Test](https://drive.google.com/file/d/1BqGLOE_gKf2GouaVBYqFd00kkwdsnnQ2/view?usp=sharing)
[SNES FPGA Test](https://drive.google.com/file/d/1PY9-svxJRjp5iImp9vOvUZB5ECgRoXVd/view?usp=sharing)


**Constrained Random Testing:**
- 100-test regression using custom cocotb framework
- Random button press/release sequences at random timing
- Achieved 100% line coverage, 31% toggle coverage, 72% combinational logic coverage

**Coverage Report:**

```

Covered covered-0.7.10 -- Verilog Code Coverage Utility
Written by Trevor Williams  (phase1geo@gmail.com)
Freely distributable under the GPL license

                            :::::::::::::::::::::::::::::::::::::::::::::::::::::
                            ::                                                 ::
                            ::  Covered -- Verilog Coverage Summarized Report  ::
                            ::                                                 ::
                            :::::::::::::::::::::::::::::::::::::::::::::::::::::


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   GENERAL INFORMATION   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
* Report generated from CDD file : cov.cdd

* Reported by                    : Module

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   LINE COVERAGE RESULTS   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module/Task/Function      Filename                 Hit/ Miss/Total    Percent hit
---------------------------------------------------------------------------------------------------------------------
  $root                   NA                         0/    0/    0      100%
  tqvp_nes_snes_contro    peripheral.v               2/    0/    2      100%
  NESTest_Top             FPGA_NESReciever.v        13/    0/   13      100%
  NES_Reciever            FPGA_NESReciever.v       139/    0/  139      100%
  gamepad_pmod_single     FPGA_NESReciever.v         0/    0/    0      100%
  gamepad_pmod_driver     FPGA_NESReciever.v        18/    2/   20       90%
  gamepad_pmod_decoder    FPGA_NESReciever.v         7/    0/    7      100%
---------------------------------------------------------------------------------------------------------------------
  Accumulated                                      179/    2/  181       99%


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   TOGGLE COVERAGE RESULTS   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                           Toggle 0 -> 1                       Toggle 1 -> 0
Module/Task/Function      Filename                 Hit/ Miss/Total    Percent hit      Hit/ Miss/Total    Percent hit
---------------------------------------------------------------------------------------------------------------------
  $root                   NA                         0/    0/    0      100%             0/    0/    0      100%
  tqvp_nes_snes_contro    peripheral.v              12/   40/   52       23%            10/   42/   52       19%
  NESTest_Top             FPGA_NESReciever.v         5/   37/   42       12%             6/   36/   42       14%
  NES_Reciever            FPGA_NESReciever.v        36/   25/   61       59%            36/   25/   61       59%
  gamepad_pmod_single     FPGA_NESReciever.v         2/   28/   30        7%             1/   29/   30        3%
  gamepad_pmod_driver     FPGA_NESReciever.v         2/   35/   37        5%             1/   36/   37        3%
  gamepad_pmod_decoder    FPGA_NESReciever.v         0/   55/   55        0%             0/   55/   55        0%
---------------------------------------------------------------------------------------------------------------------
  Accumulated                                       57/  220/  277       21%            54/  223/  277       19%


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   COMBINATIONAL LOGIC COVERAGE RESULTS   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                                            Logic Combinations
Module/Task/Function                Filename                          Hit/Miss/Total    Percent hit
---------------------------------------------------------------------------------------------------------------------
  $root                             NA                                  0/   0/   0      100%
  tqvp_nes_snes_controller          peripheral.v                       14/   4/  18       78%
  NESTest_Top                       FPGA_NESReciever.v                 26/  24/  50       52%
  NES_Reciever                      FPGA_NESReciever.v                133/  47/ 180       74%
  gamepad_pmod_single               FPGA_NESReciever.v                  0/   0/   0      100%
  gamepad_pmod_driver               FPGA_NESReciever.v                 15/  15/  30       50%
  gamepad_pmod_decoder              FPGA_NESReciever.v                 31/  53/  84       37%
---------------------------------------------------------------------------------------------------------------------
  Accumulated                                                         219/ 143/ 362       60%


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

```
