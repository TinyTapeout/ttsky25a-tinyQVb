import machine
from machine import Pin
from tinyqv import get_base_address

PERIPHERAL_NUM = 8
BASE_ADDRESS = get_base_address(PERIPHERAL_NUM)

REG_PERIOD = 0
REG_PHASE = 1
REG_AMP = 2
REG_SLOPE_R = 4
REG_SLOPE_F = 6
REG_PWM_OFFSET = 8
REG_MODE = 10
REG_SWEEP_PA = 12
REG_SWEEP_WS = 14

WAVEFORM_LINEAR_OSC = 0
WAVEFORM_NOISE = 1
WAVEFORM_PWL_OSC = 2
WAVEFORM_ORION = 3

OSC_SYNC_OFF = 0
OSC_SYNC_4_BIT = 1
OSC_SYNC_HARD = 2
OSC_SYNC_SOFT = 3

CFG_STEREO_EN = 1
CFG_STEREO_POS_EN = 2
CFG_QUANT_FIX_EN = 4
CFG_LIN_NOISE_EN = 4096

# Chromatic scale starting on B
note_mantissas = [1001, 887, 780, 679, 583, 493, 408, 327, 252, 180, 112, 49]

note_names = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11};

# Store current channel values so that we can restore or modify them
curr_on = [False]*4
curr_slopes_r = [0]*4
curr_slopes_f = [0]*4
curr_pwm_offsets = [0]*4
curr_modes = [0]*4
curr_sweep_pa = [0]*4
curr_sweep_ws = [0]*4
curr_cfg = 0

# Register access for peripheral version:

def raw_reg_write(address, data):
	machine.mem16[BASE_ADDRESS + (address&63)] = data

def raw_reg_read(address):
	return machine.mem16[BASE_ADDRESS + (address&63)]

# Register access for deluxe version:

#READ_SEL_HIGH = 16
#CMD_READ = 8
#CMD_WRITE = 4
#CMD_DATA_HIGH = 2
#CMD_DATA_LOW = 1
#
#READ_WAITING = 32
#
#def raw_reg_write(addr, value):
#	tt.input_byte = value & 0xff
#	tt.bidir_byte = CMD_DATA_LOW
#	# should wait for 3 cycles here, assume we don't have to
#
#	tt.input_byte = (value >> 8) & 0xff
#	tt.bidir_byte = CMD_DATA_HIGH
#	# should wait for 3 cycles here, assume we don't have to
#
#	tt.input_byte = addr
#	tt.bidir_byte = CMD_WRITE
#	# should wait for 3 cycles here, assume we don't have to
#	# should wait for 4 cycles here for the write to take effect, assume we don't have to
#
#def raw_reg_read(addr):
#	tt.input_byte = addr
#	tt.bidir_byte = CMD_READ
#	# should wait for 4 cycles here, assume we don't have to
#
#	wait_counter = 0
#	while (tt.bidir_byte & READ_WAITING) != 0:
#		wait_counter += 1
#		assert wait_counter < 70
#
#	data = tt.output_byte
#	tt.bidir_byte = READ_SEL_HIGH
#	# should wait for 1 cycle here, assume we don't have to
#	data |= tt.bidir_byte << 8
#
#	return data


def reg_write(channel, reg, data):
	raw_reg_write(channel*16 + reg, data)

def reg_read(channel, reg):
	return raw_reg_read(channel*16 + reg)

def set_cfg(cfg, dcounter_step=256):
	cfg &= ~(0x1ff << 3)
	cfg |= (dcounter_step & 0x1ff) << 3
	curr_cfg = cfg
	raw_reg_write(0x23, cfg)

def sweeps_off(channel):
	reg_write(channel, REG_SWEEP_PA, 0)
	reg_write(channel, REG_SWEEP_WS, 0)

def note_off(channel):
	reg_write(channel, REG_SWEEP_PA, 0) # make sure that amp doesn't start to sweep upward after we set it to zero
	reg_write(channel, REG_AMP, 0)
	curr_on[channel] = False

def all_notes_off():
	for channel in range(4): note_off(channel)

def play_raw_note(channel, f_period, amp=63):
	reg_write(channel, REG_PERIOD, f_period)
	reg_write(channel, REG_AMP, amp)
	curr_on[channel] = True

def get_f_period(note, octave = 4):
	note += 12*octave
	note += 1 # since note_mantissas starts on B
	note, octave = note % 12, note // 12

	if octave < 0: octave = 0
	elif octave > 7: octave = 7

	mantissa = note_mantissas[note]
	if octave >= 6: mantissa &= -1 << (octave - 5) # round to make sure that we hit an integer period

	return mantissa | ((7-octave)<<10)

