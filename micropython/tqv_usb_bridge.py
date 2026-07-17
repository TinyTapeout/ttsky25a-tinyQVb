import time
import sys
import rp2
import gc
import micropython
import machine
from machine import UART, Pin, PWM
import binascii
import usb.device
from usb.device.cdc import CDCInterface

print("\n\nRun TinyQV Begin")

# GPIO mapping for TT ETR v3.2 demo board
GPIO_PROJECT_CLK = 16
GPIO_PROJECT_RST_N = 14
GPIO_CTRL_ENA = 0
GPIO_CTRL_RST_N = 1
GPIO_CTRL_INC = 2
GPIO_UI_IN = [17, 18, 19, 20, 21, 22, 23, 24]
GPIO_UIO = [25, 26, 27, 28, 29, 30, 31, 32]
GPIO_UO_OUT = [33, 34, 35, 36, 37, 38, 39, 40]

clk_pin = Pin(GPIO_PROJECT_CLK, Pin.IN, Pin.PULL_DOWN)
proj_rst_n = Pin(GPIO_PROJECT_RST_N, Pin.IN, Pin.PULL_UP)
ctrl_ena = Pin(GPIO_CTRL_ENA, Pin.OUT, value=0)
ctrl_rst_n = Pin(GPIO_CTRL_RST_N, Pin.OUT, value=1)
ctrl_inc = Pin(GPIO_CTRL_INC, Pin.OUT, value=0)
ui_in = [Pin(pin, Pin.IN, Pin.PULL_DOWN) for pin in GPIO_UI_IN]
uio = [Pin(pin, Pin.IN, Pin.PULL_DOWN) for pin in GPIO_UIO]
uo_out = [Pin(pin, Pin.IN, Pin.PULL_DOWN) for pin in GPIO_UO_OUT]

def select_design(design):
    ctrl_ena.value(0)
    ctrl_inc.value(0)
    ctrl_rst_n.value(0)
    ctrl_rst_n.value(1)
    for _ in range(design):
        ctrl_inc.value(1)
        ctrl_inc.value(0)
    ctrl_ena.value(1)
    print(f"design={design}")


@rp2.asm_pio(out_shiftdir=0, autopull=True, pull_thresh=8, autopush=True, push_thresh=8, sideset_init=(rp2.PIO.OUT_LOW,), out_init=rp2.PIO.OUT_LOW)
def spi_cpha0():
    out(pins, 1)             .side(0x0)
    in_(pins, 1)             .side(0x1)

@rp2.asm_pio(out_shiftdir=0, autopull=True, pull_thresh=8, autopush=True, push_thresh=8, sideset_init=(rp2.PIO.OUT_LOW,), out_init=rp2.PIO.OUT_LOW)
def spi_cpha1():
    pull(ifempty)            .side(0x0)
    out(pins, 1)             .side(0x1).delay(1)
    in_(pins, 1)             .side(0x0)
    
