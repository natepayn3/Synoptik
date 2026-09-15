#!/usr/bin/env python3
"""
Synoptik Mascot Clip Validator
Part of the Synoptik Quickshell desktop environment.

Checks a set of mascot animation clips for the things that only show up
once they're on screen and moving - a clip whose canvas is 4px taller than
the rest makes the character hop every time that state is entered, and a
reaction clip whose last frame doesn't match the idle pose cuts visibly
back to idle when it ends.

The state vocabulary is read out of components/services/MascotState.qml
rather than repeated here, so adding a row to that ladder is the only edit
needed to make this script aware of a new state.

Usage:
    mascot_validate.py <clip-dir>     validate a directory of <state>.<ext> clips
    mascot_validate.py --config       validate the clips registered in settings.json

Exit status is 0 when nothing is broken (warnings still allow 0), 1 when
at least one error was found, 2 on a usage or environment problem.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SHELL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_QML = os.path.join(SHELL_DIR, "components", "services", "MascotState.qml")
SETTINGS = os.path.join(SHELL_DIR, "settings.json")

CLIP_EXTS = (".webp", ".gif", ".png", ".mng")

# Normalised RMSE (0..1) between a reaction's last frame and idle's first.
# Anything under NOTICE reads as a clean hand-off; past WARN the cut is
# visible at the speed these clips actually play.
CONTINUITY_NOTICE = 0.10
CONTINUITY_WARN = 0.20

ERROR, WARN, INFO = "ERROR", "WARN", "INFO"

RED, YEL, GRN, DIM, OFF = "\033[31m", "\033[33m", "\033[32m", "\033[2m", "\033[0m"
if not sys.stdout.isatty():
    RED = YEL = GRN = DIM = OFF = ""


def die(msg):
    """Environment or usage failure - distinct from 'the clips are bad', so
    a caller can tell 'this set has errors' (1) from 'I could not even
    run the check' (2)."""
    print(msg, file=sys.stderr)
    sys.exit(2)


class Report:
    def __init__(self):
        self.rows = []

    def add(self, level, scope, msg):
        self.rows.append((level, scope, msg))

    def errors(self):
        return [r for r in self.rows if r[0] == ERROR]

    def warns(self):
        return [r for r in self.rows if r[0] == WARN]

    def dump(self):
        colour = {ERROR: RED, WARN: YEL, INFO: DIM}
        mark = {ERROR: "x", WARN: "!", INFO: "-"}
        for level, scope, msg in self.rows:
            c = colour[level]
            print(f"  {c}{mark[level]}{OFF} {scope:<12} {msg}")


# ---------------------------------------------------------------- vocabulary

def load_vocabulary():
    """Pull condition + reaction state names straight from MascotState.qml."""
    try:
        src = open(STATE_QML, encoding="utf-8").read()
    except OSError as e:
        die(f"cannot read {STATE_QML}: {e}")

    block = re.search(r"readonly property var conditions:\s*\[(.*?)\n    \]", src, re.S)
    conditions = re.findall(r'\{\s*name:\s*"([a-zA-Z]+)"', block.group(1)) if block else []

    rx = re.search(r"readonly property var reactionNames:\s*\[(.*?)\]", src, re.S)
    reactions = re.findall(r'"([a-zA-Z]+)"', rx.group(1)) if rx else []

    if not conditions:
        die("could not parse any condition names out of MascotState.qml")
    return conditions, reactions


# ------------------------------------------------------------------- probing

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def probe(path):
    """Geometry, format, alpha and frame count via ImageMagick.

    Canvas comes from %W/%H (the page geometry), never %w/%h: animated WebP
    stores each frame as only the rectangle that changed, so a later frame's
    own width/height can be a handful of pixels and says nothing about the
    canvas the character is drawn on.
    """
    r = run(["magick", "identify", "-format", "%W %H %m %A\\n", f"{path}[0]"])
    if r.returncode != 0:
        return None, (r.stderr.strip().splitlines() or ["unreadable"])[-1]
    parts = r.stdout.strip().splitlines()[0].split()
    if len(parts) < 4:
        return None, "unexpected identify output"

    n = run(["magick", "identify", path])
    frames = len(n.stdout.strip().splitlines()) if n.returncode == 0 else 1

    return {
        "w": int(parts[0]),
        "h": int(parts[1]),
        "fmt": parts[2].upper(),
        "alpha": parts[3],
        "frames": frames,
    }, None


