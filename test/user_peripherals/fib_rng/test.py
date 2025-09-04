# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV


# Register Map
FIBREG1 = 0
FIBREG2 = 1
FIBREG3 = 2
FIBREG4 = 3

TAPS1 = 4
TAPS2 = 5
TAPS3 = 6
TAPS4 = 7

# use different names for writing (CMD_REG, executing a command)
# and reading (MODE_REG, queyring the mode of operation)
CMD_REG = 15
MODE_REG = 15

# Supported Commands
CMD_STOP = 0
CMD_RUN = 1
CMD_EXPLICIT= 2
CMD_ADVANCE = 3
CMD_NOP = 4 # actually any value >= 4

# Values corresponding to the different modes

MODE_STOPPED = 0
MODE_RUNNING = 1
MODE_EXPLICIT = 2


# When submitting your design, change this to 16 + the peripheral number
# in peripherals.v.  e.g. if your design is i_user_simple00, set this to 16.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 17

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Interact with your design's registers through this TinyQV class.
    # This will allow the same test to be run when your design is integrated
    # with TinyQV - the implementation of this class will be replaced with a
    # different version that uses Risc-V instructions instead of the SPI 
    # interface to read and write the registers.
    tqv = TinyQV(dut, PERIPHERAL_NUM)

    # Reset, always start the test by resetting TinyQV
    await tqv.reset()

    dut._log.info("Test Fibonacci RNG behavior")

    # Check that the design is in the inteded initial state
    # (note the things to do to reset above)
    await check_initial_state(dut,tqv)

    # Check that when not in the runnign state, the RNG does not advance on its own.
    # The test swithces to free running mode for a short time to get new values that
    # are then kept fixated.
    await check_stopped_rng(dut,tqv)

    await check_mode_changes(dut,tqv)

    # Test some maximally long cycles. The used tap is annotated after the call to the test function
    #
    # The values have been taken from 
    # https://en.wikipedia.org/wiki/Linear-feedback_shift_register#Example_polynomials_for_maximal_LFSRs
    # 
    # Note that in the table, in contrast to the text above on the page and in the implementation of the 
    # Fibonaccy LFSR sent to TTQV, the count starts from the right.
    # As we have a fixes word size of 8, padding bits (zeros) have been added to the right (indicated by
    # parantheses).
    await check_full_cycle(dut, tqv, 2, 192) # 11(000000)
    await check_full_cycle(dut, tqv, 3, 96) # 011(00000)
    await check_full_cycle(dut, tqv, 4, 48) # 0011(0000)
    # await check_full_cycle(dut, tqv, 5, 40) # 00101(000)
    # await check_full_cycle(dut, tqv, 6, 12) # 000011(00)
    # await check_full_cycle(dut, tqv, 7, 6) # 0000011(0)
    # await check_full_cycle(dut, tqv, 8, 29) # 00011101

    await check_non_full_cycle(dut, tqv)

    await check_stuck_when_zero(dut, tqv)

    # Resetting the design should yield the initial state back
    await tqv.reset()
    await check_initial_state(dut,tqv)

    await how_to_test_example(tqv)


async def how_to_test_example(tqv):
    """
    The implementation of the example used in the `How to test` section of the documentation.

    Parameters
    ----------
        tqv: The interface to the peripheral
    """    
    await tqv.write_reg(CMD_REG, CMD_STOP)

    await tqv.write_reg(FIBREG1, int('11100000',2))
    # FibReg2, FibReg3 and FibReg4 do not need to be set to zero
    # but we do it "to be safe" anyways
    await tqv.write_reg(FIBREG2, 0)
    await tqv.write_reg(FIBREG3, 0)
    await tqv.write_reg(FIBREG4, 0)

    await tqv.write_reg(TAPS1, int('01100000',2)) 
    # you *need* to clear the upper tap bits!
    await tqv.write_reg(TAPS2, 0)
    await tqv.write_reg(TAPS3, 0)
    await tqv.write_reg(TAPS3, 0)

    await tqv.write_reg(CMD_REG, MODE_EXPLICIT)


    for i in range(8):
        # get current state of the RNG
        val = await tqv.read_reg(FIBREG1)

        # extract and print the upper bits
        v = f"{val:=08b}"[0:3]
        print(f"{i}: r=<{v}> b={v[-1]}")

        await tqv.write_reg(CMD_REG, CMD_ADVANCE)

async def stop(tqv):
    """
    Sets the mode of operation of FibRNG to 'Stopped'

    Parameters
    ----------
        tqv: The interface to the peripheral
    """
    await tqv.write_reg(CMD_REG, CMD_STOP)

async def set_running(tqv):
    """
    Sets the mode of operation of FibRNG to 'Running'

    Parameters
    ----------
        tqv: The interface to the peripheral
    """
    await tqv.write_reg(CMD_REG, CMD_RUN)

async def set_explicit(tqv):
    """
    Sets the mode of operation of FibRNG to 'Explicit'

    Parameters
    ----------
        tqv: The interface to the peripheral
    """    
    await tqv.write_reg(CMD_REG, CMD_EXPLICIT)