class PIOSPI:

    def __init__(self, sm_id, pin_mosi, pin_miso, pin_sck, cpha=False, cpol=False, freq=1000000):
        assert(not(cpol))
        if not cpha:
            self._sm = rp2.StateMachine(sm_id, spi_cpha0, freq=2*freq, sideset_base=Pin(pin_sck), out_base=Pin(pin_mosi), in_base=Pin(pin_miso))
        else:
            self._sm = rp2.StateMachine(sm_id, spi_cpha1, freq=4*freq, sideset_base=Pin(pin_sck), out_base=Pin(pin_mosi), in_base=Pin(pin_miso))
        self._sm.active(1)

        self._sm_tx_dreq = sm_id
        self._sm_rx_dreq = sm_id + 4

        self._dma_write = rp2.DMA()
        self._dma_read = rp2.DMA()

    @micropython.native
    def write1(self, write):
        self._sm.put(write, 24)
        self._sm.get()

    @micropython.native
    def write(self, wdata):
        dummy_bytes = bytearray(1)
        self._dma_read.config(
            read = self._sm,
            write = dummy_bytes,
            count = len(wdata),
            ctrl = self._dma_read.pack_ctrl(
                size      = 0,  # 0 = byte, 1 = half word, 2 = word
                inc_read  = False,
                inc_write = False,
                treq_sel  = self._sm_rx_dreq
            ),
            trigger = True
        )

        self._dma_write.config(
            read = wdata,
            write = self._sm,
            count = len(wdata),
            ctrl = self._dma_write.pack_ctrl(
                size      = 0,  # 0 = byte, 1 = half word, 2 = word
                inc_read  = True,
                inc_write = False,
                treq_sel  = self._sm_tx_dreq
            ),
            trigger = True
        )

        while self._dma_read.active():
            pass
        
    @micropython.native
    def read(self, n, write=0):
        read_buf = bytearray(n)
        self.readinto(read_buf, write)
        return read_buf

    @micropython.native
    def readinto(self, rdata, write=0):
        write_bytes = bytearray(1)
        write_bytes[0] = write
        self._dma_read.config(
            read = self._sm,
            write = rdata,
            count = len(rdata),
            ctrl = self._dma_read.pack_ctrl(
                size      = 0,  # 0 = byte, 1 = half word, 2 = word
                inc_read  = False,
                inc_write = True,
                treq_sel  = self._sm_rx_dreq
            ),
            trigger = True
        )

        self._dma_write.config(
            read = write_bytes,
            write = self._sm,
            count = len(rdata),
            ctrl = self._dma_write.pack_ctrl(
                size      = 0,  # 0 = byte, 1 = half word, 2 = word
                inc_read  = False,
                inc_write = False,
                treq_sel  = self._sm_tx_dreq
            ),
            trigger = True
        )
        
        while self._dma_read.active():
            pass

    @micropython.native
    def write_read_blocking(self, wdata):
        rdata = bytearray(len(wdata))

        self._dma_read.config(
            read = self._sm,
            write = rdata,
            count = len(rdata),
            ctrl = self._dma_read.pack_ctrl(
                size      = 0,  # 0 = byte, 1 = half word, 2 = word
                inc_read  = False,
                inc_write = True,
                treq_sel  = self._sm_rx_dreq
            ),
            trigger = True
        )

        self._dma_write.config(
            read = wdata,
            write = self._sm,
            count = len(wdata),
            ctrl = self._dma_write.pack_ctrl(
                size      = 0,  # 0 = byte, 1 = half word, 2 = word
                inc_read  = True,
                inc_write = False,
                treq_sel  = self._sm_tx_dreq
            ),
            trigger = True
        )

        while self._dma_read.active():
            pass

        return rdata

@rp2.asm_pio(autopush=True, push_thresh=8, in_shiftdir=rp2.PIO.SHIFT_LEFT,
             autopull=True, pull_thresh=8, out_shiftdir=rp2.PIO.SHIFT_RIGHT,
             out_init=(rp2.PIO.OUT_HIGH, rp2.PIO.OUT_HIGH, rp2.PIO.IN_HIGH, rp2.PIO.OUT_HIGH,
                       rp2.PIO.IN_HIGH, rp2.PIO.IN_HIGH, rp2.PIO.OUT_HIGH, rp2.PIO.OUT_HIGH),
             sideset_init=(rp2.PIO.OUT_HIGH))
def qspi_read():
    out(x, 8).side(1)
    out(y, 8).side(1)
    out(pindirs, 8).side(1)
    
    label("cmd_loop")
    out(pins, 8).side(0)
    jmp(x_dec, "cmd_loop").side(1)
    
    out(pindirs, 8).side(0)
    label("data_loop")
    in_(pins, 8).side(1)
    jmp(y_dec, "data_loop").side(0)
    
    out(pins, 8).side(1)
    out(pindirs, 8).side(1)

@rp2.asm_pio(autopush=True, push_thresh=32, in_shiftdir=rp2.PIO.SHIFT_RIGHT)
def pio_capture():
    in_(pins, 8)
    
def spi_cmd(spi, data, sel, dummy_len=0, read_len=0):
    dummy_buf = bytearray(dummy_len)
    read_buf = bytearray(read_len)
    
    sel.off()
    spi.write(bytearray(data))
    if dummy_len > 0:
        spi.readinto(dummy_buf)
    if read_len > 0:
        spi.readinto(read_buf)
    sel.on()
    
    return read_buf