def qt_frames(path, qml_bin):
    """Frame count as Qt's AnimatedImage sees it - the component the mascot
    actually uses. ImageMagick reading a file proves nothing about whether
    the matching Qt image plugin is installed and handles animation.

    Returns (frames, None) or (None, reason).
    """
    # Must be absolute: a relative path in a file:// URL makes its first
    # segment the authority ("file://assets/x" = host "assets"), which Qt
    # then fails to load - and the failure looks exactly like a corrupt clip.
    path = os.path.abspath(path)
    qml = (
        "import QtQuick\n"
        "Item {\n"
        f'  AnimatedImage {{ id: a; source: "file://{path}"; playing: true }}\n'
        "  Timer { interval: 700; running: true;\n"
        "    onTriggered: Qt.exit(a.status === Image.Ready ? Math.min(a.frameCount, 200) : 255) }\n"
        "}\n"
    )
    with tempfile.NamedTemporaryFile("w", suffix=".qml", delete=False) as f:
        f.write(qml)
        tmp = f.name
    try:
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
        r = subprocess.run([qml_bin, tmp], capture_output=True, text=True,
                           env=env, timeout=30)
        if r.returncode == 255:
            return None, "Qt could not load this file"
        return r.returncode, None
    except subprocess.TimeoutExpired:
        return None, "Qt load timed out"
    finally:
        os.unlink(tmp)


def extract_frame(path, index, frames, out):
    """Write one fully-composited frame to `out`.

    -coalesce is mandatory: without it a sub-frame format hands back the
    changed rectangle rather than the whole character.
    """
    if index < 0:
        index = frames + index
    keep = []
    if frames > 1:
        # Delete everything except `index`, expressed as up-to and from ranges.
        if index > 0:
            keep.append(f"0-{index - 1}")
        if index < frames - 1:
            keep.append(f"{index + 1}-{frames - 1}")
    args = ["magick", path, "-coalesce"]
    for rng in keep:
        args += ["-delete", rng]
    args += ["+repage", out]
    return run(args).returncode == 0


def rmse(a, b):
    r = run(["magick", "compare", "-metric", "RMSE", a, b, "null:"])
    m = re.search(r"\(([0-9.]+)\)", (r.stderr or "") + (r.stdout or ""))
    return float(m.group(1)) if m else None


# -------------------------------------------------------------------- checks

def discover(clip_dir):
    found = {}
    for entry in sorted(os.listdir(clip_dir)):
        stem, ext = os.path.splitext(entry)
        if ext.lower() in CLIP_EXTS:
            found[stem] = os.path.join(clip_dir, entry)
    return found