def write_curr_waveform(channel):
	reg_write(channel, REG_SLOPE_R, curr_slopes_r[channel])
	reg_write(channel, REG_SLOPE_F, curr_slopes_f[channel])
	reg_write(channel, REG_PWM_OFFSET, curr_pwm_offsets[channel])
	reg_write(channel, REG_MODE, curr_modes[channel])

# note can be an integer (semitones from C0) or (name, octave), where name is a key in note_names
# relative_detune is specified in semitones: increase by 12 to double the detuning (or set to None to turn off detuning)
def play_note(channel, note, amp=63, relative_detune=0):
	if isinstance(note, tuple):
		note_name, octave = note
		note = note_names[note_name] + octave*12

	# Set detuning based on note frequency
	if relative_detune == None:
		detune_f = 0
	else:
		detune_f =(note + relative_detune) // 6
		detune_f = max(0, min(15, detune_f))

	# Update detune_exp and possibly detune_frac
	mode = curr_modes[channel]
	mode = (mode & ~7) | (detune_f >> 1)
	if (curr_cfg & CFG_STEREO_POS_EN) != 0 or (mode & 7 << 4) == 0: # set detune_frac when not using freq_mults (including when stereo position mode is on)
		mode = (mode & ~2048) | ((detune_f&1) << 11)
	curr_modes[channel] = mode

	note_off(channel)
	reg_write(channel, REG_SWEEP_WS, 0)
	write_curr_waveform(channel)
	play_raw_note(channel, get_f_period(note), amp)
	reg_write(channel, REG_SWEEP_PA, curr_sweep_pa[channel])
	reg_write(channel, REG_SWEEP_WS, curr_sweep_ws[channel])

def set_waveform(channel, slope_r=0, slope_f=0, pwm_offset=0, detune_exp=0, waveform=0, freq_mults=0, common_sat=False, osc_sync=0, detune_frac=False, common_quant=False, quantization_level=4):
	mode = (detune_exp&7) | ((waveform&1)<<3) | ((freq_mults&7)<<4) | ((common_sat&1)<<7) | ((waveform&2)<<7) | ((osc_sync&3)<<9) | ((detune_frac&1)<<11)
	mode |= (common_quant << 12) << ((quantization_level&7)<<13)

	curr_slopes_r[channel] = slope_r
	curr_slopes_f[channel] = slope_f
	curr_pwm_offsets[channel] = pwm_offset
	curr_modes[channel] = mode

	if curr_on[channel]:  # otherwise, the waveform will be applied when starting the next note
		write_curr_waveform(channel)

def set_period_amp_sweep(channel, period_down=False, period_rate=0, amp_target=0, amp_rate=0):
	if period_rate == 2: period_rate = 1 # represent as maximum rate
	if 0 < amp_rate <= 4: amp_rate = 1 # clamp to maximum rate, repesent amp_rate=4 as maximum rate

	period_sweep = (period_rate&15) | ((period_down&1)<<4)
	amp_sweep = (amp_rate&15) | ((amp_target&7) << 4)
	curr_sweep_pa[channel] = amp_sweep | (period_sweep << 8)
	if curr_on[channel]:
		reg_write(channel, REG_SWEEP_PA, curr_sweep_pa[channel])

def set_pwm_slope_sweep(channel, pwm_down=False, pwm_rate=0, slope_down=False, slope_dir=3, slope_rate=0):
	if 0 < pwm_rate <= 4: pwm_rate = 1 # clamp to maximum rate, repesent pwm_rate=4 as maximum rate
	if 0 < slope_rate <= 4: slope_rate = 1 # clamp to maximum rate, repesent slope_rate=4 as maximum rate

	pwm_sweep = (pwm_rate&15) | ((pwm_down&1)<<4)
	slope_sweep = (slope_rate&15) | ((slope_down&1) << 4) | ((slope_dir&3) << 5)
	curr_sweep_ws[channel] = slope_sweep | (pwm_sweep << 8)
	if curr_on[channel]:
		reg_write(channel, REG_SWEEP_WS, curr_sweep_ws[channel])

Pin(7, Pin.OUT, func_sel=PERIPHERAL_NUM)

from time import sleep

