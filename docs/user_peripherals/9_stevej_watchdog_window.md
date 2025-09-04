<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

Author: Steve Jenson <stevej@gmail.com>
Peripheral Index: 9

## What it does

This is a watchdog timer with a 32-bit counter and optional window feature. A watchdog timer resets if a pat is not sent regularly before the window times out. A watchdog is used to ensure that a microcontroller is giving consistent time slices to the tasks it's running. In a watchdog, a windowing feature allows you to ensure even more consistency by limiting not just how many cycles until the watchdog triggers but how many cycles the window will wait before it will allow you to register the pat to reset the timer.

An example: If you're expecting your watchdog pat task to run every 1 million cycles with a standard deviation of 10%, you can set a `WINDOW_OPEN` time of 800,000 cycles and an `WINDOW_CLOSE` time of 1.2 million cycles and feel confident that the watchdog pats are happening when you're expecting them to.

`WINDOW_CLOSE` is how many cycles until the watchdog timer triggers an interrupt.
`WINDOW_OPEN` is how long the watchdog waits before allowing a pat to be registered. Must be less than WINDOW_CLOSE because I don't know what your intention would be like otherwise. WINDOW_OPEN can be 0.

Remember to ENABLE the timer after setting WINDOW_CLOSE if you want the watchdog to start.

You can cancel a timer by setting ENABLE to 0. This can be done either before or after the timer has tripped.

`out[0]` is an interrupt line pulled high when the watchdog trips.
`out[1]` is an interrupt line pulled low when the watchdog trips.
`out[2]` is a line pulled high for 1 cycle when PAT is set 1.
`out[3]` is high if the watchdog is enabled.
`out[4]` is high if we're after the Start time of the window.
`out[5]` is high if we're after the End time of the window.
`out[6]` is unused.
`out[7]` is unused.

## Register map

The following registers are used to interact with the watchdog

| Address | Name    | Access | Description                                                         |
|---------|---------|--------|---------------------------------------------------------------------|
| 0x00    | ENABLE  | R/W    | 1 = Enable, 0 = Disable. |
| 0x01    | WINDOW_OPEN | R/W    | 32-bit value for how many cycles after reset the watchdog window should wait for a before allowing pats to be registered. |
| 0x02    | WINDOW_CLOSE    | R/W      | 32-bit value for how many cycles after reset the watchdog should wait until tripping if a pat isn't sent. |
| 0x03    | PAT | R/W   | 1=Pat. 0=Undefined "Patting" the watchdog timer causes it to reset the timer. |


## How to test

Set `WINDOW_CLOSE` to 100
Set `ENABLE` to 1
Wait 101 cycles
`out[0]` should be high
`out[1]` should be low

Set WINDOW_CLOSE to 100
Set ENABLE to 1
Wait 50 cycles
Set ENABLE to 0
Wait 51 more cycles
The watchdog should not have triggered so check `out[0]` and `out[1]`
`out[0]` should still be low
`out[1]` should still be high

Notes:

You can set `WINDOW_OPEN` and `WINDOW_CLOSE` while the timer is running but that's untested and thus could result in a rip in the space time continuum. Set `ENABLE` to 0 first to safely change the window parameters with predictable, tested, behavior.

## External hardware

None required.
