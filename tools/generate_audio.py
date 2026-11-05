#!/usr/bin/env python3
"""Author and verify MidnightAccess audio. Uses existing NumPy and ffmpeg only.

All notes, envelopes and arrangements below are original procedural compositions.
No source recordings, downloaded samples, model music service or network is used.
Product revision: rhythmic score with codec-aligned circular loop synthesis.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "godot/assets/audio"
MASTERS = ROOT / "builds/audio-masters"
RATE = 44100
AUTHOR = "Codex gpt-6.1-sol / high; original rhythmic OST, circular production revision 2026-11-05"
DIAGNOSTICS = ROOT / "builds/audio-upgrade-20261105"
# Voicings use sevenths, ninths and suspended tones; each four-bar cell leads home.
CUES = [
    dict(id="A01", title="Signal Home", file="a01_signal_home", mood="home", bpm=120, bars=80,
         chords=[[50,57,60,64,69],[46,53,57,60,65],[53,60,64,67,72],[48,55,60,62,67]],
         motif=[74, None, 69, 72, None, 76, 72, 67], rhythm=.82, style="synthwave", color="D minor analog drive / four-on-floor and glass motif"),
    dict(id="A02", title="First Connection", file="a02_first_connection", mood="intro", bpm=128, bars=80,
         chords=[[48,55,58,62,67],[44,51,55,58,63],[53,60,63,67,70],[46,53,58,60,65]],
         motif=[67, 70, None, 74, 72, None, 67, 63], rhythm=.74, style="breakbeat", color="C minor first infiltration / syncopated bass and restrained backbeat"),
    dict(id="A03", title="Hidden Route", file="a03_hidden_route", mood="investigate", bpm=124, bars=112,
         chords=[[45,52,55,59,64],[48,55,59,62,66],[43,50,55,57,62],[47,54,57,60,64]],
         motif=[76, None, 71, None, 74, 69, None, 67], rhythm=.78, style="breakbeat", color="A dorian investigation / broken kick pattern and rotating sixteenth arp"),
    dict(id="A04", title="Packet Flow", file="a04_packet_flow", mood="flow", bpm=136, bars=112,
         chords=[[52,59,62,66,69],[48,55,59,64,67],[55,62,66,69,74],[50,57,62,64,69]],
         motif=[71, 74, 78, None, 76, 74, 69, None], rhythm=.92, style="breakbeat", color="E minor packet momentum / punchy breaks and rising synth counterline"),
    dict(id="A05", title="Raised Alert", file="a05_raised_alert", mood="alert", bpm=148, bars=96,
         chords=[[42,49,52,56,61],[45,52,55,59,64],[40,47,52,54,59],[44,51,54,57,61]],
         motif=[73, None, 72, 68, 73, 75, None, 68], rhythm=1.0, style="alert", color="F sharp minor pursuit / strongest breakbeat, sixteenth bass and tension stabs"),
    dict(id="A06", title="Broken Pattern", file="a06_broken_pattern", mood="reveal", bpm=112, bars=64,
         chords=[[47,54,57,61,66],[43,50,54,59,62],[50,57,61,64,69],[45,52,57,59,64]],
         motif=[78, None, 73, 74, None, 69, 66, None], rhythm=.60, style="halftime", color="B minor reveal / half-time snare and gated bass, release against alert"),
    dict(id="A07", title="Clear Channel", file="a07_clear_channel", mood="ending", bpm=112, bars=96,
         chords=[[55,62,66,69,74],[50,57,62,66,69],[52,59,62,67,71],[48,55,60,64,67]],
         motif=[74, 78, None, 81, 79, 78, 74, None], rhythm=.68, style="ending", color="G major recovery / steady forward beat with open resolving synth theme"),
]


def frequency(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def envelope(length: int, attack: float, release: float) -> np.ndarray:
    env = np.ones(length, dtype=np.float32)
    a, r = min(length, int(attack * RATE)), min(length, int(release * RATE))
    if a:
        env[:a] *= np.sin(np.linspace(0, math.pi / 2, a)) ** 2
    if r:
        env[-r:] *= np.sin(np.linspace(math.pi / 2, 0, r)) ** 2
    return env


def voice(note: float, seconds: float, kind: str, phase: float = 0.0) -> np.ndarray:
    t = np.arange(round(seconds * RATE), dtype=np.float64) / RATE
    f = frequency(note)
    angle = 2 * np.pi * f * t
    if kind == "pad":
        # Low partials and gentle beating avoid saw-wave aliasing and hard beeps.
        sound = (.65 * np.sin(angle + phase) + .22 * np.sin(angle * 1.0017 + .7)
                 + .10 * np.sin(angle * 2 + .3) + .03 * np.sin(angle * 3))
        sound *= .92 + .08 * np.cos(2 * np.pi * .11 * t + phase)
        env = envelope(len(t), 1.8, 2.8)
    elif kind == "bass":
        sound = np.sin(angle) + .38 * np.sin(2 * angle) + .18 * np.sin(3 * angle) + .08 * np.sin(4 * angle)
        sound = np.tanh(sound * 1.6) * .82
        env = envelope(len(t), .006, min(.065, seconds * .35)) * np.exp(-t * 1.5)
    elif kind in ["arp", "lead"]:
        sound = np.zeros(len(t), dtype=np.float64)
        # Explicit partial ceiling keeps upper synth notes below Nyquist.
        for harmonic in range(1, min(9, int((RATE * .43) / f)) + 1):
            weight = math.exp(-harmonic * (.20 if kind == "arp" else .32)) / harmonic
            sound += weight * np.sin(angle * harmonic + .12 * np.sin(2 * np.pi * .7 * t))
        sound += .13 * np.sin(angle * 1.0025 + .4)
        env = envelope(len(t), .006 if kind == "arp" else .014, min(.13, seconds * .40))
        env *= np.exp(-t * (6.0 if kind == "arp" else 2.0))
    elif kind == "bell":
        sound = np.sin(angle) + .24 * np.sin(2 * angle) * np.exp(-t * 2.5)
        sound += .06 * np.sin(3 * angle) * np.exp(-t * 5)
        env = envelope(len(t), .015, .50) * np.exp(-t * 1.7)
    else:
        raise ValueError(kind)
    return (sound * env).astype(np.float32)


def add(buffer: np.ndarray, sound: np.ndarray, start: float, gain: float, pan: float = 0.0) -> None:
    """Circular placement preserves tails over the loop boundary."""
    offset = round(start * RATE) % len(buffer)
    stereo = sound[:, None] * np.array([math.sqrt((1 - pan) / 2), math.sqrt((1 + pan) / 2)]) * gain
    while len(stereo):
        take = min(len(stereo), len(buffer) - offset)
        buffer[offset:offset + take] += stereo[:take]
        stereo, offset = stereo[take:], 0


def room_reverb(buffer: np.ndarray, beat: float) -> None:
    dry = buffer.copy()
    for delay, gain in [(beat * .75, .18), (beat * 1.5, .10), (beat * 2.25, .055)]:
        buffer += np.roll(dry[:, ::-1], round(delay * RATE), axis=0) * gain


def drum(kind: str, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    seconds = {"kick": .40, "snare": .24, "hat": .065, "open_hat": .18}[kind]
    t = np.arange(round(seconds * RATE)) / RATE
    if kind == "kick":
        # A pitched body and short noise attack, not a sampled recording.
        phase = 2 * np.pi * (49 * t + 5.1 * (1 - np.exp(-t * 28)))
        body = np.sin(phase) * np.exp(-t * 12)
        attack = rng.normal(0, 1, len(t)) * np.exp(-t * 380) * .12
        sound = body + attack
    else:
        noise = rng.normal(0, 1, len(t))
        spectrum = np.fft.rfft(noise)
        hz = np.fft.rfftfreq(len(t), 1 / RATE)
        low, high = (650, 6800) if kind == "snare" else (4300, 10500)
        band = (1 - np.exp(-(hz / low) ** 2)) * np.exp(-(hz / high) ** 4)
        filtered = np.fft.irfft(spectrum * band, n=len(t))
        filtered /= max(.01, float(np.sqrt(np.mean(filtered ** 2))))
        if kind == "snare":
            sound = .48 * filtered * np.exp(-t * 21)
            sound += (.43 * np.sin(2 * np.pi * 182 * t) + .15 * np.sin(2 * np.pi * 327 * t)) * np.exp(-t * 27)
            sound += .13 * filtered * np.exp(-t * 110)
        else:
            sound = filtered * np.exp(-t * (70 if kind == "hat" else 23)) * .32
    sound *= envelope(len(t), .0018, .018)
    sound /= max(1.0, float(np.abs(sound).max()))
    return sound.astype(np.float32)


def arrangement(cue: dict) -> list[dict]:
    count = cue["bars"] // 16
    names = (["drive_intro", "main_a", "break_build", "return"] if count == 4 else
             ["drive_intro", "main_a", "break_build", "return", "main_b"] if count == 5 else
             ["drive_intro", "main_a", "main_b", "break_build", "return", "coda"] if count == 6 else
             ["drive_intro", "main_a", "main_b", "break_build", "return", "main_b", "coda"])
    bar_seconds = 240 / cue["bpm"]
    return [dict(name=name, start_bar=index * 16, end_bar=(index + 1) * 16,
                 start_seconds=round(index * 16 * bar_seconds, 4),
                 end_seconds=round((index + 1) * 16 * bar_seconds, 4))
            for index, name in enumerate(names)]


def render_music(cue: dict) -> np.ndarray:
    beat = 60 / cue["bpm"]
    bar = beat * 4
    length = aligned_samples(cue["bars"] * bar)
    tonal = np.zeros((length, 2), dtype=np.float32)
    drums = np.zeros_like(tonal)
    duck = np.ones(length, dtype=np.float32)
    sections = arrangement(cue)
    kit = {kind: [drum(kind, 71000 + int(cue["id"][1:]) * 100 + version * 4 + index)
                  for version in range(3)]
           for index, kind in enumerate(["kick", "snare", "hat", "open_hat"])}
    counts = dict(kick=0, snare=0, hat=0, open_hat=0, bass=0, arp=0, lead=0)
    for cell in range(cue["bars"] // 4):
        chord = cue["chords"][cell % 4]
        section = sections[(cell * 4) // 16]["name"]
        gain = .65 if section == "break_build" else (.80 if section == "drive_intro" else 1.0)
        for index, note in enumerate(chord):
            add(tonal, voice(note, bar * 4 + 2.6, "pad", index * .73), cell * bar * 4,
                .028 * gain / math.sqrt(len(chord)), (index - 2) * .26)
    for b in range(cue["bars"]):
        phrase = sections[b // 16]["name"]
        position = b % 16
        is_break = phrase == "break_build" and position < 8
        build = phrase == "break_build" and position >= 8
        density = .78 if phrase == "drive_intro" else 1.0
        if is_break:
            density = .55
        chord = cue["chords"][(b // 4) % 4]
        root_note = chord[0] - 12
        bass_steps = 16 if cue["style"] == "alert" and not is_break else 8
        bass_pattern = [0, 0, 12, 0, 7, 0, 12, 7] if cue["style"] in ["synthwave", "ending"] else [0, None, 0, 7, 0, 12, None, 7]
        for step in range(bass_steps):
            interval = bass_pattern[step % 8]
            if interval is None or (is_break and step % 2):
                continue
            start = b * bar + step * bar / bass_steps
            note = root_note + interval
            add(tonal, voice(note, beat * (2.3 if is_break else .47), "bass"), start,
                .14 * density * (1.0 if step % 4 == 0 else .8))
            counts["bass"] += 1
        arp_steps = 8 if is_break or cue["style"] in ["halftime", "ending"] else 16
        for step in range(arp_steps):
            if (b % 8 == 7 and step >= arp_steps - 2) or (phrase == "drive_intro" and step % 2):
                continue
            degree = [0, 2, 1, 3, 4, 2, 3, 1][(step + (b // 8) * 2) % 8]
            note = chord[degree] + 12
            add(tonal, voice(note, beat * .75, "arp"), b * bar + step * bar / arp_steps,
                .058 * density * (1.12 if phrase == "return" else 1.0), math.sin(step * 1.1) * .55)
            counts["arp"] += 1
        if b % 4 in [0, 1, 2] and (not is_break or b % 4 == 0):
            for step in range(4):
                note = cue["motif"][(b * 4 + step) % len(cue["motif"])]
                if note is None or (phrase == "drive_intro" and step % 2):
                    continue
                octave = 12 if phrase in ["return", "main_b"] and cue["id"] != "A05" else 0
                add(tonal, voice(note + octave, beat * 1.8, "lead"), b * bar + (step + .15) * beat,
                    .047 * density, .20 * math.sin(b + step))
                counts["lead"] += 1
        if cue["style"] in ["synthwave", "ending"]:
            kick_positions = [0, 1, 2, 3]
        elif cue["style"] == "halftime":
            kick_positions = [0, 1.5, 2.75]
        elif cue["style"] == "alert":
            kick_positions = [0, .75, 1.5, 2, 2.75, 3.5] if b % 2 else [0, 1.5, 2, 2.5, 3.25]
        else:
            kick_positions = [0, 1.5, 2.5] if b % 2 else [0, .75, 2, 3.5]
        snare_positions = [2] if cue["style"] == "halftime" else [1, 3]
        if is_break:
            kick_positions, snare_positions = [0, 2.5], [2]
        if build and position >= 12:
            snare_positions += [3.5] if position < 15 else [3.25, 3.5, 3.75]
        for hit, point in enumerate(kick_positions):
            when = b * bar + point * beat
            add(drums, kit["kick"][(b + hit) % 3], when, .34 * cue["rhythm"] * density)
            counts["kick"] += 1
            span = round(.22 * RATE)
            values = 1 - (.34 if cue["style"] == "alert" else .25) * np.exp(-np.arange(span) / (RATE * .065))
            offset = round(when * RATE) % length
            take = min(span, length - offset)
            duck[offset:offset + take] = np.minimum(duck[offset:offset + take], values[:take])
            if take < span:
                duck[:span - take] = np.minimum(duck[:span - take], values[take:])
        for hit, point in enumerate(snare_positions):
            add(drums, kit["snare"][(b + hit) % 3], b * bar + point * beat,
                .245 * cue["rhythm"] * density * (.68 if point > 3 else 1.0))
            counts["snare"] += 1
            if b % 8 == 7 and not is_break:
                add(drums, kit["snare"][hit % 3], b * bar + (point - .125) * beat,
                    .036 * cue["rhythm"], -.12)
                counts["snare"] += 1
        hats = 8 if cue["style"] in ["halftime", "ending"] or is_break else 16
        for step in range(hats):
            if step % 2 and (phrase == "drive_intro" or (b + step) % 5 == 0):
                continue
            when = b * bar + step * bar / hats
            add(drums, kit["hat"][(b + step) % 3], when,
                .055 * cue["rhythm"] * density * (.80 if step % 2 else 1.0), .25 if step % 2 else -.25)
            counts["hat"] += 1
        if not is_break and cue["style"] in ["alert", "breakbeat"]:
            for point in [1.5, 3.5]:
                add(drums, kit["open_hat"][b % 3], b * bar + point * beat, .033 * cue["rhythm"], .25)
                counts["open_hat"] += 1
    # Delay belongs to the tonal stem; drums retain their transient attack.
    room_reverb(tonal, beat)
    tonal *= duck[:, None]
    target = {"A01": .095, "A02": .100, "A03": .100, "A04": .105, "A05": .112, "A06": .085, "A07": .090}[cue["id"]]
    samples = master(tonal + drums, target)
    cue["target_rms"] = target
    cue["arrangement"] = sections
    cue["event_counts"] = counts
    cue["rms_policy"] = "Rhythmic re-arrangement plus modest mastering presence; audition preview is independently loudness-matched."
    return samples


def master(samples: np.ndarray, target_rms: float) -> np.ndarray:
    samples -= samples.mean(axis=0)
    rms = float(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))
    samples *= min(target_rms / max(rms, 1e-9), .66 / max(float(np.abs(samples).max()), 1e-9))
    # Loop sources already wrap tails/FFT noise circularly; never impose a boundary fade.
    return samples


def render_sfx(notes: list[int], seconds: float, gain: float = .10) -> np.ndarray:
    result = np.zeros((round(seconds * RATE), 2), dtype=np.float32)
    for i, note in enumerate(notes):
        start = i * min(.11, seconds / (len(notes) + 1))
        sound = voice(note, min(.70, seconds - start), "bell")
        # One-shots must release into silence rather than wrap their musical tails.
        offset = round(start * RATE)
        take = min(len(sound), len(result) - offset)
        result[offset:offset + take] += sound[:take, None] * gain
    result *= envelope(len(result), .006, min(.15, seconds / 3))[:, None]
    return result


def render_ambience() -> tuple[np.ndarray, int]:
    result = np.zeros((aligned_samples(48.0), 2), dtype=np.float32)
    rng = np.random.default_rng(61008)
    for channel in range(2):
        noise = rng.normal(0, 1, len(result))
        # Circular FFT filter: soft rain/air band, no imported field recordings.
        spectrum = np.fft.rfft(noise)
        hz = np.fft.rfftfreq(len(noise), 1 / RATE)
        band = (1 - np.exp(-(hz / 180) ** 2)) * np.exp(-(hz / 2300) ** 2)
        result[:, channel] = np.fft.irfft(spectrum * band, n=len(noise))
    t = np.arange(len(result)) / RATE
    for frequency_hz, gain in [(50, .035), (100, .012), (150, .003)]:
        result += (gain * np.sin(2 * np.pi * frequency_hz * t))[:, None]
    result *= (.85 + .15 * np.cos(2 * np.pi * t / 24))[:, None]
    result = master(result, .035)
    # Select a natural quiet value/slope, preserving every sample and the full circular spectrum.
    slope = result - np.roll(result, 1, axis=0)
    cost = np.sum(result.astype(np.float64) ** 2, axis=1) + 4 * np.sum(slope.astype(np.float64) ** 2, axis=1)
    phase = int(np.argmin(cost))
    return np.roll(result, -phase, axis=0), phase


def aligned_samples(seconds: float) -> int:
    # Native Vorbis emits 64-sample blocks; synthesize the actual circular period, not zero padding.
    return math.ceil(seconds * RATE / 64) * 64


def loop_metrics(samples: np.ndarray) -> dict:
    span = min(round(.05 * RATE), len(samples) // 4)
    joined = np.concatenate((samples[-span:], samples[:span])).astype(np.float64)
    differences = np.diff(joined, axis=0)
    seam = samples[0].astype(np.float64) - samples[-1].astype(np.float64)
    neighbors = np.delete(differences, span - 1, axis=0)
    curvature = np.diff(joined, n=2, axis=0)
    seam_curvature = curvature[span - 2:span]
    curvature_neighbors = np.delete(curvature, [span - 2, span - 1], axis=0)
    derivative_q = float(np.quantile(np.abs(neighbors), .999))
    curvature_q = float(np.quantile(np.abs(curvature_neighbors), .999))
    derivative_limit = derivative_q * 1.75 + 4 / 32768
    curvature_limit = curvature_q * 1.75 + 8 / 32768
    jump = float(np.abs(seam).max())
    bend = float(np.abs(seam_curvature).max())
    rms = {}
    for milliseconds in [2, 50, 2000]:
        count = min(round(milliseconds / 1000 * RATE), len(samples) // 2)
        region = np.concatenate((samples[-count:], samples[:count])).astype(np.float64)
        rms[str(milliseconds)] = float(np.sqrt(np.mean(region ** 2)))
    return dict(sample_count=len(samples), seam_difference=round(jump, 9),
                adjacent_derivative_q999=round(derivative_q, 9), derivative_limit=round(derivative_limit, 9),
                seam_curvature=round(bend, 9), adjacent_curvature_q999=round(curvature_q, 9),
                curvature_limit=round(curvature_limit, 9), rms_boundary_windows=rms,
                boundary_rms_2ms_ratio=round(rms["2"] / max(rms["50"], 1e-12), 6),
                passed=jump <= derivative_limit and bend <= curvature_limit)


def stats(samples: np.ndarray) -> dict:
    assert samples.ndim == 2 and samples.shape[1] == 2
    assert np.isfinite(samples).all(), "non-finite audio"
    peak = float(np.abs(samples).max())
    rms = float(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))
    blocks = [float(np.sqrt(np.mean(samples[i:i + RATE].astype(np.float64) ** 2)))
              for i in range(0, len(samples), RATE) if len(samples[i:i + RATE]) >= RATE]
    return dict(seconds=round(len(samples) / RATE, 6), peak=round(peak, 6),
                peak_dbfs=round(20 * math.log10(max(peak, 1e-12)), 3), rms=round(rms, 6),
                rms_dbfs=round(20 * math.log10(max(rms, 1e-12)), 3),
                dc=round(float(np.abs(samples.mean(axis=0)).max()), 8),
                silent_seconds=sum(x < .0001 for x in blocks),
                loop_jump=round(float(np.abs(samples[-1] - samples[0]).max()), 7),
                loop_metrics=loop_metrics(samples),
                clipped_samples=int(np.sum(np.abs(samples) >= .999)))


def validate(values: dict, looping: bool) -> None:
    assert .0001 < values["rms"] < .20, values
    assert 0 < values["peak"] < .90, values
    assert values["clipped_samples"] == 0, values
    assert values["dc"] < .003, values
    if looping:
        assert values["silent_seconds"] == 0, values
        assert values["loop_metrics"]["passed"], values


def encode(name: str, folder: str, samples: np.ndarray, looping: bool, metadata: dict) -> dict:
    destination = ASSETS / folder / (name + ".ogg")
    staged = destination.with_suffix(".render.ogg")
    wav = MASTERS / (name + ".wav")
    wav.parent.mkdir(parents=True, exist_ok=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    values = stats(samples)
    validate(values, looping)
    with wave.open(str(wav), "wb") as output:
        output.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes((samples * 32767).astype("<i2").tobytes())
    command = ["ffmpeg", "-v", "error", "-nostdin", "-y", "-i", str(wav),
               "-c:a", "vorbis", "-strict", "-2", "-b:a", "160k",
               "-metadata", "artist=" + AUTHOR, "-metadata", "title=" + metadata["title"],
               "-metadata", "copyright=Original synthesis; project license", str(staged)]
    subprocess.run(command, check=True)
    decoded = subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-i", str(staged),
                              "-f", "f32le", "-ac", "2", "-ar", str(RATE), "pipe:1"],
                             check=True, capture_output=True).stdout
    encoded_values = stats(np.frombuffer(decoded, dtype="<f4").reshape(-1, 2))
    validate(encoded_values, looping)
    assert abs(encoded_values["seconds"] - values["seconds"]) < .06
    if looping:
        assert len(samples) == len(decoded) // 8, "Encoder padding changed the circular period"
        assert encoded_values["loop_metrics"]["boundary_rms_2ms_ratio"] > .10, "Production loop gained an artificial fade dip"
    staged.replace(destination)
    # Encode introduces a different output hash on different ffmpeg builds; PCM
    # arrangement is deterministic, and every shipped encode has its own digest.
    return dict(**metadata, path=str(destination.relative_to(ROOT / "godot")), loop=looping,
                master=str(wav.relative_to(ROOT)), master_stats=values, encoded_stats=encoded_values,
                bytes=destination.stat().st_size, sha256=hashlib.sha256(destination.read_bytes()).hexdigest())


def self_test() -> None:
    assert abs(frequency(69) - 440) < 1e-8
    env = envelope(4410, .01, .03)
    assert env[0] == 0 and env[-1] < 1e-10 and env.max() == 1
    buffer = np.zeros((10, 2), dtype=np.float32)
    add(buffer, np.ones(4), 8 / RATE, 1)
    assert np.count_nonzero(buffer[:, 0]) == 4 and buffer[0, 0] > 0
    for cue in CUES:
        duration = cue["bars"] * 4 * 60 / cue["bpm"]
        assert (180 <= duration <= 240) if cue["id"] in ["A03", "A04", "A07"] else (120 <= duration <= 180)
        assert len(cue["chords"]) == 4 and len(set(cue["motif"])) >= 5
        assert 108 <= cue["bpm"] <= 148 and cue["rhythm"] >= .60
        assert arrangement(cue)[-1]["end_bar"] == cue["bars"]
    assert 17 * 60 <= sum(c["bars"] * 240 / c["bpm"] for c in CUES) <= 24 * 60
    n = aligned_samples(1.0)
    t = np.arange(n) / n
    periodic = np.repeat((.1 * np.sin(2 * np.pi * 2400 * t))[:, None], 2, axis=1).astype(np.float32)
    values = stats(periodic)
    assert values["loop_jump"] > .001, "Fixture must have a real natural derivative"
    validate(values, True)
    slow = np.repeat((.1 * np.sin(2 * np.pi * t))[:, None], 2, axis=1).astype(np.float32)
    assert loop_metrics(slow)["boundary_rms_2ms_ratio"] < .10
    validate(stats(slow), True)  # Low seam energy alone is not a universal discontinuity.
    broken = periodic.copy()
    broken[:n // 2] += .4
    assert not loop_metrics(broken)["passed"], "Step corruption must fail local derivative tests"
    for invalid in [dict(rms=0, peak=.2, dc=0, clipped_samples=0, silent_seconds=0),
                    dict(rms=.1, peak=1.0, dc=0, clipped_samples=1, silent_seconds=0),
                    dict(rms=.1, peak=.2, dc=0, clipped_samples=0, silent_seconds=1)]:
        try:
            validate(invalid, True)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid audio accepted")
    for kind in ["kick", "snare", "hat", "open_hat"]:
        a, b = drum(kind, 61001), drum(kind, 61001)
        assert np.array_equal(a, b) and np.isfinite(a).all()
        assert .001 < float(np.sqrt(np.mean(a ** 2))) < 1.0
        assert abs(float(a[0])) < .0001 and abs(float(a[-1])) < .0001
    print("Audio self-check PASS: tuning, envelope, circular tails, seven cue contracts, silence/clipping/seam rejection")


def verify() -> None:
    manifest = json.loads((ASSETS / "manifest.json").read_text())
    assert len(manifest["music"]) == 7
    for entry in manifest["music"] + manifest["edits"] + manifest["effects"] + manifest["ambience"]:
        path = ROOT / "godot" / entry["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"], path
        decoded = subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-i", str(path), "-f", "f32le",
                                  "-ac", "2", "-ar", str(RATE), "pipe:1"], capture_output=True, check=True).stdout
        validate(stats(np.frombuffer(decoded, dtype="<f4").reshape(-1, 2)), entry["loop"])
    print("Shipped audio verification PASS:", len(manifest["music"]), "music;", len(manifest["edits"]), "ending edit;", len(manifest["effects"]), "effects;", len(manifest["ambience"]), "ambience")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    self_test()
    if args.self_test:
        return
    assert shutil.which("ffmpeg"), "ffmpeg must already be installed"
    if args.verify:
        verify()
        return
    baseline = json.loads((ASSETS / "manifest.json").read_text())
    manifest = dict(version=3, loop_validation_version=2, author=AUTHOR, sample_rate=RATE, channels=2,
                    provenance="Original note scores and offline additive synthesis; no third-party audio or samples.",
                    license="Project license; see LICENSE.txt", music=[], edits=[], effects=[], ambience=[])
    for cue in CUES:
        print("Rendering", cue["id"], cue["title"], flush=True)
        samples = render_music(cue)
        manifest["music"].append(encode(cue["file"], "music", samples, True, cue))
        if cue["id"] == "A07":
            # A separate credit edit closes gently; the in-game mood stays loopable.
            samples *= envelope(len(samples), 2.0, 14.0)[:, None]
            manifest["edits"].append(encode("a07_clear_channel_ending", "music", samples, False,
                                           dict(id="A07-edit", title="Clear Channel - Ending Edit", source_cue="A07")))
    # Keep already shipped SFX byte-for-byte; only the rain's circular boundary changes.
    for entry in baseline["effects"]:
        path = ROOT / "godot" / entry["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"]
        manifest["effects"].append(entry)
    rain, phase = render_ambience()
    manifest["ambience"].append(encode("night_rain_air", "ambience", rain, True,
                                     dict(title="Night Rain and Workstation Air", phase_offset_samples=phase,
                                          loop_policy="Circular FFT noise with natural value/slope phase selection; no sample fade.")))
    (ASSETS / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print("Original audio production complete:", round(sum(x["master_stats"]["seconds"] for x in manifest["music"]), 2), "music seconds", flush=True)


if __name__ == "__main__":
    main()
