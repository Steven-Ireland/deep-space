#!/usr/bin/env python3
"""Synthesizes the game's sounds (GDD §15, TECH §5) into assets/audio/: 22,050 Hz, 16-bit mono.

    python3 tools/build_audio.py

Every sound is built from seeded noise, tuned modes and biquad filters, so a rebuild writes the
same files. What it makes:
  ambient/   station_hum (the LANTERN, aboard) and derelict_ambience: 8 s loops; the jump's
             jump_spool, jump_enter (the tunnel's mouth), hyperspace_loop (7 s) and jump_exit
  player/    lamp_click_on, lamp_click_off: the helmet lamp's switch
  foley/     step_metal_01..04 (the LANTERN's deck), step_derelict_01..04, step_land (a jump or a
             fall), door_open and door_close (a sliding bulkhead door), terminal_click,
             terminal_beep and terminal_error (a console's key, its confirm and its refusal),
             fuel_cell_load (a cell seating in the fuel rack), item_pickup (taking a thing),
             hatch_open and hatch_close (a round pressure hatch), airlock_vent and airlock_fill
             (the collar's airlock cycling), dock_contact, dock_clamps and collar_motor
             (docking); and ambient/dock_siren, a 2 s loop (the undock warning)
A loop's .import file has it loop forward over the whole file: edit/loop_mode=2 (in Godot's WAV
importer 1 is Disabled) and edit/loop_end its length in samples (-1 drops the last).
"""

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050  # GDD §15: low-fi sound, 22 kHz samples
AUDIO = Path(__file__).resolve().parent.parent / "assets" / "audio"
LOOP_SECONDS = 8.0
HYPERSPACE_SECONDS = 7.0


# --- DSP Utilities ---

class Biquad:
    """Standard biquad filter (Direct Form I / II)."""
    def __init__(self):
        self.b0 = 1.0; self.b1 = 0.0; self.b2 = 0.0
        self.a1 = 0.0; self.a2 = 0.0
        self.x1 = 0.0; self.x2 = 0.0
        self.y1 = 0.0; self.y2 = 0.0

    @classmethod
    def lowpass(cls, fc, q=0.707, fs=SAMPLE_RATE):
        f = cls()
        w0 = 2.0 * math.pi * fc / fs
        alpha = math.sin(w0) / (2.0 * q)
        cos_w0 = math.cos(w0)
        a0 = 1.0 + alpha
        f.b0 = ((1.0 - cos_w0) / 2.0) / a0
        f.b1 = (1.0 - cos_w0) / a0
        f.b2 = ((1.0 - cos_w0) / 2.0) / a0
        f.a1 = (-2.0 * cos_w0) / a0
        f.a2 = (1.0 - alpha) / a0
        return f

    @classmethod
    def highpass(cls, fc, q=0.707, fs=SAMPLE_RATE):
        f = cls()
        w0 = 2.0 * math.pi * fc / fs
        alpha = math.sin(w0) / (2.0 * q)
        cos_w0 = math.cos(w0)
        a0 = 1.0 + alpha
        f.b0 = ((1.0 + cos_w0) / 2.0) / a0
        f.b1 = (-(1.0 + cos_w0)) / a0
        f.b2 = ((1.0 + cos_w0) / 2.0) / a0
        f.a1 = (-2.0 * cos_w0) / a0
        f.a2 = (1.0 - alpha) / a0
        return f

    @classmethod
    def bandpass(cls, fc, q=2.0, fs=SAMPLE_RATE):
        f = cls()
        w0 = 2.0 * math.pi * fc / fs
        alpha = math.sin(w0) / (2.0 * q)
        cos_w0 = math.cos(w0)
        a0 = 1.0 + alpha
        f.b0 = (alpha) / a0
        f.b1 = 0.0
        f.b2 = (-alpha) / a0
        f.a1 = (-2.0 * cos_w0) / a0
        f.a2 = (1.0 - alpha) / a0
        return f

    def process(self, x):
        y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2
        self.x2 = self.x1
        self.x1 = x
        self.y2 = self.y1
        self.y1 = y
        return y

    def process_all(self, samples):
        return [self.process(s) for s in samples]


def soft_clip(x):
    """Smooth cubic soft clipping saturation."""
    if x > 1.0:
        return 2.0 / 3.0
    elif x < -1.0:
        return -2.0 / 3.0
    return x - (x ** 3) / 3.0


def save_wav(name, samples, normalize_to=0.92, saturate=True):
    """Normalizes and writes assets/audio/<name> as 16-bit PCM; `saturate` puts it through
    soft_clip's gentle cubic curve on the way (the station, footfall and door sounds were tuned
    with it, the jump and console sounds without)."""
    path = AUDIO / name
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(max(abs(s) for s in samples), 1e-6)
    scale = normalize_to / peak
    packed = bytearray()
    for s in samples:
        v = soft_clip(s * scale) if saturate else s * scale
        packed.extend(struct.pack('<h', int(max(-32767, min(32767, v * 32767)))))
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(packed)
    print(f"{name}: {len(samples) / SAMPLE_RATE:.2f} s, peak {peak:.3f}")


def seamless(samples, length, fade_seconds=0.1):
    """The first `length` samples of a sound rendered a little longer, looping cleanly: the overrun
    past `length` is crossfaded into the start, so the loop's end runs straight on into its start."""
    fade = int(SAMPLE_RATE * fade_seconds)
    assert len(samples) >= length + fade
    out = samples[:length]
    for i in range(fade):
        w = i / fade
        out[i] = samples[i] * w + samples[length + i] * (1.0 - w)
    return out


# --- Noise Generators ---

def pink_noise(n, seed=None):
    """Voss-McCartney pink noise."""
    rng = random.Random(seed)
    num_rows = 12
    rows = [0.0] * num_rows
    running_sum = 0.0
    out = [0.0] * n
    for i in range(n):
        k = (i ^ (i - 1)).bit_length() - 1
        if 0 <= k < num_rows:
            running_sum -= rows[k]
            rows[k] = rng.random() * 2.0 - 1.0
            running_sum += rows[k]
        val = running_sum + (rng.random() * 2.0 - 1.0)
        out[i] = val / (num_rows + 1.0)
    return out


# --- Reverb / Corridor Echo ---

def apply_corridor_echo(samples, sample_rate=SAMPLE_RATE, echo_delay_ms=45, feedback=0.35, lp_cutoff=1800, wet=0.6):
    """Simulates hard bulkhead reflections in narrow metallic station corridors."""
    delay_samples = int(sample_rate * (echo_delay_ms / 1000.0))
    buffer = [0.0] * delay_samples
    buf_idx = 0
    lp = Biquad.lowpass(lp_cutoff, q=0.8, fs=sample_rate)
    out = list(samples)
    extra_tail = int(sample_rate * 0.25)
    out.extend([0.0] * extra_tail)

    res = [0.0] * len(out)
    for i in range(len(out)):
        in_s = out[i]
        delayed = buffer[buf_idx]
        filtered_echo = lp.process(delayed)
        buffer[buf_idx] = in_s + filtered_echo * feedback
        buf_idx = (buf_idx + 1) % delay_samples
        res[i] = in_s + filtered_echo * wet
    return res


# =============================================================================
# 1. FLASHLIGHT SWITCH CLICKS (AEROSPACE TACTILE SWITCH)
# =============================================================================