async def advance(tqv):
    """
    Sents the 'Advance' command to FibRNG

    Parameters
    ----------
        tqv: The interface to the peripheral
    """
    await tqv.write_reg(CMD_REG, CMD_ADVANCE)    

async def nop(tqv):
    """
    Sends the 'NOP' command to FibRNG

    Parameters
    ----------
        tqv: The interface to the peripheral
    """
    await tqv.write_reg(CMD_REG, CMD_NOP)        


async def readLFSR(tqv):
    """
    Reads the four LFSR words

    FibRNG must be either Stopped or in Explicit mode!

    Parameters
    ----------
        tqv: The interface to the peripheral


    Returns
    -------
    list<int>
        The list [FIBREG1, FIBREG2. FIBREG3, FIBREG4]

    """
    fibReg1 = await tqv.read_reg(FIBREG1)
    fibReg2 = await tqv.read_reg(FIBREG2)
    fibReg3 = await tqv.read_reg(FIBREG3)
    fibReg4 = await tqv.read_reg(FIBREG4)

    return [fibReg1,fibReg2,fibReg3,fibReg4]

async def readTaps(tqv):
    """
    Reads the four tap words

    FibRNG must be either Stopped or in Explicit mode!

    Parameters
    ----------
        tqv: The interface to the peripheral


    Returns
    -------
    list<int>
        The list [TAPS1, TAPS2. TAPS3, TAPS4]

    """
    tap0 = await tqv.read_reg(TAPS1)
    tap1 = await tqv.read_reg(TAPS2)
    tap2 = await tqv.read_reg(TAPS3)
    tap3 = await tqv.read_reg(TAPS4)

    return [tap0,tap1,tap2,tap3]


async def readMode(tqv):
    """
    Reads the current mode of FibRNG

    FibRNG must be either Stopped or in Explicit mode!

    Parameters
    ----------
        tqv: The interface to the peripheral


    Returns
    -------
    int
        The mode, FibRNG is in 

    """
    mode = await tqv.read_reg(MODE_REG)
    return mode


async def writeTap(tqv,idx,val):
    """
    Writes a value to the specified tap word.

    FibRNG should be either Stopped or in Explicit mode!

    Parameters
    ----------
        tqv: The interface to the peripheral
        idx (int): The number of the tap word to write (1<=idx<=4)
        val (int): The value to write to the tap word

    """    
    assert idx >= 0
    assert idx < 4
    await tqv.write_reg(idx+4,val)


async def writeTaps(tqv,vals):
    """
    Writes values to all four tap words.

    FibRNG should be either Stopped or in Explicit mode!

    Parameters
    ----------
        tqv: The interface to the peripheral
        vals list<int>: The four words to write to the taps vector

    """        
    assert len(vals) >= 4
    await tqv.write_reg(TAPS1,vals[0])
    await tqv.write_reg(TAPS2,vals[1])
    await tqv.write_reg(TAPS3,vals[2])
    await tqv.write_reg(TAPS4,vals[3])

async def writeLFSR(tqv,idx,val):
    """
    Writes a value to the specified LFSR word.

    FibRNG should be either Stopped or in Explicit mode!

    Parameters
    ----------
        tqv: The interface to the peripheral
        idx (int): The number of the tap word to write (1<=idx<=4)
        val (int): The value to write to the LSFR word

    """        
    assert idx >= 0
    assert idx < 4
    await tqv.write_reg(idx,val)


async def writeLFSRs(tqv,vals):
    """
    Writes values to all four LFSR words.

    FibRNG should be either Stopped or in Explicit mode!

    Parameters
    ----------
        tqv: The interface to the peripheral
        vals list<int>: The four words to write to the LFSR vector

    """       
    await tqv.write_reg(FIBREG1,vals[0])
    await tqv.write_reg(FIBREG2,vals[1])
    await tqv.write_reg(FIBREG3,vals[2])
    await tqv.write_reg(FIBREG4,vals[3])



def printWords(w):
    """
    Prints a vector (either LFSR or the taps) in a nice way

    Parameters
    ----------
        w (list<int>): The vector to be pretty printed
    """
    assert len(w) == 4
    print(f"<{w[0]:=08b} {w[1]:=08b} {w[2]:=08b} {w[3]:=08b}>")



async def stoppedIsFixed(dut,tqv,vals):
    """
    Checks that specified values remain the same when the RNG is stopped

    Parameters
    ----------
        dut: The design under test
        tqv: The interface to the FibRNG peripheral
        vals (list<int>): The four values that should remain the same
    """
    for n in range(10):
        await ClockCycles(dut.clk,n)
        lfsr = await readLFSR(tqv)
        assert lfsr == vals