def setup_pmod():
    flash_sel = Pin(GPIO_UIO[0], Pin.OUT, value=1)
    ram_a_sel = Pin(GPIO_UIO[6], Pin.OUT, value=1)
    ram_b_sel = Pin(GPIO_UIO[7], Pin.OUT, value=1)
    
    spi = PIOSPI(2, Pin(GPIO_UIO[1]), Pin(GPIO_UIO[2]), Pin(GPIO_UIO[3]), freq=10000000)

    # Enter QPI mode on the RAM chips
    for sel in (ram_a_sel, ram_b_sel):
        spi_cmd(spi, [0x35], sel)

    # Leave CM mode if in it
    spi_cmd(spi, [0xFF], flash_sel)
    spi._sm.active(0)
    del spi

    sm = rp2.StateMachine(0, qspi_read, 16_000_000, in_base=Pin(GPIO_UIO[0]), out_base=Pin(GPIO_UIO[0]), sideset_base=Pin(GPIO_UIO[3]))
    sm.active(1)
    
    # Read 1 byte from address 0 to get into continuous read mode
    num_bytes = 4
    buf = bytearray(num_bytes*2 + 4)
    
    sm.put(8+6+2-1)     # Command + Address + Dummy - 1
    sm.put(num_bytes*2 + 4 - 1) # Data + Dummy - 1
    sm.put(0b11111111)  # Directions
    
    # RAM_B_SEL, RAM_A_SEL, SD3, SD2, SCK, SD1, SD0, CS
    sm.put(0b11000010)  # Command
    sm.put(0b11000010)
    sm.put(0b11000010)
    sm.put(0b11000000)
    sm.put(0b11000010)
    sm.put(0b11000000)
    sm.put(0b11000010)
    sm.put(0b11000010)
    
    sm.put(0b11000000)  # Address
    sm.put(0b11000000)
    sm.put(0b11000000)
    sm.put(0b11000000)
    sm.put(0b11000000)
    sm.put(0b11000000)
    sm.put(0b11100100) 
    sm.put(0b11100100)
    
    sm.put(0b11001001)  # Directions
    
    for i in range(num_bytes*2 + 4):
        buf[i] = sm.get()
        if i >= 4:
            d = buf[i]
            nibble = ((d >> 1) & 1) | ((d >> 1) & 2) | ((d >> 2) & 0x4) | ((d >> 2) & 0x8)
            #print("%01x" % (nibble,), end="")
    #print()
        
    sm.put(0b11111111)
    sm.put(0b11001001)  # Directions
    sm.active(0)
    del sm
    
    flash_sel = Pin(GPIO_UIO[0], Pin.OUT, value=1)
    ram_a_sel = Pin(GPIO_UIO[6], Pin.OUT, value=1)
    ram_b_sel = Pin(GPIO_UIO[7], Pin.OUT, value=1)

