#!/usr/bin/env python3
"""Author and verify MidnightAccess audio. Uses existing NumPy and ffmpeg only.

All notes, envelopes and arrangements below are original procedural compositions.
No source recordings, downloaded samples, model music service or network is used.
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
AUTHOR = "Codex gpt-6.1-sol / high; original offline synthesis, 2026-11-05"
# Voicings use sevenths, ninths and suspended tones; each four-bar cell leads home.
CUES = [
    dict(id="A01", title="Signal Home", file="a01_signal_home", mood="home", bpm=80, bars=48,
         chords=[[50,57,60,64,69],[46,53,57,60,65],[53,60,64,67,72],[48,55,60,62,67]],
         motif=[74, None, 69, 72, None, 76, 72, 67], rhythm=.20, color="warm suspended D minor; breathing pad / glass answer"),
    dict(id="A02", title="First Connection", file="a02_first_connection", mood="intro", bpm=84, bars=48,
         chords=[[48,55,59,62,67],[45,52,55,59,64],[53,60,64,67,72],[50,57,60,65,69]],
         motif=[67, 71, None, 74, 72, None, 67, 64], rhythm=.12, color="C major / A minor; patient descending connection motif"),
    dict(id="A03", title="Hidden Route", file="a03_hidden_route", mood="investigate", bpm=76, bars=64,
         chords=[[45,52,55,59,64],[48,55,59,62,66],[43,50,55,57,62],[47,54,57,60,64]],
         motif=[76, None, 71, None, 74, 69, None, 67], rhythm=.24, color="A dorian shadows; sparse delayed keys / wide filtered pad"),
    dict(id="A04", title="Packet Flow", file="a04_packet_flow", mood="flow", bpm=92, bars=80,
         chords=[[52,59,62,66,69],[48,55,59,64,67],[55,62,66,69,74],[50,57,62,64,69]],
         motif=[71, 74, 78, None, 76, 74, 69, None], rhythm=.50, color="E minor ninths; interlocking soft pulse / rising three-note motif"),
    dict(id="A05", title="Raised Alert", file="a05_raised_alert", mood="alert", bpm=104, bars=64,
         chords=[[42,49,52,56,61],[45,52,55,59,64],[40,47,52,54,59],[44,51,54,57,61]],
         motif=[73, None, 72, 68, 73, 75, None, 68], rhythm=.78, color="F sharp minor tension; muted kick / unsettled semitone answer"),
    dict(id="A06", title="Broken Pattern", file="a06_broken_pattern", mood="reveal", bpm=72, bars=48,
         chords=[[47,54,57,61,66],[43,50,54,59,62],[50,57,61,64,69],[45,52,57,59,64]],
         motif=[78, None, 73, 74, None, 69, 66, None], rhythm=.10, color="B minor / G major ambiguity; reverse-like pad / fragile bell"),
    dict(id="A07", title="Clear Channel", file="a07_clear_channel", mood="ending", bpm=80, bars=64,
         chords=[[55,62,66,69,74],[50,57,62,66,69],[52,59,62,67,71],[48,55,60,64,67]],
         motif=[74, 78, None, 81, 79, 78, 74, None], rhythm=.28, color="G major ninths; open register / gentle resolution, no victory fanfare"),
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
        sound = .85 * np.sin(angle) + .15 * np.sin(2 * angle)
        env = envelope(len(t), .08, .50) * np.exp(-t * .32)
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


def render_music(cue: dict) -> np.ndarray:
    beat = 60 / cue["bpm"]
    bar = beat * 4
    result = np.zeros((round(cue["bars"] * bar * RATE), 2), dtype=np.float32)
    rng = np.random.default_rng(61000 + int(cue["id"][1:]))
    for cell in range(cue["bars"] // 4):
        chord = cue["chords"][cell % 4]
        # Four 16-bar sections: sparse, bloom, rhythmic, return. Never empty.
        section = (cell // 4) % 4
        density = [.65, .90, 1.0, .75][section]
        for index, note in enumerate(chord):
            add(result, voice(note, bar * 4 + 2.6, "pad", index * .73), cell * bar * 4,
                .10 * density / math.sqrt(len(chord)), (index - 2) * .25)
        for local_bar in range(4):
            b = cell * 4 + local_bar
            bass_note = chord[0] - 12
            add(result, voice(bass_note, beat * 3.7, "bass"), b * bar, .105 * density)
            if section in [1, 2] or cue["id"] == "A05":
                add(result, voice(bass_note + (7 if local_bar == 3 else 0), beat * 1.7, "bass"),
                    b * bar + beat * 2.5, .043)
            # The melody answers across two bars with space for text reading.
            for step in range(4):
                motif_index = (b * 4 + step) % len(cue["motif"])
                note = cue["motif"][motif_index]
                if note is None or (section == 0 and step % 2):
                    continue
                if b % 4 == 3 and step >= 2:
                    continue
                transposition = [0, 0, 12 if cue["id"] != "A05" else 0, -12][section]
                add(result, voice(note + transposition, 2.8, "bell"), b * bar + step * beat + beat * .20,
                    .033 * density, math.sin(b + step) * .55)
            # Band-limited, quiet rhythmic detail: no square waves or sharp hats.
            for step in range(8):
                if step % 2 and section == 0:
                    continue
                n = round(.08 * RATE)
                noise = rng.normal(0, 1, n).astype(np.float32)
                noise = np.convolve(noise, np.ones(13) / 13, mode="same")
                tick = noise * np.exp(-np.arange(n) / (RATE * .012)) * envelope(n, .003, .03)
                add(result, tick, b * bar + step * beat / 2, cue["rhythm"] * .022 * density, .3 if step % 2 else -.3)
            if cue["rhythm"] >= .45 and section != 0:
                t = np.arange(round(.30 * RATE)) / RATE
                kick = np.sin(2 * np.pi * (45 * t + 2.6 * (1 - np.exp(-t * 15)))) * np.exp(-t * 18)
                kick *= envelope(len(t), .008, .08)
                for pulse in [0, 2]:
                    add(result, kick, b * bar + pulse * beat, .060 * cue["rhythm"])
    room_reverb(result, beat)
    return master(result, .085 if cue["id"] == "A05" else .078)


def master(samples: np.ndarray, target_rms: float) -> np.ndarray:
    samples -= samples.mean(axis=0)
    rms = float(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))
    samples *= min(target_rms / max(rms, 1e-9), .66 / max(float(np.abs(samples).max()), 1e-9))
    # A 25 ms de-click window also tolerates Vorbis encoder padding at the seam.
    edge = min(round(.025 * RATE), len(samples) // 4)
    join = np.zeros(2, dtype=np.float32)
    weights = np.linspace(1, 0, edge, dtype=np.float32)[:, None]
    samples[:edge] = samples[:edge] * (1 - weights) + join * weights
    samples[-edge:] = samples[-edge:] * weights + join * (1 - weights)
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


def render_ambience() -> np.ndarray:
    result = np.zeros((RATE * 48, 2), dtype=np.float32)
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
    return master(result, .035)


def stats(samples: np.ndarray) -> dict:
    assert samples.ndim == 2 and samples.shape[1] == 2
    assert np.isfinite(samples).all(), "non-finite audio"
    peak = float(np.abs(samples).max())
    rms = float(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))
    window = RATE
    blocks = [float(np.sqrt(np.mean(samples[i:i + window].astype(np.float64) ** 2)))
              for i in range(0, len(samples), window) if len(samples[i:i + window]) >= window]
    return dict(seconds=round(len(samples) / RATE, 6), peak=round(peak, 6),
                peak_dbfs=round(20 * math.log10(max(peak, 1e-12)), 3), rms=round(rms, 6),
                rms_dbfs=round(20 * math.log10(max(rms, 1e-12)), 3),
                dc=round(float(np.abs(samples.mean(axis=0)).max()), 8),
                silent_seconds=sum(x < .0001 for x in blocks),
                loop_jump=round(float(np.abs(samples[-1] - samples[0]).max()), 7),
                clipped_samples=int(np.sum(np.abs(samples) >= .999)))


def validate(values: dict, looping: bool) -> None:
    assert .0001 < values["rms"] < .20, values
    assert 0 < values["peak"] < .90, values
    assert values["clipped_samples"] == 0, values
    assert values["dc"] < .003, values
    if looping:
        assert values["silent_seconds"] == 0, values
        assert values["loop_jump"] < .02, values


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
               "-c:a", "vorbis", "-strict", "-2", "-b:a", "112k",
               "-metadata", "artist=" + AUTHOR, "-metadata", "title=" + metadata["title"],
               "-metadata", "copyright=Original synthesis; project license", str(staged)]
    subprocess.run(command, check=True)
    decoded = subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-i", str(staged),
                              "-f", "f32le", "-ac", "2", "-ar", str(RATE), "pipe:1"],
                             check=True, capture_output=True).stdout
    encoded_values = stats(np.frombuffer(decoded, dtype="<f4").reshape(-1, 2))
    validate(encoded_values, looping)
    assert abs(encoded_values["seconds"] - values["seconds"]) < .06
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
    assert 17 * 60 <= sum(c["bars"] * 240 / c["bpm"] for c in CUES) <= 24 * 60
    for invalid in [dict(rms=0, peak=.2, dc=0, clipped_samples=0, silent_seconds=0, loop_jump=0),
                    dict(rms=.1, peak=1.0, dc=0, clipped_samples=1, silent_seconds=0, loop_jump=0),
                    dict(rms=.1, peak=.2, dc=0, clipped_samples=0, silent_seconds=1, loop_jump=.5)]:
        try:
            validate(invalid, True)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid audio accepted")
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
    manifest = dict(version=1, author=AUTHOR, sample_rate=RATE, channels=2,
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
    effects = [("click", [79], .18), ("key", [65], .075), ("hover", [86], .12),
               ("notification", [74, 81], .8), ("success", [67, 74, 78], 1.2),
               ("error", [58, 57], .55), ("connect", [62, 69, 74], .8),
               ("disconnect", [74, 69, 62], .8), ("alert", [61, 68, 61], 1.0),
               ("tool", [71, 78], .45), ("save", [74, 79], .6), ("window", [72], .25)]
    for name, notes, duration in effects:
        manifest["effects"].append(encode(name, "sfx", render_sfx(notes, duration, .065 if name in ["key", "hover"] else .10),
                                           False, dict(title=name, event=name)))
    manifest["ambience"].append(encode("night_rain_air", "ambience", render_ambience(), True,
                                        dict(title="Night Rain and Workstation Air")))
    (ASSETS / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print("Original audio production complete:", round(sum(x["master_stats"]["seconds"] for x in manifest["music"]), 2), "music seconds", flush=True)


if __name__ == "__main__":
    main()