def generate_flashlight_clicks():
    """
    Tactile, sealed helmet-mounted lamp switch (GDD §9.3 & Player lamp toggle).
    Real mechanical switches have a multi-stage acoustic event:
      1. Detent slip: initial high-frequency friction transient (~0-3ms)
      2. Plunger bottom-out: solid mechanical stop against casing (~4-15ms, 850-1400 Hz)
      3. Spring/latch vibration: microscopic spring coil ring-down (~8-25ms)
    """
    duration = 0.08
    n = int(SAMPLE_RATE * duration)

    # 1. LAMP CLICK ON
    samples_on = [0.0] * n
    rng = random.Random(101)

    # Stage 1: Sharp micro-snap (detent release) at t=0ms
    for i in range(min(n, int(SAMPLE_RATE * 0.003))):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 2800.0)
        noise = (rng.random() * 2.0 - 1.0)
        samples_on[i] += noise * env * 1.6

    # Stage 2: Plunger bottom-out impact at t=3.5ms
    impact_start = int(SAMPLE_RATE * 0.0035)
    for i in range(impact_start, n):
        t = (i - impact_start) / SAMPLE_RATE
        env = math.exp(-t * 220.0)
        # Inharmonic casing modes: 880 Hz, 1340 Hz, 2450 Hz, 4100 Hz
        thump = math.sin(2.0 * math.pi * 880.0 * t) * 0.7
        body = math.sin(2.0 * math.pi * 1340.0 * t + 0.4) * 0.5
        snap = math.sin(2.0 * math.pi * 2450.0 * t + 1.1) * 0.35
        clack = math.sin(2.0 * math.pi * 4100.0 * t + 0.2) * 0.2
        samples_on[i] += (thump + body + snap + clack) * env * 1.3

    # Stage 3: Secondary latch click (spring detent seating at t=8.5ms)
    latch_start = int(SAMPLE_RATE * 0.0085)
    for i in range(latch_start, n):
        t = (i - latch_start) / SAMPLE_RATE
        env = math.exp(-t * 310.0)
        latch = math.sin(2.0 * math.pi * 3200.0 * t + 0.8) * 0.35
        samples_on[i] += latch * env

    hp_on = Biquad.highpass(350, q=0.7)
    lp_on = Biquad.lowpass(6800, q=0.8)
    samples_on = hp_on.process_all(samples_on)
    samples_on = lp_on.process_all(samples_on)
    save_wav("player/lamp_click_on.wav", samples_on, normalize_to=0.95)

    # 2. LAMP CLICK OFF (Slightly deeper release latch, softer top-end)
    samples_off = [0.0] * n
    rng_off = random.Random(202)

    # Detent slip
    for i in range(min(n, int(SAMPLE_RATE * 0.003))):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 2400.0)
        samples_off[i] += (rng_off.random() * 2.0 - 1.0) * env * 1.2

    # Plunger release stop at t=3.0ms
    impact_start = int(SAMPLE_RATE * 0.003)
    for i in range(impact_start, n):
        t = (i - impact_start) / SAMPLE_RATE
        env = math.exp(-t * 190.0)
        # Lower casing modes: 720 Hz, 1150 Hz, 1980 Hz
        thump = math.sin(2.0 * math.pi * 720.0 * t) * 0.8
        body = math.sin(2.0 * math.pi * 1150.0 * t + 0.3) * 0.5
        snap = math.sin(2.0 * math.pi * 1980.0 * t + 0.7) * 0.3
        samples_off[i] += (thump + body + snap) * env * 1.2

    # Latch return at t=7.5ms
    latch_start = int(SAMPLE_RATE * 0.0075)
    for i in range(latch_start, n):
        t = (i - latch_start) / SAMPLE_RATE
        env = math.exp(-t * 260.0)
        samples_off[i] += math.sin(2.0 * math.pi * 2650.0 * t + 0.5) * env * 0.3

    hp_off = Biquad.highpass(280, q=0.7)
    lp_off = Biquad.lowpass(5500, q=0.8)
    samples_off = hp_off.process_all(samples_off)
    samples_off = lp_off.process_all(samples_off)
    save_wav("player/lamp_click_off.wav", samples_off, normalize_to=0.92)


# =============================================================================
# 2. FOOTSTEPS & CORRIDOR ECHO (MODAL STEEL DECK FOLEY)
# =============================================================================

def generate_metal_footstep(variant=0, seed=100):
    """
    Heavy spacesuit magnetic boot stepping on modular steel floor grating.
    Acoustic layers:
      1. Sole impact slap: rubber/composite boot lug hitting metal (filtered punch, 15ms)
      2. Plate modal vibration: inharmonic steel plate modes (decay 45-75ms)
      3. Tread scuff: gritty texture of diamond tread friction (35ms)
      4. Corridor slapback echo: reflections off metallic bulkhead walls
    """
    duration = 0.30
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    rng = random.Random(seed + variant * 137)

    # 1. Boot sole impact slap (noise burst + rapid pitch-dropped body)
    slap_dur = int(SAMPLE_RATE * 0.025)
    bp_slap = Biquad.bandpass(1400 + variant * 120, q=1.5)
    for i in range(slap_dur):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 260.0)
        noise = (rng.random() * 2.0 - 1.0) * env
        samples[i] += bp_slap.process(noise) * 1.5

    # Low-end sole punch (weight of suit body: 140 Hz down to 55 Hz in 20ms)
    punch_dur = int(SAMPLE_RATE * 0.06)
    for i in range(punch_dur):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 60.0)
        freq = 140.0 * math.exp(-t * 45.0) + 55.0
        punch = math.sin(2.0 * math.pi * freq * t) * env
        samples[i] += punch * 1.1

    # 2. Inharmonic steel deck plate vibration (dense modes)
    # Fundamental and higher modes of a clamped steel floor tile
    f0 = 175.0 + variant * 14.0 + (rng.random() * 6.0 - 3.0)
    modes = [
        (f0 * 1.00, 0.70, 38.0),   # Fundamental plate flex
        (f0 * 1.85, 0.45, 48.0),   # Cross mode
        (f0 * 2.76, 0.35, 62.0),   # Diagonal mode
        (f0 * 4.12, 0.22, 85.0),   # High modal ping
        (f0 * 6.05, 0.14, 110.0),  # Top edge ping
    ]
    for i in range(n):
        t = i / SAMPLE_RATE
        plate_sig = 0.0
        for freq, amp, damp in modes:
            env = math.exp(-t * damp)
            # Add slight phase jitter
            plate_sig += math.sin(2.0 * math.pi * freq * t + amp) * env * amp
        samples[i] += plate_sig * 0.9

    # 3. Tread scuff / diamond-plate friction
    scuff_start = int(SAMPLE_RATE * 0.008)
    scuff_len = int(SAMPLE_RATE * 0.04)
    bp_scuff = Biquad.bandpass(2400 + variant * 150, q=2.0)
    for i in range(scuff_start, min(n, scuff_start + scuff_len)):
        t = (i - scuff_start) / SAMPLE_RATE
        env = math.sin(t / 0.04 * math.pi)
        noise = (rng.random() * 2.0 - 1.0)
        samples[i] += bp_scuff.process(noise) * env * 0.45

    # Filter shaping
    hp = Biquad.highpass(55, q=0.7)
    lp = Biquad.lowpass(4200, q=0.8)
    samples = hp.process_all(samples)
    samples = lp.process_all(samples)

    # 4. Realistic corridor slapback echo (station hallway reflections)
    echoed = apply_corridor_echo(samples, echo_delay_ms=38 + variant * 5, feedback=0.25, lp_cutoff=1800)
    return echoed