def test1():
	notes = [("C", 4), ("G", 4), ("B", 4), ("C", 5)]
	channel = 0
	relative_detune = 0  # Try to increase decrease, or set to None to turn off detuning

	# Fade out each note by sweeping down amp. Set amp_rate=0 to keep sustained.
	set_period_amp_sweep(channel, amp_target=0, amp_rate=12)  # amp_rate = 12 should ramp down in around 0.5 s at 64 MHz clock frequency

	for note in notes:
		play_note(channel, note, relative_detune=relative_detune)

		sleep(0.5)
	sleep(0.5)
	note_off(channel)

def test2():
	notes = [("D", 3), ("G", 3), ("C", 4), ("Eb", 4)]
	relative_detune = 0  # Try to increase decrease, or set to None to turn off detuning
	for (channel, note) in enumerate(notes):
		# Fade in each note by sweeping up amp. Takes effect when the next note is played.
		set_period_amp_sweep(channel, amp_target=63, amp_rate=12)  # amp_rate = 12 should ramp down in around 0.5 s at 64 MHz clock frequency

		play_note(channel, note, amp=0, relative_detune=relative_detune)

		sleep(0.5)
	sleep(0.5)
	all_notes_off()

def test3():
	channel = 0

	# Triangle wave.
	# Timbre initially becomes darker (more sine-like) when lowering amplitude from amp_s = 1.
	set_waveform(channel, slope_r=0, slope_f=0, pwm_offset=0)

	# 4 bit triangle wave
	set_waveform(channel, slope_r=0, slope_f=0, pwm_offset=0, osc_sync=OSC_SYNC_4_BIT)

	# Square wave
	slope = 12*16  # Reduce to make it smoother (eventually turning into a triangle wave)
	set_waveform(channel, slope_r=slope, slope_f=slope, pwm_offset=0)

	# Sawtooth-like wave
	slope = 12*16  # Reduce to make it smoother (eventually turning into a triangle wave)
	set_waveform(channel, slope_r=0, slope_f=slope, pwm_offset=0)

	# 25% duty pulse wave. Reduce both slope_s values equally to make it smoother.
	# Amplitude starts to drop when slope < 1*16.
	slope = 12*16  # Reduce to make it smoother
	set_waveform(channel, slope_r=slope, slope_f=slope, pwm_offset=128)

	# 12.5% duty pulse wave. Reduce both slope_s values equally to make it smoother.
	# Amplitude starts to drop when slope < 2*16.
	slope = 12*16  # Reduce to make it smoother
	set_waveform(channel, slope_r=slope, slope_f=slope, pwm_offset=192)

	# Sine wave approximation. Varying the amplitude and slope a bit
	# (while keeping both slopes the same) gives other approximattions.
	set_waveform(channel, slope_r=8, slope_f=8, pwm_offset=0)

	# Clamped triangle wave. Same spectrum as a triangle wave (but 6 dB louder) at full amplitude,
	# but timbre starts to become brighter as soon as lowering amplitude from amp_s = 1.
	set_waveform(channel, slope_r=16, slope_f=16, pwm_offset=0)

	# Noise. Don't use on channels 0 and 3 at the same time, note that channels 1 and 2 have noise with a short period (11 bit LFSR)
	set_waveform(channel, slope_r=0, slope_f=0, pwm_offset=0, waveform=WAVEFORM_NOISE)

	# Sawtooth-like wave with common saturation (works only on channel 0) and (3x, 2x) frequency multiplier (power chord).
	# Play one octave lower than it is intended to sound, since the frequency multipliers raise the frequency.
	slope = 12*16  # Reduce to make it smoother
	set_waveform(channel, slope_r=0, slope_f=slope, pwm_offset=0, freq_multipliers=3, common_sat=True)
	# Try with set_pwm_slope_sweep(channel, slope_down=True, slope_rate=12)

	set_pwm_slope_sweep(channel, slope_down=True, slope_rate=10)  # slope_rate = 10 should be enough to sweep from full slope to zero in about 0.5 s

	set_waveform(channel, slope_r=16, slope_f=16)
	set_period_amp_sweep(channel, period_down=False, period_rate=1, amp_target=0, amp_rate=8)
	play_note(channel, ("C", 4), amp=63, relative_detune=None)

	sleep(1)

	set_period_amp_sweep(channel, period_down=False, period_rate=1, amp_target=0, amp_rate=10)
	set_waveform(channel, slope_r=0, slope_f=0, pwm_offset=0, waveform=WAVEFORM_NOISE)
	play_note(channel, ("Bb", 7), amp=63, relative_detune=None)  # Bb7 is the highest note in the scale right now

if True:
	channel = 0
	slope = 12*16  # Reduce to make it smoother
	set_waveform(channel, slope_r=slope, slope_f=slope, pwm_offset=128)

test1()
test2()
test3()