def run(design, latency, freq):
    machine.freq(freq * 2)

    Pin(GPIO_UIO[0], Pin.IN, pull=Pin.PULL_UP)
    Pin(GPIO_UIO[1], Pin.IN, pull=None)
    Pin(GPIO_UIO[2], Pin.IN, pull=None)
    Pin(GPIO_UIO[3], Pin.IN, pull=None)
    Pin(GPIO_UIO[4], Pin.IN, pull=None)
    Pin(GPIO_UIO[5], Pin.IN, pull=None)
    Pin(GPIO_UIO[6], Pin.IN, pull=Pin.PULL_UP)
    Pin(GPIO_UIO[7], Pin.IN, pull=Pin.PULL_UP)

    print()
    select_design(design)

    # Pull up UART RX
    Pin(GPIO_UI_IN[7], Pin.IN, pull=Pin.PULL_UP)
    
    # All other inputs pulled low
    for i in range(7):
        Pin(GPIO_UI_IN[i], Pin.IN, pull=Pin.PULL_DOWN)

    clk = Pin(GPIO_PROJECT_CLK, Pin.OUT, value=0)
    rst_n = Pin(GPIO_PROJECT_RST_N, Pin.OUT, value=1)
    for i in range(2):
        clk.on()
        clk.off()
    rst_n.off()
    
    clk.on()
    time.sleep(0.001)
    clk.off()
    time.sleep(0.001)

    setup_pmod()

    flash_sel = Pin(GPIO_UIO[0], Pin.OUT)
    qspi_sd0  = Pin(GPIO_UIO[1], Pin.OUT)
    qspi_sd1  = Pin(GPIO_UIO[2], Pin.OUT)
    qspi_sck  = Pin(GPIO_UIO[3], Pin.OUT)
    qspi_sd2  = Pin(GPIO_UIO[4], Pin.OUT)
    qspi_sd3  = Pin(GPIO_UIO[5], Pin.OUT)
    ram_a_sel = Pin(GPIO_UIO[6], Pin.OUT)
    ram_b_sel = Pin(GPIO_UIO[7], Pin.OUT)

    qspi_sck.off()
    flash_sel.off()
    ram_a_sel.off()
    ram_b_sel.off()
    qspi_sd0.value((latency & 1) == 1)
    qspi_sd1.value((latency & 2) == 2)
    qspi_sd2.off()
    qspi_sd3.off()

    for i in range(10):
        clk.off()
        time.sleep(0.001)
        clk.on()
        time.sleep(0.001)

    Pin(GPIO_UIO[0], Pin.IN, pull=Pin.PULL_UP)
    Pin(GPIO_UIO[1], Pin.IN, pull=None)
    Pin(GPIO_UIO[2], Pin.IN, pull=None)
    Pin(GPIO_UIO[3], Pin.IN, pull=None)
    Pin(GPIO_UIO[4], Pin.IN, pull=None)
    Pin(GPIO_UIO[5], Pin.IN, pull=None)
    Pin(GPIO_UIO[6], Pin.IN, pull=Pin.PULL_UP)
    Pin(GPIO_UIO[7], Pin.IN, pull=Pin.PULL_UP)
    
    rst_n.on()
    time.sleep(0.001)
    clk.off()

    if design == 39:  # GF 0p2 is slow, really needs CTS.  Default freq is 24MHz, so adjust baudrate accordingly
        baud = int(115200 * freq / 24000000)
        uart_out = UART(1, baudrate=baud, tx=Pin(GPIO_UI_IN[7]), rx=None, cts=Pin(GPIO_UO_OUT[5]), flow=UART.CTS)
    elif design == 514:  # For FemtoRV on TT sky25b
        baud = int(115200 * freq / 50000000)
        uart_out = UART(1, baudrate=baud, tx=Pin(GPIO_UI_IN[7]), rx=None)
    else:
        baud = int(115200 * freq / 64000000)
        uart_out = UART(1, baudrate=baud, tx=Pin(GPIO_UI_IN[7]), rx=None)
    uart_in = UART(0, baudrate=baud, rx=Pin(GPIO_UO_OUT[0]), tx=None)
    time.sleep(0.001)
    clk = PWM(Pin(GPIO_PROJECT_CLK), freq=freq, duty_u16=32768)

    try:
        while True:
            time.sleep_us(10)
            if cdc._rb.readable():
                c = cdc.read(1)
                uart_out.write(c)

            uart_data = uart_in.read(128)
            while uart_data:
                cdc.write(uart_data)
                uart_data = uart_in.read(128)
    finally:
        print("TinyQV stop")

cdc = CDCInterface()
cdc.init(timeout=0)  # zero timeout makes this non-blocking, suitable for os.dupterm()

# pass builtin_driver=True so that we get the built-in USB-CDC alongside,
# if it's available.
usb.device.get().init(cdc, builtin_driver=True)

print("Waiting for USB host to configure the interface...")

# wait for host enumerate as a CDC device...
while not cdc.is_open():
    time.sleep_ms(100)
    
while not cdc.dtr:
    time.sleep_ms(100)
    
print("Connected")

# Choose one:

# For gf0p2
#run(39, 1, 24_000_000)

# For sky25a Asteroids
#run(495, 2, 64_000_000)

# For sky25a Berzerk
run(687, 2, 64_000_000)