def generate_derelict_footstep(variant=0, seed=500):
    """
    Derelict rusted, gritty floor step.
    More grit crunch, duller decayed metal plate, darker corridor echo.
    """
    duration = 0.32
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    rng = random.Random(seed + variant * 191)

    # Grit / rust crunch
    crunch_len = int(SAMPLE_RATE * 0.055)
    bp_crunch = Biquad.bandpass(1600 + variant * 180, q=1.2)
    for i in range(crunch_len):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 90.0)
        noise = (rng.random() * 2.0 - 1.0)
        if rng.random() > 0.82:
            noise *= 2.2  # flaking rust crunch
        samples[i] += bp_crunch.process(noise) * env * 1.3

    # Heavy dull thump (110 Hz dropping to 45 Hz)
    thump_len = int(SAMPLE_RATE * 0.08)
    for i in range(thump_len):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 42.0)
        freq = 110.0 * math.exp(-t * 35.0) + 45.0
        samples[i] += math.sin(2.0 * math.pi * freq * t) * env * 1.2

    # Degraded, damped steel hollow ring
    f0 = 145.0 + variant * 11.0
    modes = [
        (f0 * 1.00, 0.65, 30.0),
        (f0 * 1.72, 0.35, 42.0),
        (f0 * 2.54, 0.20, 65.0),
    ]
    for i in range(n):
        t = i / SAMPLE_RATE
        sig = 0.0
        for freq, amp, damp in modes:
            sig += math.sin(2.0 * math.pi * freq * t) * math.exp(-t * damp) * amp
        samples[i] += sig * 0.7

    hp = Biquad.highpass(45, q=0.7)
    lp = Biquad.lowpass(3200, q=0.7)
    samples = hp.process_all(samples)
    samples = lp.process_all(samples)

    echoed = apply_corridor_echo(samples, echo_delay_ms=52 + variant * 7, feedback=0.30, lp_cutoff=1300)
    return echoed


def generate_jump_land():
    """Heavy two-boot landing on steel deck with deep hull reverberation."""
    duration = 0.45
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    rng = random.Random(999)

    # Staggered dual foot strikes: 0ms and 16ms
    bp_slap = Biquad.bandpass(1300, q=1.4)
    for offset_ms in (0, 16):
        offset = int(SAMPLE_RATE * (offset_ms / 1000.0))
        for i in range(min(n - offset, int(SAMPLE_RATE * 0.035))):
            t = i / SAMPLE_RATE
            env = math.exp(-t * 210.0)
            noise = (rng.random() * 2.0 - 1.0) * env
            samples[offset + i] += bp_slap.process(noise) * 1.4

    # Heavy hull structural thump
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 22.0)
        pitch = 95.0 * math.exp(-t * 18.0) + 36.0
        hull = math.sin(2.0 * math.pi * pitch * t) * env * 1.4
        plate = math.sin(2.0 * math.pi * 160.0 * t) * math.exp(-t * 24.0) * 0.7
        sub = math.sin(2.0 * math.pi * 65.0 * t) * math.exp(-t * 16.0) * 0.8
        samples[i] += hull + plate + sub

    hp = Biquad.highpass(35, q=0.7)
    lp = Biquad.lowpass(2800, q=0.8)
    samples = hp.process_all(samples)
    samples = lp.process_all(samples)
    echoed = apply_corridor_echo(samples, echo_delay_ms=48, feedback=0.35, lp_cutoff=1400)
    save_wav("foley/step_land.wav", echoed, normalize_to=0.96)


def generate_all_footsteps():
    for i in range(4):
        s = generate_metal_footstep(variant=i)
        save_wav(f"foley/step_metal_0{i+1}.wav", s, normalize_to=0.92)
    for i in range(4):
        s = generate_derelict_footstep(variant=i)
        save_wav(f"foley/step_derelict_0{i+1}.wav", s, normalize_to=0.90)
    generate_jump_land()


# =============================================================================
# 3. BULKHEAD SLIDING DOORS (MOTOR & INTERLOCK)
# =============================================================================

def generate_door_sounds():
    """
    Motorized sliding bulkhead doors (game/station/door.gd):
    - Door Open: Solenoid latch release click + pneumatic pressure puff + electric servo motor
      slide + soft mechanical stop cushion (~0.52s)
    - Door Close: Electric servo motor slide + heavy metallic bulkhead slam (~0.58s)
    """
    # 1. DOOR OPEN (0.55s)
    # High-pressure pneumatic unlatch blast, heavy steel track slide rumble, pocket buffer stop
    dur_open = 0.55
    n_open = int(SAMPLE_RATE * dur_open)
    samples_open = [0.0] * n_open
    noise_open = pink_noise(n_open, seed=701)

    # Initial unlatch & pneumatic exhaust burst (0 to 65ms)
    bp_burst = Biquad.bandpass(1450, q=1.1)
    bp_hiss = Biquad.bandpass(2800, q=1.5)
    for i in range(min(n_open, int(SAMPLE_RATE * 0.08))):
        t = i / SAMPLE_RATE
        env_blast = math.exp(-t * 70.0)
        # Solenoid pin release transient
        pin = math.sin(2.0 * math.pi * 920.0 * t) * math.exp(-t * 300.0) * 1.2
        pin += math.sin(2.0 * math.pi * 2150.0 * t) * math.exp(-t * 450.0) * 0.8
        # Pneumatic valve blast
        blast = (bp_burst.process(noise_open[i]) * 1.8 + bp_hiss.process(noise_open[i]) * 0.9) * env_blast
        # Low hull thud from pressure unseal
        thud = math.sin(2.0 * math.pi * 85.0 * t) * math.exp(-t * 90.0) * 1.4
        samples_open[i] += pin + blast + thud

    # Heavy track slide & steel grinding mass (0.025s to 0.49s)
    slide_start = int(SAMPLE_RATE * 0.025)
    slide_end = int(SAMPLE_RATE * 0.49)
    bp_track_low = Biquad.bandpass(140, q=1.6)
    bp_track_mid = Biquad.bandpass(480, q=2.0)
    bp_track_grit = Biquad.bandpass(1100, q=1.8)
    bp_air_piston = Biquad.bandpass(2200, q=1.4)

    for i in range(slide_start, slide_end):
        t = (i - slide_start) / SAMPLE_RATE
        dur_slide = (slide_end - slide_start) / SAMPLE_RATE
        norm_t = t / dur_slide

        env = math.sin(norm_t * math.pi) ** 0.85
        raw = noise_open[i]

        # Heavy physical mass rumble (saturated harmonics)
        f_rumble = 72.0 + 15.0 * math.sin(norm_t * math.pi)
        rumble = (
            math.sin(2.0 * math.pi * f_rumble * t) * 0.65 +
            math.sin(2.0 * math.pi * (f_rumble * 2.0) * t + 0.4) * 0.35 +
            math.sin(2.0 * math.pi * (f_rumble * 3.0) * t + 1.1) * 0.18
        )
        rumble = math.tanh(rumble * 1.4) * 0.9

        # Gritty steel rail friction with stick-slip chatter
        chatter = 1.0 + 0.25 * math.sin(2.0 * math.pi * 55.0 * t)
        friction = (
            bp_track_low.process(raw) * 0.9 +
            bp_track_mid.process(raw) * 0.75 +
            bp_track_grit.process(raw) * 0.45
        ) * chatter

        # Pneumatic actuator push hiss
        piston = bp_air_piston.process(raw) * 0.45 * (1.0 - norm_t * 0.4)

        samples_open[i] += (rumble + friction + piston) * env * 1.25

    # Into its pocket: the leaves meet their buffers, a dull thunk.
    _thunk(samples_open, 0.48, 705, weight=1.1, gain=0.9)

    hp_open = Biquad.highpass(45, q=0.7)
    lp_open = Biquad.lowpass(4600, q=0.8)
    samples_open = hp_open.process_all(samples_open)
    samples_open = lp_open.process_all(samples_open)
    samples_open = apply_corridor_echo(samples_open, echo_delay_ms=42, feedback=0.22, lp_cutoff=1600)
    save_wav("foley/door_open.wav", samples_open, normalize_to=0.94)

    # 2. DOOR CLOSE (0.58s)
    # Heavy sliding mass, then the steel bulkhead's impact
    dur_close = 0.58
    n_close = int(SAMPLE_RATE * dur_close)
    samples_close = [0.0] * n_close
    noise_close = pink_noise(n_close, seed=902)

    # Closing track slide & pneumatic actuator (0.0s to 0.47s)
    slide_len = int(SAMPLE_RATE * 0.47)
    bp_c_low = Biquad.bandpass(130, q=1.5)
    bp_c_mid = Biquad.bandpass(440, q=1.8)
    bp_c_grit = Biquad.bandpass(980, q=2.0)
    bp_c_air = Biquad.bandpass(1950, q=1.3)

    for i in range(slide_len):
        t = i / SAMPLE_RATE
        norm_t = t / 0.47
        env = math.sin(norm_t * math.pi) ** 0.9
        raw = noise_close[i]

        f_rumble = 80.0 - 12.0 * norm_t
        rumble = (
            math.sin(2.0 * math.pi * f_rumble * t) * 0.65 +
            math.sin(2.0 * math.pi * (f_rumble * 2.0) * t + 0.3) * 0.32 +
            math.sin(2.0 * math.pi * (f_rumble * 3.0) * t + 0.8) * 0.16
        )
        rumble = math.tanh(rumble * 1.5) * 0.85

        friction = (
            bp_c_low.process(raw) * 0.85 +
            bp_c_mid.process(raw) * 0.70 +
            bp_c_grit.process(raw) * 0.40
        )
        whoosh = bp_c_air.process(raw) * 0.50 * (0.6 + 0.4 * norm_t)

        samples_close[i] += (rumble + friction + whoosh) * env * 1.15

    # The leaves meet: heavy, dull, the gasket sighing as it seals.
    _thunk(samples_close, 0.465, 905, weight=1.7, gain=1.5, seal=0.8)

    hp_close = Biquad.highpass(40, q=0.7)
    lp_close = Biquad.lowpass(4800, q=0.8)
    samples_close = hp_close.process_all(samples_close)
    samples_close = lp_close.process_all(samples_close)
    samples_close = apply_corridor_echo(samples_close, echo_delay_ms=38, feedback=0.25, lp_cutoff=1700)
    save_wav("foley/door_close.wav", samples_close, normalize_to=0.96)