async def check_stopped_rng(dut,tqv):
    """
    Checks that FibRNG does not change its internal state when stopped

    Assumptions
    -----------
    This function assumes that FibRNG is in its initial state. Otherwise, the tests
    will fail.

    Parameters
    ----------
        dut: The design under test
        tqv: The interface to the FibRNG peripheral
    """
    dut._log.info("A stopped RNG should always produce the same values")

    
    await stoppedIsFixed(dut,tqv,[255,255,255,255])

    await ClockCycles(dut.clk,4)
    await stoppedIsFixed(dut,tqv,[255,255,255,255])

    # Let it tick for some time and then stop it again
    await set_running(tqv)
    await ClockCycles(dut.clk,23)
    await stop(tqv)


    w = await readLFSR(tqv)
    await stoppedIsFixed(dut,tqv,w)

    # An advance command should not do anything when the RNG is stopped
    await advance(tqv)
    await stoppedIsFixed(dut,tqv,w)

    await ClockCycles(dut.clk,3)

async def check_mode_changes(dut,tqv):
    """
    Checks that changing the mode of operation is reflected when reading the current mode.

    Parameters
    ----------
        dut: The design under test
        tqv: The interface to the FibRNG peripheral
    """

    dut._log.info("Changing the modes can be seen when querying afterwards")

    await set_running(tqv)
    assert await readMode(tqv) == MODE_RUNNING

    await set_explicit(tqv)
    assert await readMode(tqv) == MODE_EXPLICIT

    await stop(tqv)
    assert await readMode(tqv) == MODE_STOPPED

async def check_full_cycle(dut, tqv, n, tap):
    """
    Checks that FibRNG does produce the maximal length cycle of a given length.

    Parameters
    ----------
        dut: The design under test
        tqv: The interface to the FibRNG peripheral
        n (int): The length of the RNG in bits
        tap (int): The tap to use (i.e. TAPS1)
    """


    dut._log.info(f"Testing the maximal cycle for {n} bits")

    assert n <= 8

    await stop(tqv)
    await writeLFSR(tqv,0,255) # start with all ones set
    await writeTaps(tqv,[tap,0,0,0])
    await set_explicit(tqv)

    # bitstring consisting of "1"'s only
    initVal = f"{2**n-1:=0b}" 

    def extract_n_bits(n,val):
        return f"{val:=08b}"[0:n]

    w = (await readLFSR(tqv))[0]
    wS = extract_n_bits(n,w)
    assert wS == initVal
    assert (await readTaps(tqv))[0] == tap

    for i in range((2**n)-2):
        await advance(tqv)
        w = (await readLFSR(tqv))[0]
        wS = extract_n_bits(n,w)
        #print(f"{i:=3}: {w:=08b} {wS}")
        assert w != initVal
        assert (await readTaps(tqv))[0] == tap

    await advance(tqv)
    w = (await readLFSR(tqv))[0]
    wS = extract_n_bits(n,w)
    #print(f"{2**n-2:=3}: {w:=08b} {wS}")
    assert wS == initVal
    assert (await readTaps(tqv))[0] == tap

async def check_non_full_cycle(dut, tqv):
    """
    Checks that FibRNG produces non maximal cycles with a bad choice of taps

    Parameters
    ----------
        dut: The design under test
        tqv: The interface to the FibRNG peripheral
    """


    dut._log.info(f"Check that FibRNG produces non maximal cycles with a bad choice of taps")

    n = 4
    tap = int('01010000',2)

    await stop(tqv)
    await writeLFSR(tqv,0,255) # start with all ones set
    await writeTaps(tqv,[tap,0,0,0])
    await set_explicit(tqv)

    # bitstring consisting of "1"'s only
    initVal = f"{2**n-1:=0b}" 

    print("For n=4 the tap '0101' yields a cycle length of 7:")

    def extract_n_bits(n,val):
        return f"{val:=08b}"[0:n]

    for i in range((2**n)):
        w = (await readLFSR(tqv))[0]
        wS = extract_n_bits(n,w)
        print(f" {i:=2}: r=<{wS}>")
        await advance(tqv)



async def check_initial_state(dut,tqv):
    """
    Checks that FibRNG is in its well-defined initial state after reset.

    Assumptions
    -----------
    FibRNG has been reset before calling this method

    Parameters
    ----------
        dut: The design under test
        tqv: The interface to the FibRNG peripheral
    """    

    dut._log.info("Check that the initial state is as expected")

    m = await readMode(tqv)
    assert m == MODE_STOPPED
    await ClockCycles(dut.clk,4)

    lfsr = await readLFSR(tqv)
    assert lfsr == [255,255,255,255]

    taps = await readTaps(tqv)
    printWords(taps)
    assert taps == [192,0,4,1]


async def check_stuck_when_zero(dut, tqv):
    """
    Checks that FibRNG continuously produces zeros only, regardless of the taps
    when the bit-vector is set to zeroes only

    Parameters
    ----------
        dut: The design under test
        tqv: The interface to the FibRNG peripheral
    """

    dut._log.info("Check that a LSFR value of 0 is stuck")

    await set_explicit(tqv)
    await writeLFSRs(tqv, [0,0,0,0])

    for taps in [[4,0,0,0], [4,8,16,32], [0,0,0,0], [1,1,1,1]]:
        await writeTaps(tqv, taps)

        for i in range(10):
            assert (await readLFSR(tqv)) == [0,0,0,0]
            await advance(tqv)


