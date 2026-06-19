"""Generate METTA OS synthetic sound theme (OGG, <=2s each)."""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100


def tone(freq: float, duration: float, amp: float = 0.25, fade: float = 0.02) -> np.ndarray:
    t = np.linspace(0, duration, int(SR * duration), endpoint=False)
    wave = amp * np.sin(2 * math.pi * freq * t)
    fade_samples = int(SR * fade)
    if fade_samples > 0:
        env = np.ones_like(wave)
        env[:fade_samples] = np.linspace(0, 1, fade_samples)
        env[-fade_samples:] = np.linspace(1, 0, fade_samples)
        wave *= env
    return wave.astype(np.float32)


def chord(freqs: list[float], duration: float, amp: float = 0.18) -> np.ndarray:
    mix = np.zeros(int(SR * duration), dtype=np.float32)
    for f in freqs:
        mix += tone(f, duration, amp / len(freqs), fade=0.01)
    return mix


def write(name: Path, data: np.ndarray) -> None:
    sf.write(name, data, SR, format="OGG", subtype="VORBIS")


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "stereo")
    out.mkdir(parents=True, exist_ok=True)

    startup = np.concatenate([
        tone(220, 0.15, 0.12),
        tone(330, 0.15, 0.14),
        tone(440, 0.25, 0.16),
        tone(554, 0.35, 0.18),
    ])
    write(out / "metta-startup.ogg", startup)

    shutdown = np.concatenate([
        tone(440, 0.2, 0.16),
        tone(330, 0.25, 0.14),
        tone(220, 0.35, 0.1),
    ])
    write(out / "metta-shutdown.ogg", shutdown)

    write(out / "metta-notification.ogg", tone(880, 0.12, 0.2))
    write(out / "metta-warning.ogg", np.concatenate([tone(440, 0.1, 0.2), tone(440, 0.1, 0.2)]))
    write(out / "metta-error.ogg", np.concatenate([tone(330, 0.15, 0.22), tone(220, 0.2, 0.18)]))
    write(out / "metta-login.ogg", chord([440, 554, 659], 0.35))
    write(out / "metta-complete.ogg", np.concatenate([tone(659, 0.1, 0.18), tone(880, 0.15, 0.2)]))

    links = {
        "audio-volume-change.ogg": "metta-notification.ogg",
        "bell.ogg": "metta-notification.ogg",
        "complete.ogg": "metta-complete.ogg",
        "dialog-error.ogg": "metta-error.ogg",
        "dialog-warning.ogg": "metta-warning.ogg",
        "login.ogg": "metta-login.ogg",
        "logout.ogg": "metta-shutdown.ogg",
        "service-login.ogg": "metta-login.ogg",
        "startup.ogg": "metta-startup.ogg",
    }
    for dst, src in links.items():
        target = out / dst
        if target.exists() or target.is_symlink():
            target.unlink()
        target.symlink_to(src)

    print(f"Generated {len(list(out.glob('*.ogg')))} sounds in {out}")


if __name__ == "__main__":
    main()