# =============================================================================
# 4. AMBIENT NOISE (STATION HUM & DERELICT DRONE)
# =============================================================================

def generate_station_hum():
    """
    GDD §15: 'The station hum is a comfort, and its absence is a warning.'
    An 8 s loop:
    - Reactor core sub-bass fundamental (42 Hz)
    - 60 Hz electrical mains hum with 120/180/240 Hz transformer buzz and phase beating
    - HVAC air handling airflow: STEADY, NON-CYCLIC continuous gentle air wash
      (no breathing LFO modulation, so it doesn't sound like cyclic breathing).
    """
    length = int(SAMPLE_RATE * LOOP_SECONDS)
    n = length + SAMPLE_RATE  # rendered on past the loop, to crossfade back into its start
    samples = [0.0] * n
    noise = pink_noise(n, seed=999)

    # Smooth, steady HVAC broadband air filters
    bp_air = Biquad.bandpass(320, q=0.9)
    lp_air = Biquad.lowpass(650, q=0.6)

    for i in range(n):
        t = i / SAMPLE_RATE

        # 1. Sub-bass drive core drone (42 Hz + 84 Hz)
        core = (
            0.52 * math.sin(2.0 * math.pi * 42.0 * t) +
            0.28 * math.sin(2.0 * math.pi * 84.0 * t + 0.5) +
            0.12 * math.sin(2.0 * math.pi * 126.0 * t + 1.2)
        )

        # 2. Electrical mains transformer buzz (60 Hz fundamental + harmonics + beat)
        elec = (
            0.34 * math.sin(2.0 * math.pi * 60.0 * t) +
            0.20 * math.sin(2.0 * math.pi * 60.25 * t + 0.3) +
            0.18 * math.sin(2.0 * math.pi * 120.0 * t + 0.8) +
            0.09 * math.sin(2.0 * math.pi * 180.0 * t + 1.7) +
            0.04 * math.sin(2.0 * math.pi * 240.0 * t + 2.1)
        )

        # 3. Life-support HVAC ventilation: STEADY, completely non-cyclic air wash
        air_filtered = lp_air.process(bp_air.process(noise[i])) * 0.70

        samples[i] = (core * 0.75 + elec * 0.65 + air_filtered * 0.45)

    hp = Biquad.highpass(30, q=0.7)
    samples = hp.process_all(samples)

    save_wav("ambient/station_hum.wav", seamless(samples, length), normalize_to=0.82)


def generate_derelict_ambience():
    """
    Derelict ambient drone:
    Cold, sparse, hollow, dissonant sub-rumble (44 Hz and minor third 52.25 Hz),
    eerie cold air draft, distant structural stress resonance.
    """
    length = int(SAMPLE_RATE * LOOP_SECONDS)
    n = length + SAMPLE_RATE
    samples = [0.0] * n
    noise = pink_noise(n, seed=333)

    bp_hollow = Biquad.bandpass(750, q=2.8)
    bp_hiss = Biquad.bandpass(2100, q=2.0)

    for i in range(n):
        t = i / SAMPLE_RATE

        # 1. Dissonant eerie drone (minor interval)
        drone = (
            0.42 * math.sin(2.0 * math.pi * 44.0 * t) +
            0.32 * math.sin(2.0 * math.pi * 52.25 * t + 0.4) +
            0.16 * math.sin(2.0 * math.pi * 88.0 * t + 1.1) +
            0.08 * math.sin(2.0 * math.pi * 176.0 * t + 2.3)
        )

        # 2. Hollow cold draft
        lfo = 0.7 + 0.3 * math.sin(2.0 * math.pi * 0.25 * t)
        hollow = bp_hollow.process(noise[i]) * 0.6 * lfo
        hiss = bp_hiss.process(noise[i]) * 0.22 * (0.8 + 0.2 * math.cos(2.0 * math.pi * 0.125 * t))

        # 3. Distant metallic hull resonance ping (at t = 2.4s and t = 6.2s)
        ping = 0.0
        for pt in (2.4, 6.2):
            if pt <= t < pt + 1.2:
                dt = t - pt
                env = math.exp(-dt * 4.5)
                ping += math.sin(2.0 * math.pi * 890.0 * dt) * env * 0.15

        samples[i] = (drone * 0.65 + hollow * 0.55 + hiss * 0.35 + ping)

    hp = Biquad.highpass(35, q=0.7)
    samples = hp.process_all(samples)

    save_wav("ambient/derelict_ambience.wav", seamless(samples, length), normalize_to=0.80)


# =============================================================================
# 5. THE JUMP (Run: SPOOL 3 s, the tunnel, ARRIVAL 2 s)
# =============================================================================

