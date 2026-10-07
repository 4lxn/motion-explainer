"""Render a scene's narration to one AAC clip per step with a local Kokoro model.

Reads the JSON from narration.mjs on stdin; writes <out>/step-N.m4a, voice.json and voice.js.
Nothing here touches the network: the model files must already be in ~/.cache/motion-voice.
"""

import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import wave

CACHE = os.path.expanduser("~/.cache/motion-voice")
# Pinned so a swapped model file is refused rather than run.
PINNED = {
    "kokoro-v1.0.int8.onnx": "6e742170d309016e5891a994e1ce1559c702a2ccd0075e67ef7157974f6406cb",
    "voices-v1.0.bin": "bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d",
}
# An original voice with a synthetic sheen: doubled (chorus), a short room, a bright top.
EFFECT = ",".join([
    "highpass=f=90",
    "chorus=0.7:0.9:40|57:0.22|0.18:0.25|0.3:1.9|1.3",
    "aecho=0.85:0.6:24|48:0.18|0.10",
    "treble=g=2.5:f=6000",
    "loudnorm=I=-16:TP=-1.5",
])


def checked(name):
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        sys.exit(f"voice: missing {path}; download it first (see REFERENCE.md, Voice)")
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            digest.update(block)
    if digest.hexdigest() != PINNED[name]:
        sys.exit(f"voice: {name} does not match its pinned sha256; refusing to load it")
    return path


def plain(markdown):
    text = re.sub(r"\*\*|__|`", "", markdown)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    return " ".join(text.split())


def js_block(clips):
    """The Motion.voice script; `</` is escaped so narration can't close the inline <script>."""
    entries = ["null" if c is None else json.dumps(c) for c in clips]
    return ("Motion.voice = [\n" + ",\n".join(entries) + "\n];\n").replace("</", "<\\/")


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: voice.py <out-dir> <voice> [speed] < narration.json")
    out, voice = sys.argv[1], sys.argv[2]
    speed = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
    steps = json.load(sys.stdin)

    from kokoro_onnx import Kokoro

    kokoro = Kokoro(checked("kokoro-v1.0.int8.onnx"), checked("voices-v1.0.bin"))
    if voice not in kokoro.get_voices():
        sys.exit(f"voice: unknown voice {voice!r}; try one of {', '.join(sorted(kokoro.get_voices())[:12])} …")
    os.makedirs(out, exist_ok=True)
    clips = []
    for step in steps:
        text = plain(step["say"])
        if not text:
            clips.append(None)
            continue
        samples, rate = kokoro.create(text, voice=voice, speed=speed, lang="en-gb" if voice.startswith("b") else "en-us")
        name = f"step-{step['k'] + 1}.m4a"
        with tempfile.NamedTemporaryFile(suffix=".wav") as raw:
            with wave.open(raw.name, "wb") as wav:
                wav.setnchannels(1)
                wav.setsampwidth(2)
                wav.setframerate(rate)
                wav.writeframes((samples.clip(-1, 1) * 32767).astype("<i2").tobytes())
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", raw.name, "-af", EFFECT, "-ar", "44100",
                            "-c:a", "aac", "-b:a", "64k", os.path.join(out, name)], check=True)
        # The player drops a clip whose `say` no longer matches its step.
        clips.append({"file": name, "dur": round(len(samples) / rate + 0.1, 2), "say": step["say"]})
        print(f"voice step {step['k'] + 1}: {clips[-1]['dur']}s", file=sys.stderr)

    meta = {"model": "kokoro-v1.0.int8", "voice": voice, "speed": speed, "effect": EFFECT, "steps": clips}
    with open(os.path.join(out, "voice.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    embedded = []
    for clip in clips:
        if clip is None:
            embedded.append(None)
            continue
        with open(os.path.join(out, clip["file"]), "rb") as fh:
            data = base64.b64encode(fh.read()).decode()
        embedded.append({"dur": clip["dur"], "say": clip["say"], "src": "data:audio/mp4;base64," + data})
    with open(os.path.join(out, "voice.js"), "w") as fh:
        fh.write(js_block(embedded))
    total = sum(c["dur"] for c in clips if c)
    print(f"voice {sum(1 for c in clips if c)} clips, {total:.1f}s -> {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