def validate(clips, conditions, reactions, rep, tmpdir):
    known = set(conditions) | set(reactions)
    qml_bin = shutil.which("qml6") or shutil.which("qml")
    if not qml_bin:
        rep.add(INFO, "environment", "qml6 not found - skipping the Qt load check")

    info = {}
    for state in sorted(clips):
        path = clips[state]
        if state not in known:
            rep.add(WARN, state, f"not a state MascotState knows - this clip will never play")
        if not os.path.exists(path):
            rep.add(ERROR, state, f"file does not exist: {path}")
            continue

        meta, err = probe(path)
        if meta is None:
            rep.add(ERROR, state, f"unreadable: {err}")
            continue
        info[state] = meta
        meta["path"] = path
        # Inventory line for every clip that was read, so a clean set still
        # shows its work rather than printing nothing at all.
        rep.add(INFO, state, f"{meta['w']}x{meta['h']} {meta['fmt']}, "
                             f"{meta['frames']} frame(s)")

        if meta["frames"] < 2:
            if state in reactions:
                rep.add(WARN, state, "single frame - a reaction cannot signal completion, "
                                     "so it will hold for the full 4s safety timeout")
            else:
                rep.add(INFO, state, "single frame (static pose)")

        if meta["fmt"] == "GIF":
            rep.add(WARN, state, "GIF has 1-bit alpha - soft edges will fringe against "
                                 "the wallpaper; WebP is verified to work here")
        elif meta["alpha"].lower() in ("false", "undefined"):
            rep.add(WARN, state, f"{meta['fmt']} has no alpha channel - the clip will "
                                 "render as an opaque rectangle")

        if qml_bin:
            qframes, qerr = qt_frames(path, qml_bin)
            if qerr:
                rep.add(ERROR, state, qerr)
            elif qframes is not None and qframes < 2 <= meta["frames"]:
                rep.add(ERROR, state,
                        f"ImageMagick sees {meta['frames']} frames but Qt sees {qframes} - "
                        "the Qt plugin is not decoding this file's animation")

    # --- canvas consistency -------------------------------------------------
    # Measured against idle, since idle is the clip every other state falls
    # back to and the one the character's resting position is judged by.
    if info:
        anchor = "idle" if "idle" in info else sorted(info)[0]
        aw, ah = info[anchor]["w"], info[anchor]["h"]
        rep.add(INFO, "canvas", f"set canvas is {aw}x{ah} (from '{anchor}')")
        for state, meta in sorted(info.items()):
            if (meta["w"], meta["h"]) != (aw, ah):
                rep.add(ERROR, state,
                        f"canvas is {meta['w']}x{meta['h']}, set is {aw}x{ah} - the "
                        "character will jump when this state is entered")

    # --- reaction end-pose continuity --------------------------------------
    if "idle" in info:
        idle_first = os.path.join(tmpdir, "idle_first.png")
        if extract_frame(info["idle"]["path"], 0, info["idle"]["frames"], idle_first):
            for state in reactions:
                meta = info.get(state)
                if not meta or meta["frames"] < 2:
                    continue
                if (meta["w"], meta["h"]) != (info["idle"]["w"], info["idle"]["h"]):
                    continue  # already reported as a canvas error
                last = os.path.join(tmpdir, f"{state}_last.png")
                if not extract_frame(meta["path"], -1, meta["frames"], last):
                    continue
                d = rmse(last, idle_first)
                if d is None:
                    continue
                if d >= CONTINUITY_WARN:
                    rep.add(WARN, state, f"last frame differs from idle frame 0 by "
                                         f"{d:.0%} - expect a visible cut when it ends")
                elif d >= CONTINUITY_NOTICE:
                    rep.add(INFO, state, f"last frame differs from idle frame 0 by {d:.0%}")
                else:
                    rep.add(INFO, state, f"hands back to idle cleanly ({d:.0%} difference)")
    return info


def main():
    ap = argparse.ArgumentParser(description="Validate a set of Synoptik mascot clips.")
    ap.add_argument("clip_dir", nargs="?", help="directory of <state>.<ext> clips")
    ap.add_argument("--config", action="store_true",
                    help="validate the clips registered in settings.json instead")
    args = ap.parse_args()

    if not shutil.which("magick"):
        die("ImageMagick ('magick') is required and was not found on PATH")

    conditions, reactions = load_vocabulary()

    if args.config:
        try:
            clips = json.load(open(SETTINGS, encoding="utf-8")).get("mascotClips") or {}
        except OSError as e:
            die(f"cannot read {SETTINGS}: {e}")
        if not clips:
            print("No clips registered yet - mascotClips is empty, so every state "
                  "falls back to mascotPath.")
            return 0
        source = "settings.json"
    elif args.clip_dir:
        if not os.path.isdir(args.clip_dir):
            die(f"not a directory: {args.clip_dir}")
        clips = discover(args.clip_dir)
        if not clips:
            die(f"no clip files ({', '.join(CLIP_EXTS)}) found in {args.clip_dir}")
        source = args.clip_dir
    else:
        ap.print_help()
        return 2

    print(f"\nValidating {len(clips)} clip(s) from {source}\n")

    rep = Report()
    with tempfile.TemporaryDirectory() as tmpdir:
        validate(clips, conditions, reactions, rep, tmpdir)

    if "idle" not in clips:
        rep.add(WARN, "idle", "no idle clip - states without their own clip will fall "
                              "through to mascotPath rather than to this set")

    missing = [s for s in conditions + reactions if s not in clips]
    if missing:
        rep.add(INFO, "unfilled", f"{len(missing)} state(s) have no clip yet: "
                                  + ", ".join(missing))

    rep.dump()

    errs, warns = len(rep.errors()), len(rep.warns())
    print()
    if errs:
        print(f"{RED}{errs} error(s){OFF}, {warns} warning(s)")
        return 1
    if warns:
        print(f"{YEL}{warns} warning(s){OFF}, no errors")
        return 0
    print(f"{GRN}All clips valid.{OFF}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