def generate_jump_spool():
    """
    jump_spool.wav (3.0s):
    Drive reactor spooling up to hyperspace transit (matches SPOOL = 3.0s):
    - Sub-bass structural reactor pulse (40 Hz -> 75 Hz) that shakes the deck
    - Rising high-energy turbine charge whine (120 Hz -> 880 Hz with harmonics)
    - 3 retro bridge klaxon alert pulses (650 Hz / 820 Hz dual-tone) warning the crew
    """
    duration = 3.1
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    noise = pink_noise(n, seed=42)

    bp_air = Biquad.bandpass(1400, q=1.2)

    for i in range(n):
        t = i / SAMPLE_RATE
        norm_t = min(1.0, t / 3.0)

        # 1. Rising reactor turbine whine
        # Sweeps upwards with exponential pitch curve: 120 Hz -> 840 Hz
        f_turbine = 120.0 + 720.0 * (norm_t ** 2.2)
        whine_amp = norm_t ** 1.3
        whine = (
            math.sin(2.0 * math.pi * f_turbine * t) * 0.65 +
            math.sin(2.0 * math.pi * (f_turbine * 2.0) * t + 0.3) * 0.30 +
            math.sin(2.0 * math.pi * (f_turbine * 3.0) * t + 0.8) * 0.15
        ) * whine_amp

        # 2. Deep structural sub-bass deck shudder
        f_sub = 42.0 + 35.0 * norm_t
        # Pulsing deck vibration (shudder amplitude pulses faster as jump nears)
        pulse_hz = 4.0 + 12.0 * norm_t
        pulse = 0.8 + 0.2 * math.sin(2.0 * math.pi * pulse_hz * t)
        sub = math.sin(2.0 * math.pi * f_sub * t) * (0.6 + 0.8 * norm_t) * pulse
        sub = math.tanh(sub * 1.5) * 0.9

        # 3. Cooling venting air rush
        air = bp_air.process(noise[i]) * 0.35 * (norm_t ** 1.5)

        # 4. Rhythmic bridge alarm pulses at t = 0.4s, 1.3s, 2.2s
        alarm = 0.0
        for alarm_t in (0.4, 1.3, 2.2):
            if alarm_t <= t < alarm_t + 0.35:
                dt = t - alarm_t
                env_al = math.sin(dt / 0.35 * math.pi) ** 1.5
                beep = (
                    math.sin(2.0 * math.pi * 680.0 * dt) * 0.6 +
                    math.sin(2.0 * math.pi * 840.0 * dt) * 0.4
                )
                alarm += beep * env_al * 0.55

        samples[i] = whine + sub + air + alarm

    hp = Biquad.highpass(35, q=0.7)
    lp = Biquad.lowpass(4200, q=0.8)
    samples = hp.process_all(samples)
    samples = lp.process_all(samples)
    save_wav("ambient/jump_spool.wav", samples, normalize_to=0.94, saturate=False)


def generate_jump_enter():
    """
    jump_enter.wav (1.8s):
    The explosive gravitational rupture when the station breaches the continuum into hyperspace:
    - Massive 38 Hz sub-bass hull boom
    - Tachyon arc discharge crackle
    - Tunnel sonic displacement rush
    """
    duration = 1.8
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    noise = pink_noise(n, seed=888)
    rng = random.Random(999)

    bp_flash = Biquad.bandpass(1650, q=2.0)
    bp_wash = Biquad.bandpass(550, q=1.5)

    for i in range(n):
        t = i / SAMPLE_RATE

        # 1. Explosive continuum rupture boom (sub-bass punch)
        boom_env = math.exp(-t * 3.8)
        f_boom = 68.0 * math.exp(-t * 4.5) + 38.0
        boom = math.sin(2.0 * math.pi * f_boom * t) * boom_env * 1.8
        boom = math.tanh(boom * 1.6)

        # 2. Tachyon arc crackle (0 to 180ms)
        arc = 0.0
        if t < 0.25:
            arc_env = math.exp(-t * 22.0)
            raw = (rng.random() * 2.0 - 1.0)
            arc = bp_flash.process(raw) * arc_env * 1.5

        # 3. Tunnel displacement wash
        wash_env = math.sin(min(1.0, t / 0.4) * math.pi * 0.5) * math.exp(-t * 2.2)
        wash = bp_wash.process(noise[i]) * wash_env * 1.2

        samples[i] = boom + arc + wash

    hp = Biquad.highpass(30, q=0.7)
    lp = Biquad.lowpass(3800, q=0.8)
    samples = hp.process_all(samples)
    samples = lp.process_all(samples)
    samples = apply_corridor_echo(samples, echo_delay_ms=65, feedback=0.35, lp_cutoff=1400, wet=0.55)
    save_wav("ambient/jump_enter.wav", samples, normalize_to=0.96, saturate=False)


def generate_hyperspace_loop():
    """
    hyperspace_loop.wav (a 7 s loop: two whole swells of the 3.5 s wave):
    Dark, immersive, non-tonal hyperspace continuum slipstream:
    - Relativistic spatial slipstream wash (wideband turbulent airflow outside hull)
    - Sub-space cavitation waves with slow 3.5s phase sweep
    - Heavy drive core structural sub-rumble (44 Hz / 88 Hz) under maximum load
    """
    length = int(SAMPLE_RATE * HYPERSPACE_SECONDS)
    n = length + SAMPLE_RATE
    samples = [0.0] * n
    noise = pink_noise(n, seed=512)

    bp_stream_low = Biquad.bandpass(280, q=1.2)
    bp_stream_mid = Biquad.bandpass(620, q=1.6)
    bp_stream_high = Biquad.bandpass(1450, q=2.0)
    lp_rumble = Biquad.lowpass(95, q=0.8)

    for i in range(n):
        t = i / SAMPLE_RATE

        # 1. Heavy drive core structural sub-bass rumble
        # Low frequency reactor load pushing through hyperspace
        drive = (
            math.sin(2.0 * math.pi * 44.0 * t) * 0.70 +
            math.sin(2.0 * math.pi * 88.0 * t + 0.5) * 0.35 +
            math.sin(2.0 * math.pi * 132.0 * t + 1.1) * 0.15
        )
        drive = math.tanh(drive * 1.6) * 0.85

        # 2. Relativistic slipstream wash - slow undulating wave (period 3.5s)
        wave_lfo = 0.75 + 0.25 * math.sin(2.0 * math.pi * (1.0 / 3.5) * t)
        raw = noise[i]
        stream_body = bp_stream_low.process(raw) * 0.85 * wave_lfo
        stream_air = bp_stream_mid.process(raw) * 0.55 * (1.2 - 0.2 * wave_lfo)
        stream_hiss = bp_stream_high.process(raw) * 0.25

        # 3. Deep turbulent hull roar
        hull_roar = lp_rumble.process(raw) * 1.1

        samples[i] = drive * 0.55 + stream_body * 0.60 + stream_air * 0.45 + stream_hiss * 0.30 + hull_roar * 0.50

    hp = Biquad.highpass(32, q=0.7)
    lp = Biquad.lowpass(3600, q=0.8)
    samples = hp.process_all(samples)
    samples = lp.process_all(samples)

    save_wav("ambient/hyperspace_loop.wav", seamless(samples, length, 0.15), normalize_to=0.86, saturate=False)


def generate_jump_exit():
    """
    jump_exit.wav (2.2s):
    Exiting hyperspace into the destination star system (matches ARRIVAL = 2.0s):
    - Deceleration snapback shockwave / dimensional cavitation boom
    - Reactor turbine pitch wind-down (sweeping down: 750 Hz -> 55 Hz)
    - Re-entry pressure stabilization hiss
    """
    duration = 2.2
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    noise = pink_noise(n, seed=77)

    bp_hiss = Biquad.bandpass(1850, q=1.5)

    for i in range(n):
        t = i / SAMPLE_RATE

        # 1. Deceleration shockwave boom (at t=0s)
        boom_env = math.exp(-t * 4.2)
        f_boom = 85.0 * math.exp(-t * 3.5) + 45.0
        boom = math.sin(2.0 * math.pi * f_boom * t) * boom_env * 1.7
        boom = math.tanh(boom * 1.5)

        # 2. Descending turbine wind-down
        norm_t = min(1.0, t / 2.0)
        f_turbine = 750.0 * ((1.0 - norm_t) ** 2.0) + 55.0
        decay_env = (1.0 - norm_t) ** 1.2
        turbine = (
            math.sin(2.0 * math.pi * f_turbine * t) * 0.50 +
            math.sin(2.0 * math.pi * (f_turbine * 2.0) * t + 0.4) * 0.25
        ) * decay_env

        # 3. Equalization hiss
        hiss_env = math.exp(-t * 2.8)
        hiss = bp_hiss.process(noise[i]) * hiss_env * 0.65

        samples[i] = boom + turbine + hiss

    hp = Biquad.highpass(35, q=0.7)
    lp = Biquad.lowpass(4000, q=0.8)
    samples = hp.process_all(samples)
    samples = lp.process_all(samples)
    samples = apply_corridor_echo(samples, echo_delay_ms=48, feedback=0.28, lp_cutoff=1500, wet=0.55)
    save_wav("ambient/jump_exit.wav", samples, normalize_to=0.95, saturate=False)


# =============================================================================
# 6. CONSOLES, THE FUEL RACK, TAKING THINGS
# =============================================================================

def generate_terminal_sounds():
    """
    Retro 1979 CRT Terminal & Console UI sounds:
    - terminal_click.wav: Tactile mechanical key click / phosphor blip (input feedback)
    - terminal_beep.wav: Dual-tone CRT confirmation chirp (valid selection / scan plotted)
    - terminal_error.wav: Low blunt warning denial buzz (blocked action / error)
    """
    # 1. TERMINAL CLICK (45ms) - vintage computer relay click & subtle 2.8kHz CRT blip
    dur_click = 0.045
    n_click = int(SAMPLE_RATE * dur_click)
    samples_click = [0.0] * n_click
    rng = random.Random(77)

    for i in range(n_click):
        t = i / SAMPLE_RATE
        # Key switch tactile snap
        env_snap = math.exp(-t * 400.0)
        noise = (rng.random() * 2.0 - 1.0) * env_snap
        # Phosphor screen capacitive blip
        blip = math.sin(2.0 * math.pi * 2800.0 * t) * math.exp(-t * 250.0) * 0.4
        samples_click[i] = noise * 0.7 + blip

    hp_tc = Biquad.highpass(350, q=0.7)
    samples_click = hp_tc.process_all(samples_click)
    save_wav("foley/terminal_click.wav", samples_click, normalize_to=0.82, saturate=False)

    # 2. TERMINAL BEEP (160ms) - dual-tone CRT confirmation chirp (880 Hz -> 1760 Hz)
    dur_beep = 0.16
    n_beep = int(SAMPLE_RATE * dur_beep)
    samples_beep = [0.0] * n_beep

    for i in range(n_beep):
        t = i / SAMPLE_RATE
        # First blip (880 Hz for 60ms)
        if t < 0.07:
            env1 = math.sin(t / 0.07 * math.pi) ** 1.2
            samples_beep[i] = (
                math.sin(2.0 * math.pi * 880.0 * t) * 0.7 +
                math.sin(2.0 * math.pi * 1760.0 * t) * 0.2
            ) * env1
        # Second blip (1760 Hz for 80ms)
        elif t >= 0.075:
            dt = t - 0.075
            env2 = math.exp(-dt * 30.0)
            samples_beep[i] = (
                math.sin(2.0 * math.pi * 1760.0 * dt) * 0.7 +
                math.sin(2.0 * math.pi * 3520.0 * dt) * 0.2
            ) * env2

    save_wav("foley/terminal_beep.wav", samples_beep, normalize_to=0.78, saturate=False)

    # 3. TERMINAL ERROR (200ms) - low blunt double-boop (190 Hz square blip)
    dur_err = 0.20
    n_err = int(SAMPLE_RATE * dur_err)
    samples_err = [0.0] * n_err

    for i in range(n_err):
        t = i / SAMPLE_RATE
        # Double buzz at t=0 and t=0.09s
        for bt in (0.0, 0.09):
            if bt <= t < bt + 0.07:
                dt = t - bt
                env = math.sin(dt / 0.07 * math.pi) ** 1.4
                # Saturated low square wave
                buzz = math.sin(2.0 * math.pi * 185.0 * dt) * 1.5
                buzz = math.tanh(buzz) * 0.85
                samples_err[i] += buzz * env

    save_wav("foley/terminal_error.wav", samples_err, normalize_to=0.85, saturate=False)


def generate_fuel_cell_load():
    """
    fuel_cell_load.wav (0.55s):
    Loading a heavy fuel cell into a drive rack bay:
    - Guide rail slide friction
    - Heavy pneumatic locking clamp snap
    - Electrical bus engagement buzz
    """
    duration = 0.55
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    noise = pink_noise(n, seed=314)

    bp_slide = Biquad.bandpass(520, q=1.8)
    bp_clamp = Biquad.bandpass(1650, q=2.0)

    # 1. Slide into slot (0.0s to 0.25s)
    for i in range(int(SAMPLE_RATE * 0.28)):
        t = i / SAMPLE_RATE
        norm_t = t / 0.28
        env = math.sin(norm_t * math.pi) ** 1.2
        slide = bp_slide.process(noise[i]) * env * 0.9
        samples[i] += slide

    # 2. Heavy mechanical seat & latch clamp (at t=0.26s)
    latch_start = int(SAMPLE_RATE * 0.26)
    for i in range(latch_start, n):
        t = (i - latch_start) / SAMPLE_RATE
        snap_env = math.exp(-t * 120.0)
        snap = bp_clamp.process(noise[i]) * snap_env * 1.8
        thump_env = math.exp(-t * 40.0)
        thump = math.sin(2.0 * math.pi * 72.0 * t) * thump_env * 1.4
        # Electrical power coupling hum
        elec = math.sin(2.0 * math.pi * 120.0 * t) * math.exp(-t * 15.0) * 0.4
        samples[i] += snap + thump + elec

    hp = Biquad.highpass(45, q=0.7)
    lp = Biquad.lowpass(4200, q=0.8)
    samples = hp.process_all(samples)
    samples = lp.process_all(samples)
    samples = apply_corridor_echo(samples, echo_delay_ms=40, feedback=0.25, lp_cutoff=1700, wet=0.55)
    save_wav("foley/fuel_cell_load.wav", samples, normalize_to=0.92, saturate=False)


def generate_item_pickup():
    """
    item_pickup.wav (0.12s):
    Tactile utility belt strap clip / metallic gear grab when taking an item into hands/belt.
    """
    duration = 0.12
    n = int(SAMPLE_RATE * duration)
    samples = [0.0] * n
    rng = random.Random(222)

    bp_clink = Biquad.bandpass(2400, q=3.0)
    bp_cloth = Biquad.bandpass(850, q=1.5)

    for i in range(n):
        t = i / SAMPLE_RATE
        # Leather/cloth strap rustle
        env_cloth = math.exp(-t * 45.0)
        cloth = bp_cloth.process(rng.random() * 2.0 - 1.0) * env_cloth * 0.7
        # Metallic buckle snap (at t=15ms)
        clink = 0.0
        if t >= 0.015:
            dt = t - 0.015
            env_clink = math.exp(-dt * 180.0)
            clink = bp_clink.process(rng.random() * 2.0 - 1.0) * env_clink * 1.2
            clink += math.sin(2.0 * math.pi * 3200.0 * dt) * env_clink * 0.4
        samples[i] = cloth + clink

    hp = Biquad.highpass(200, q=0.7)
    samples = hp.process_all(samples)
    save_wav("foley/item_pickup.wav", samples, normalize_to=0.80, saturate=False)


# =============================================================================
# DOCKING AND THE AIRLOCK
# =============================================================================

def _thunk(samples, start, seed, weight=1.0, gain=1.0, seal=0.0):
    """A heavy part meeting its stop at `start` seconds, felt more than heard: a dull knock (noise,
    a few milliseconds, low-passed) rung through a few low resonances fed by that noise, not pure
    tones, so it has weight and no pitch, and nothing rings on after it (a ringing sine read as a
    clang, not metal meeting metal). `weight` lowers it (2 is twice as heavy); `seal` adds the
    short sigh of air pushed out of a gasket as it closes."""
    rng = random.Random(seed)
    first = int(SAMPLE_RATE * start)
    n = min(len(samples) - first, int(SAMPLE_RATE * 0.3))
    knock_lp = Biquad.lowpass(900 / weight ** 0.5, q=0.7)
    bands = [(Biquad.bandpass(55 / weight, q=2.0), 1.0), (Biquad.bandpass(110 / weight, q=3.0), 0.7),
             (Biquad.bandpass(230 / weight, q=3.5), 0.4)]
    air_bp = Biquad.bandpass(700, q=0.8)
    for k in range(n):
        t = k / SAMPLE_RATE
        knock = knock_lp.process(rng.random() * 2.0 - 1.0) * math.exp(-t * 400.0)
        body = sum(bp.process(knock) * w for bp, w in bands) * 7.0
        air = air_bp.process(rng.random() * 2.0 - 1.0) * seal * math.exp(-t * 30.0) * min(1.0, t / 0.004) * 0.5
        samples[first + k] += (body + knock * 0.4 + air) * gain


def _creak(samples, start, length, noise, seed, low=62.0, high=48.0, gain=1.0):
    """A heavy hinge turning under load for `length` seconds: a groaning tone sliding from `low`
    to `high` Hz, roughened by stick-slip chatter."""
    rng = random.Random(seed)
    first = int(SAMPLE_RATE * start)
    n = int(SAMPLE_RATE * length)
    bp_grit = Biquad.bandpass(900, q=2.5)
    bp_body = Biquad.bandpass(240, q=1.4)
    phase = 0.0
    slip = 0.0
    for k in range(n):
        i = first + k
        if i >= len(samples):
            break
        u = k / n
        env = math.sin(u * math.pi) ** 0.6
        f = low + (high - low) * u + 4.0 * math.sin(2.0 * math.pi * 1.7 * u)
        phase += 2.0 * math.pi * f / SAMPLE_RATE
        groan = math.tanh(math.sin(phase) * 2.2 + math.sin(phase * 2.0 + 0.4) * 0.8) * 0.6
        if rng.random() < 26.0 / SAMPLE_RATE:
            slip = 1.0
        slip *= 0.9985
        grit = bp_grit.process(noise[i]) * (0.25 + slip * 0.9)
        body = bp_body.process(noise[i]) * 0.5
        samples[i] += (groan * 0.7 + grit + body) * env * gain


def generate_hatch_sounds():
    """
    A round pressure hatch (game/station/hatch.gd), swinging on its hinge:
    - hatch_open (2.4 s): four locking dogs ratchet back, the seal breaks with a short hiss, the
      hatch groans round on its hinge and stops against its catch.
    - hatch_close (2.1 s): it groans shut, seats with a heavy thud, and the dogs drive home.
    """
    n = int(SAMPLE_RATE * 2.4)
    samples = [0.0] * n
    noise = pink_noise(n, seed=1201)
    for k, at in enumerate((0.05, 0.19, 0.33, 0.47)):
        _thunk(samples, at, 1210 + k, weight=0.7, gain=1.8)
    bp_hiss = Biquad.bandpass(3200, q=1.2)
    for i in range(int(SAMPLE_RATE * 0.58), int(SAMPLE_RATE * 0.95)):
        t = i / SAMPLE_RATE - 0.58
        samples[i] += bp_hiss.process(noise[i]) * math.exp(-t * 9.0) * 1.1
    _creak(samples, 0.7, 1.45, noise, 77, low=66.0, high=50.0, gain=0.9)
    _thunk(samples, 2.12, 1215, weight=1.6, gain=2.6)
    samples = Biquad.highpass(40, q=0.7).process_all(samples)
    samples = Biquad.lowpass(4400, q=0.8).process_all(samples)
    samples = apply_corridor_echo(samples, echo_delay_ms=52, feedback=0.3, lp_cutoff=1500)
    save_wav("foley/hatch_open.wav", samples, normalize_to=0.94)

    n = int(SAMPLE_RATE * 2.1)
    samples = [0.0] * n
    noise = pink_noise(n, seed=1202)
    _creak(samples, 0.0, 1.25, noise, 78, low=52.0, high=64.0, gain=0.9)
    _thunk(samples, 1.2, 1216, weight=1.8, gain=1.4, seal=1.0)
    for k, at in enumerate((1.42, 1.55, 1.68, 1.81)):
        _thunk(samples, at, 1220 + k, weight=0.7, gain=1.6)
    samples = Biquad.highpass(38, q=0.7).process_all(samples)
    samples = Biquad.lowpass(4400, q=0.8).process_all(samples)
    samples = apply_corridor_echo(samples, echo_delay_ms=52, feedback=0.3, lp_cutoff=1500)
    save_wav("foley/hatch_close.wav", samples, normalize_to=0.95)


def generate_airlock_sounds():
    """
    The collar's airlock cycling (game/station/airlock.gd):
    - airlock_vent (4.5 s): the chamber dumps its air: a roaring hiss that thins and falls in pitch
      as the pressure goes, the dump valve rumbling under it, a thin whistle at the end.
    - airlock_fill (4.5 s): air floods back in: a hiss that swells and steadies, then the valve
      shuts with a clunk as the chamber reaches pressure.
    """
    for name, filling, seed in (("airlock_vent", False, 1301), ("airlock_fill", True, 1302)):
        n = int(SAMPLE_RATE * 4.5)
        samples = [0.0] * n
        noise = pink_noise(n, seed=seed)
        white = random.Random(seed)
        lows = [Biquad.bandpass(f, q=1.2) for f in (900, 1600, 2600)]
        rumble = Biquad.lowpass(110, q=0.9)
        for i in range(n):
            t = i / SAMPLE_RATE
            u = t / 4.5
            if filling:
                level = min(1.0, t / 0.35) * (1.0 - 0.35 * u) * (1.0 if t < 4.05 else math.exp(-(t - 4.05) * 30.0))
                bright = 0.6 + 0.4 * u
            else:
                level = min(1.0, t / 0.08) * math.exp(-t * 0.75)
                bright = 1.0 - 0.7 * u
            w = white.random() * 2.0 - 1.0
            hiss = (lows[0].process(w) * (1.2 - bright * 0.6) + lows[1].process(w) * 0.9 + lows[2].process(w) * bright * 0.9)
            valve = rumble.process(noise[i]) * 2.2 * level
            flutter = 1.0 + 0.12 * math.sin(2.0 * math.pi * 7.3 * t) * level
            samples[i] = (hiss * flutter * 1.4 + valve) * level
            if not filling and 3.0 < t:
                samples[i] += math.sin(2.0 * math.pi * (1900.0 - 300.0 * (t - 3.0)) * t) * 0.05 * math.sin((t - 3.0) / 1.5 * math.pi)
        if filling:
            _thunk(samples, 4.06, 1310, weight=0.9, gain=0.7)
        samples = Biquad.highpass(45, q=0.7).process_all(samples)
        samples = Biquad.lowpass(5200, q=0.8).process_all(samples)
        samples = apply_corridor_echo(samples, echo_delay_ms=48, feedback=0.25, lp_cutoff=1700, wet=0.45)
        save_wav(f"foley/{name}.wav", samples, normalize_to=0.9, saturate=False)


def generate_dock_sounds():
    """
    Docking (game/station/collar.gd):
    - dock_contact (3.2 s): two hulls meet: a crunch, a deep boom through the frame, the plates
      ringing, then the structure groaning as it settles.
    - dock_clamps (1.9 s): four hydraulic clamps bite one after another: a hiss, then a clunk.
    - collar_motor (3.0 s): the collar running out or in: a geared servo whining up, steady, and
      winding down, a hydraulic hiss under it, a stop at each end.
    """
    n = int(SAMPLE_RATE * 3.2)
    samples = [0.0] * n
    noise = pink_noise(n, seed=1401)
    bp_crunch = Biquad.bandpass(700, q=1.0)
    for i in range(n):
        t = i / SAMPLE_RATE
        crunch = bp_crunch.process(noise[i]) * math.exp(-t * 22.0) * 2.0
        boom = (math.sin(2.0 * math.pi * 36.0 * t) * 1.6 + math.sin(2.0 * math.pi * 54.0 * t + 0.5) * 1.0) * math.exp(-t * 2.2)
        plates = sum(math.sin(2.0 * math.pi * f * t + f) * a * math.exp(-t * d)
                     for f, a, d in ((112.0, 0.6, 2.6), (171.0, 0.45, 3.1), (263.0, 0.35, 3.8), (389.0, 0.25, 4.6), (617.0, 0.16, 6.0)))
        samples[i] = crunch + boom + plates
    _creak(samples, 1.1, 1.9, noise, 91, low=41.0, high=36.0, gain=0.55)
    samples = Biquad.highpass(28, q=0.7).process_all(samples)
    samples = Biquad.lowpass(3800, q=0.8).process_all(samples)
    samples = apply_corridor_echo(samples, echo_delay_ms=85, feedback=0.4, lp_cutoff=1100, wet=0.55)
    save_wav("foley/dock_contact.wav", samples, normalize_to=0.96)

    n = int(SAMPLE_RATE * 1.9)
    samples = [0.0] * n
    noise = pink_noise(n, seed=1402)
    for k, at in enumerate((0.05, 0.45, 0.85, 1.25)):
        bp = Biquad.bandpass(650 + k * 40, q=1.6)
        for i in range(int(SAMPLE_RATE * at), int(SAMPLE_RATE * (at + 0.2))):
            t = i / SAMPLE_RATE - at
            samples[i] += bp.process(noise[i]) * (t / 0.2) ** 2 * 0.9
        _thunk(samples, at + 0.2, 1410 + k, weight=1.4, gain=1.0)
    samples = Biquad.highpass(35, q=0.7).process_all(samples)
    samples = Biquad.lowpass(4200, q=0.8).process_all(samples)
    samples = apply_corridor_echo(samples, echo_delay_ms=60, feedback=0.3, lp_cutoff=1400)
    save_wav("foley/dock_clamps.wav", samples, normalize_to=0.94)

    n = int(SAMPLE_RATE * 3.0)
    samples = [0.0] * n
    noise = pink_noise(n, seed=1403)
    bp_gear = Biquad.bandpass(1800, q=3.0)
    bp_hiss = Biquad.bandpass(2400, q=1.0)
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        spin = min(1.0, t / 0.4) * min(1.0, (2.85 - t) / 0.45) if t < 2.85 else 0.0
        spin = max(0.0, spin)
        f = 70.0 + 55.0 * spin
        phase += 2.0 * math.pi * f / SAMPLE_RATE
        whine = (math.sin(phase) * 0.6 + math.sin(phase * 2.0) * 0.35 + math.sin(phase * 3.0 + 0.2) * 0.25 + math.sin(phase * 7.0) * 0.08)
        teeth = 0.5 + 0.5 * math.sin(phase * 0.25)
        gear = bp_gear.process(noise[i]) * teeth ** 4 * 0.9
        samples[i] = (whine * 0.8 + gear + bp_hiss.process(noise[i]) * 0.35) * spin
    _thunk(samples, 0.0, 1420, weight=0.8, gain=0.35)
    _thunk(samples, 2.82, 1421, weight=1.2, gain=0.6)
    samples = Biquad.highpass(40, q=0.7).process_all(samples)
    samples = Biquad.lowpass(4600, q=0.8).process_all(samples)
    samples = apply_corridor_echo(samples, echo_delay_ms=50, feedback=0.25, lp_cutoff=1600, wet=0.4)
    save_wav("foley/collar_motor.wav", samples, normalize_to=0.88)


SIREN_SECONDS = 2.0


def generate_siren():
    """
    dock_siren.wav (a 2 s loop: two whoops): the undock warning (GDD §8.3), a harsh horn sweeping
    up through each whoop and dropping away, its odd harmonics shaped by the horn's throat. It
    sounds through the docking port, the collar and the derelict's open end until the collar lets
    go.
    """
    length = int(SAMPLE_RATE * SIREN_SECONDS)
    n = length + int(SAMPLE_RATE * 0.2)
    samples = [0.0] * n
    horn = Biquad.bandpass(1150, q=1.3)
    body = Biquad.bandpass(520, q=1.0)
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        u = (t % 1.0)
        if u < 0.72:
            f = 430.0 + 380.0 * (u / 0.72) ** 0.7
            env = min(1.0, u / 0.04) * (1.0 if u < 0.62 else 1.0 - (u - 0.62) / 0.1)
        else:
            f = 430.0
            env = 0.0
        f *= 1.0 + 0.006 * math.sin(2.0 * math.pi * 6.0 * t)
        phase += 2.0 * math.pi * f / SAMPLE_RATE
        tone = math.tanh((math.sin(phase) + math.sin(phase * 3.0) / 3.0 + math.sin(phase * 5.0) / 5.0) * 2.5)
        samples[i] = (horn.process(tone) * 1.4 + body.process(tone) * 0.8) * env
    samples = Biquad.highpass(120, q=0.7).process_all(samples)
    samples = Biquad.lowpass(4000, q=0.8).process_all(samples)
    save_wav("ambient/dock_siren.wav", seamless(samples, length, 0.05), normalize_to=0.85, saturate=False)


# =============================================================================
# MAIN
# =============================================================================

def main():
    generate_flashlight_clicks()
    generate_all_footsteps()
    generate_door_sounds()
    generate_station_hum()
    generate_derelict_ambience()
    generate_jump_spool()
    generate_jump_enter()
    generate_hyperspace_loop()
    generate_jump_exit()
    generate_terminal_sounds()
    generate_fuel_cell_load()
    generate_item_pickup()
    generate_hatch_sounds()
    generate_airlock_sounds()
    generate_dock_sounds()
    generate_siren()


if __name__ == "__main__":
    main()
