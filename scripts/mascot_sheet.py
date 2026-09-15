#!/usr/bin/env python3
"""
Synoptik Mascot Sheet Builder
Part of the Synoptik Quickshell desktop environment.

Turns a sprite sheet of poses into per-state animation clips.

Three things happen that are easy to get wrong by hand:

  1. Chroma keying. A JPEG sheet has no alpha, so the background has to be
     keyed out, and lossy compression smears colour across every edge. Fuzz
     tolerance is NOT the trade it looks like: erosion is continuous with
     fuzz (measured no plateau from 10% to 34% on real art), so a value high
     enough to erase the fringe is already eating the character's own
     green-toned regions elsewhere. Keep --fuzz low (default 15, just enough
     to clear the solid background) and let despill() recolour the
     remaining spill-tinted edge pixels instead of deleting them.
     --probe-fuzz still helps confirm the background itself is fully gone.

  2. Alignment. Poses drawn free-hand on a grid are not registered to each
     other - the body wanders by tens of pixels between cells. Dropped in
     as-is the character visibly hops every time the state changes. Each
     pose is re-centred on its BODY, found as the largest connected
     component so that detached sparkles and bubbles don't drag the centre
     off, and bottom-aligned to a shared baseline because the mascot's
     transformOrigin is Item.Bottom.

  3. Motion. A pose sheet is static. Condition states get a vertical bob
     that loops seamlessly; reaction states get an explicit pose sequence
     which must END on the idle pose, since that is what the mascot hands
     back to when a one-shot finishes (see mascot_validate.py).

Usage:
  mascot_sheet.py SHEET --grid 3x3 --key '#1AFA05' --out DIR \\
      --assign idle=0 --assign petted=3 \\
      --sequence poke=4,4,2,2,2,0

  mascot_sheet.py SHEET --grid 3x3 --key '#1AFA05' --probe-fuzz
"""

import argparse
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

BOB_OFFSETS = [0, -1, -2, -3, -2, -1]   # loops back to 0 without a jump
DANCE_FRAMES = 8


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def magick(*args):
    r = run(["magick", *[str(a) for a in args]])
    if r.returncode != 0:
        die("magick failed: " + " ".join(str(a) for a in args) + "\n" + r.stderr.strip())
    return r.stdout


# ------------------------------------------------------------------ geometry

def body_box(path):
    """Bounding box of the character's body, excluding detached bits.

    The largest connected component of the alpha mask is the body; sparkles,
    bubbles and other floaters are smaller components and are ignored, which
    is the whole point - centring on the naive bounding box would shove the
    body sideways on any pose that has them.
    """
    out = run(["magick", path, "-alpha", "extract", "-threshold", "50%",
               "-type", "bilevel",
               "-define", "connected-components:verbose=true",
               "-define", "connected-components:area-threshold=100",
               "-connected-components", "8", "null:"]).stdout

    best = None
    for line in out.splitlines():
        # Area is plain digits for a small component but ImageMagick switches
        # to scientific notation (e.g. "1.29123e+06") once it crosses into
        # the millions - a full-resolution single portrait's body is well
        # past that on its own, where a sprite-sheet cell's never was. The
        # area group has to accept both or every large source silently
        # matches nothing and "no body found" fires on a perfectly good image.
        m = re.match(r"\s*\d+:\s+(\d+)x(\d+)\+(-?\d+)\+(-?\d+)\s+[\d.,]+\s+([\d.]+(?:e[+-]?\d+)?)\s+gray\((\d+)\)", line)
        if not m:
            continue
        w, h, x, y = (int(g) for g in m.groups()[:4])
        area = float(m.group(5))
        grey = int(m.group(6))
        if grey < 128:          # gray(0) is the transparent background object
            continue
        if best is None or area > best[4]:
            best = (w, h, x, y, area)
    return best[:4] if best else None


def content_box(path):
    return magick(path, "-format", "%@", "info:").strip()


def strip_strays(path, margin=60, max_aspect=3.5):
    """Erase connected components that are a NEIGHBOURING cell's leftovers,
    not this pose's own effects.

    Cells on a hand-packed sheet don't always have a clean gutter on every
    side - a kicking foot or trailing hair from the row above or below can
    end up inside this cell's crop, keyed out as its own opaque blob same
    as the body. body_box() already tells the difference between "the
    body" and "everything else" for alignment purposes, but leaves the
    everything-else untouched, so a bled-in fragment rides along into the
    final frame - confirmed on a live rebuild as a shoe-sized fragment
    floating above the character's head.

    Two independent tests decide what gets erased, because neither alone
    covers both shapes bleed actually takes:

    - Distance: an effect that belongs to this pose sits close against the
      body it was drawn for; a bled-in fragment from a whole different row
      is typically most of a cell away. Anything whose box doesn't come
      within `margin` px of the body's own box is erased.

    - Aspect ratio: this one exists because distance alone missed a real
      case - a foot sliced clean through by the row gutter lands almost
      flush against the top of the NEXT row's body (that's what "above her
      head" looks like), well inside any margin that wouldn't also cut off
      a genuine sparkle sitting next to her raised hand. But a slice
      through a limb is a thin, elongated sliver - nothing in this
      character's own sparkle/bubble vocabulary is. Anything longer than
      `max_aspect` times its own thickness is erased regardless of
      distance.
    """
    box = body_box(path)
    if box is None:
        return
    bw, bh, bx, by = box
    ex0, ey0 = bx - margin, by - margin
    ex1, ey1 = bx + bw + margin, by + bh + margin

    out = run(["magick", path, "-alpha", "extract", "-threshold", "50%",
               "-type", "bilevel",
               "-define", "connected-components:verbose=true",
               "-define", "connected-components:area-threshold=100",
               "-connected-components", "8", "null:"]).stdout

    for line in out.splitlines():
        m = re.match(r"\s*\d+:\s+(\d+)x(\d+)\+(-?\d+)\+(-?\d+)\s+[\d.,]+\s+([\d.]+(?:e[+-]?\d+)?)\s+gray\((\d+)\)", line)
        if not m:
            continue
        w, h, x, y = (int(g) for g in m.groups()[:4])
        grey = int(m.group(6))
        if grey < 128 or (w, h, x, y) == (bw, bh, bx, by):
            continue                         # background, or the body itself
        overlaps = not (x + w < ex0 or x > ex1 or y + h < ey0 or y > ey1)
        aspect = max(w, h) / max(1, min(w, h))
        if overlaps and aspect < max_aspect:
            continue                         # close AND compact - this pose's own effect
        # -region scopes -evaluate to just this rectangle. The tempting
        # shortcut - compositing a small transparent patch with
        # "-compose Src" - looks region-scoped but isn't: Porter-Duff Src
        # is defined over the WHOLE canvas, and a source smaller than the
        # canvas reads as "fully transparent everywhere else it doesn't
        # cover" too, silently wiping the entire cell (found the hard way -
        # it turned "no body found" into the failure on nearly every cell).
        pad = 4
        ew, eh = w + 2 * pad, h + 2 * pad
        ex, ey = x - pad, y - pad
        magick(path, "-alpha", "set", "-channel", "A",
               "-region", f"{ew}x{eh}+{ex}+{ey}", "-evaluate", "set", "0",
               "+channel", "+region", path)


def despill(path):
    """Suppress green spill on the edge pixels -transparent leaves behind.

    A JPEG-compressed sheet has no hard edge between character and key
    colour - the boundary pixels are a blend of both, tinted green but not
    close enough to pure key colour to be within any SAFE fuzz tolerance.
    Raising fuzz to catch them doesn't work: erosion is continuous with fuzz
    (no plateau), so a tolerance loose enough to erase the fringe is already
    eating the character's own green-toned regions (hair shadow, pant
    fabric) everywhere else in the image. See probe_fuzz's note.

    Recolouring instead of deleting sidesteps that entirely: any pixel whose
    green channel outweighs both red and blue - the fringe's signature, not
    the character's own palette, which has no channel that dominant - is
    pulled to the red/blue average. The pixel stays exactly as opaque as it
    was; only its hue changes.
    """
    magick(path, "-channel", "G",
           "-fx", "u.g>max(u.r,u.b) ? (u.r+u.b)/2 : u.g", "+channel", path)


# ------------------------------------------------------------------- pipeline

def _profile(mask, axis, n):
    """Mean alpha per row (or column), as a 1-px-wide strip."""
    geom = f"1x{n}!" if axis == "row" else f"{n}x1!"
    txt = run(["magick", mask, "-resize", geom, "txt:-"]).stdout
    vals = []
    for line in txt.splitlines()[1:]:
        m = re.search(r"gray\((\d+)", line)
        if m:
            vals.append(int(m.group(1)))
        else:
            m = re.search(r"#([0-9A-Fa-f]{2})", line)
            vals.append(int(m.group(1), 16) if m else 0)
    return vals


def _bands(vals, total, min_gutter=3, min_band=10):
    """Content bands = the spans between runs of all-background lines."""
    empty = [i for i, v in enumerate(vals) if v == 0]
    runs, start, prev = [], None, None
    for i in empty:
        if start is None:
            start = i
        elif i != prev + 1:
            runs.append((start, prev))
            start = i
        prev = i
    if start is not None:
        runs.append((start, prev))
    gutters = [r for r in runs if r[1] - r[0] >= min_gutter]

    bands, cursor = [], 0
    for a, z in gutters:
        if a - cursor > min_band:
            bands.append((cursor, a - 1))
        cursor = z + 1
    if total - cursor > min_band:
        bands.append((cursor, total - 1))
    return bands


def mirror_repair(path):
    """Rebuild an arm the sheet cut off, by mirroring the sprite about its own
    axis of symmetry.

    Art that runs to the very edge of the sheet loses pixels that no slicing
    strategy can recover - they were never in the file. For a symmetric
    character the missing side can be reconstructed from the intact one.

    The axis is taken from the horizontal centre of the TOPMOST row holding
    any pixels: on a star or any pointed character that row is the tip, which
    sits on the axis. Using the bounding-box centre instead would fail on
    exactly the clipped sprites this exists for - their bbox is already
    lopsided, so it would mirror about the wrong line and widen the damage.
    """
    txt = run(["magick", path, "-alpha", "extract", "-threshold", "50%", "txt:-"]).stdout
    rows = {}
    for line in txt.splitlines()[1:]:
        m = re.match(r"(\d+),(\d+): .*?(white|#FFFFFF)", line)
        if m:
            rows.setdefault(int(m.group(2)), []).append(int(m.group(1)))
    if not rows:
        return False
    xs = rows[min(rows)]
    axis = (min(xs) + max(xs)) / 2

    W = int(magick(path, "-format", "%w", "info:"))
    shift = round(2 * axis - W)

    with tempfile.TemporaryDirectory() as td:
        mirrored = os.path.join(td, "m.png")
        magick(path, "-flop", "-background", "none",
               "-page", f"{shift:+d}+0", "-flatten", mirrored)
        # Original on top, so the mirror only shows through where pixels are
        # actually missing - the intact side is never overwritten.
        magick(mirrored, path, "-compose", "Over", "-composite", path)
    return True


def slice_auto(sheet, key, fuzz, workdir):
    """Slice on detected gutters instead of an assumed uniform grid.

    Hand-made sheets are rarely on an exact grid - cell pitch drifts, and the
    last row is often a leftover rather than a full row. Cutting at even
    fractions then slices straight through the artwork. Finding the runs of
    pure background instead puts every cut in a gap.

    Cells are padded to a common canvas so the set stays uniform; align()
    re-centres each body afterwards, so only the canvas size matters here.
    """
    W, H = (int(v) for v in magick(sheet, "-format", "%w %h", "info:").split())
    mask = os.path.join(workdir, "mask.png")
    magick(sheet, "-fuzz", f"{fuzz}%", "-transparent", key,
           "-alpha", "extract", "-threshold", "50%", mask)

    cols = _bands(_profile(mask, "col", W), W)
    rows = _bands(_profile(mask, "row", H), H)
    print(f"  detected {len(cols)} columns x {len(rows)} row bands")

    cw = max(c[1] - c[0] + 1 for c in cols)
    ch = max(r[1] - r[0] + 1 for r in rows)
    pad = 24                                  # room for the sway/lean later
    cw, ch = cw + pad, ch + pad

    keyed = os.path.join(workdir, "keyed_sheet.png")
    magick(sheet, "-fuzz", f"{fuzz}%", "-transparent", key, keyed)
    despill(keyed)

    cells, i, repaired = [], 0, []
    for (ry, rz) in rows:
        for (cx, cz) in cols:
            dst = os.path.join(workdir, f"keyed_{i}.png")
            bw, bh = cz - cx + 1, rz - ry + 1
            magick(keyed, "-crop", f"{bw}x{bh}+{cx}+{ry}", "+repage",
                   "-background", "none", "-gravity", "center",
                   "-extent", f"{cw}x{ch}", dst)

            # A cell whose band runs to the sheet boundary, and whose content
            # reaches that boundary, has been cut by the file itself.
            if ARGS.repair_edges and (cx <= 0 or cz >= W - 1):
                box = magick(keyed, "-crop", f"{bw}x{bh}+{cx}+{ry}", "+repage",
                             "-format", "%@", "info:").strip()
                m = re.match(r"(\d+)x(\d+)([+-]\d+)([+-]\d+)", box)
                if m:
                    ww, _, xx, _ = (int(g) for g in m.groups())
                    if (cz >= W - 1 and xx + ww >= bw) or (cx <= 0 and xx <= 0):
                        if mirror_repair(dst):
                            repaired.append(i)
            strip_strays(dst)
            cells.append(dst)
            i += 1
    print(f"  {len(cells)} cells at {cw}x{ch}")
    if repaired:
        print(f"  mirror-repaired {len(repaired)} edge-clipped cell(s): "
              + ", ".join(str(r) for r in repaired))
    return cells


def slice_sheet(sheet, cols, rows, key, fuzz, workdir):
    """Crop to a size that divides evenly, slice, and key out the background."""
    w, h = (int(v) for v in magick(sheet, "-format", "%w %h", "info:").split())
    cw, ch = (w // cols) * cols, (h // rows) * rows
    if (cw, ch) != (w, h):
        print(f"  sheet is {w}x{h}, not divisible by {cols}x{rows} - "
              f"cropping to {cw}x{ch}")

    raw = os.path.join(workdir, "raw_%d.png")
    magick(sheet, "-crop", f"{cw}x{ch}+0+0", "+repage",
           "-crop", f"{cols}x{rows}@", "+repage", raw)

    cells = []
    for i in range(cols * rows):
        src = os.path.join(workdir, f"raw_{i}.png")
        dst = os.path.join(workdir, f"keyed_{i}.png")
        magick(src, "-fuzz", f"{fuzz}%", "-transparent", key, dst)
        despill(dst)
        strip_strays(dst)
        cells.append(dst)
    return cells


def probe_fuzz(cell):
    """Report how much of the sprite each fuzz level removes.

    CORRECTED: there is usually no plateau here. On JPEG-compressed art the
    opaque-pixel count was measured falling in a steady ~3-8% step from
    fuzz 10 all the way to fuzz 34, with no cliff to distinguish 'fringe'
    from 'erosion' - a set built at fuzz 35 on that basis had visible holes
    eaten clean through the hair and pant fabric, because -transparent
    matches that colour EVERYWHERE in the image, not just the background,
    and this character's own palette has green-toned regions. Do not chase
    the fringe by raising fuzz - despill() (always applied after keying)
    is what removes it, by recolouring spill-tinted edge pixels rather than
    deleting them. Use this probe only to confirm the SOLID background is
    gone (opaque count roughly flattens once the background itself is
    fully keyed) - pick the lowest fuzz that achieves that, then inspect
    the actual output against a contrasting (not just transparent-checker)
    background before trusting it. mascot_validate.py cannot see colour
    fringing or body erosion - only a rendered look does.
    """
    print("\n  fuzz   opaque px   change")
    prev = None
    for fz in (5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60):
        n = float(magick(cell, "-fuzz", f"{fz}%", "-transparent", ARGS.key,
                         "-alpha", "extract", "-format", "%[fx:mean*w*h]",
                         "info:"))
        delta = "" if prev is None else f"{(n - prev) / prev * 100:+6.1f}%"
        print(f"  {fz:>3}%   {int(n):>9}   {delta}")
        prev = n
    print("\n  Pick the LOWEST fuzz where the background is fully gone - do not\n"
          "  chase remaining fringe by going higher, despill() handles that.\n"
          "  Then look at the actual rendered result, not just this table.\n")


def align(cells, workdir):
    """Re-centre every pose on its body, on a shared canvas and baseline."""
    W, H = (int(v) for v in magick(cells[0], "-format", "%w %h", "info:").split())
    boxes = {}
    for i, c in enumerate(cells):
        bb = body_box(c)
        if bb is None:
            print(f"  cell {i}: no body found - skipping")
            continue
        boxes[i] = bb

    if not boxes:
        die("no usable cells - is the key colour right?")

    # Baseline: the lowest body bottom across the set, so no pose has to
    # move down (and risk pushing an effect off the canvas) to reach it.
    baseline = max(y + h for (w, h, x, y) in boxes.values())
    baseline = min(baseline, H - 2)

    aligned = {}
    for i, (w, h, x, y) in boxes.items():
        dx = round(W / 2 - x - w / 2)
        dy = baseline - (y + h)
        dst = os.path.join(workdir, f"aligned_{i}.png")
        magick("-size", f"{W}x{H}", "xc:none", cells[i],
               "-geometry", f"{dx:+d}{dy:+d}", "-composite", dst)
        aligned[i] = dst

        after = content_box(dst)
        m = re.match(r"(\d+)x(\d+)([+-]\d+)([+-]\d+)", after)
        if m:
            cwid, chei, cx, cy = (int(g) for g in m.groups())
            if cx < 0 or cy < 0 or cx + cwid > W or cy + chei > H:
                print(f"  cell {i}: content clipped by the shift "
                      f"({dx:+d}{dy:+d}) - consider a taller canvas")
    return aligned, W, H, baseline


def build_bob(src, out, W, H, amp, delay):
    """A seamless vertical bob loop from one static pose."""
    with tempfile.TemporaryDirectory() as td:
        frames = []
        for n, off in enumerate(BOB_OFFSETS):
            f = os.path.join(td, f"f{n}.png")
            magick("-size", f"{W}x{H}", "xc:none", src,
                   "-geometry", f"+0{round(off * amp / 3):+d}", "-composite", f)
            frames.append(f)
        magick("-delay", delay, "-loop", "0", *frames, "-strip", out)


def build_dance(src, out, W, H, baseline, sway, rot, bob, delay):
    """A sway-and-lean loop, for states that a facial expression can't carry.

    A pose sheet has no 'dancing' face - the difference has to come from
    movement. One sine cycle of horizontal sway, the body leaning INTO the
    direction of travel, plus a bounce at double frequency so it reads as
    rhythm rather than drifting.

    The lean pivots on the character's feet (the aligned baseline), not the
    image centre: rotating about the middle makes the whole body swing like
    a pendulum from its waist, which looks like falling over rather than
    dancing.
    """
    with tempfile.TemporaryDirectory() as td:
        frames = []
        for n in range(DANCE_FRAMES):
            phase = 2 * math.pi * n / DANCE_FRAMES
            dx = round(sway * math.sin(phase))
            dy = -round(bob * abs(math.sin(phase * 2)))
            angle = rot * math.sin(phase)

            leaned = os.path.join(td, f"r{n}.png")
            magick(src, "-background", "none", "-virtual-pixel", "none",
                   "-distort", "SRT", f"{W / 2},{baseline} {angle}", "+repage", leaned)

            f = os.path.join(td, f"f{n}.png")
            magick("-size", f"{W}x{H}", "xc:none", leaned,
                   "-geometry", f"{dx:+d}{dy:+d}", "-composite", f)

            box = content_box(f)
            m = re.match(r"(\d+)x(\d+)([+-]\d+)([+-]\d+)", box)
            if m:
                cw, ch, cx, cy = (int(g) for g in m.groups())
                if cx <= 0 or cy <= 0 or cx + cw >= W or cy + ch >= H:
                    print(f"    frame {n}: touches the canvas edge - "
                          f"reduce --sway-amp/--rot-amp or use a taller sheet")
            frames.append(f)
        magick("-delay", delay, "-loop", "0", *frames, "-strip", out)


def build_sequence(indices, aligned, out, delay):
    frames = [aligned[i] for i in indices if i in aligned]
    if not frames:
        return False
    magick("-delay", delay, "-loop", "0", *frames, "-strip", out)
    return True


def main():
    global ARGS
    ap = argparse.ArgumentParser(description="Build mascot clips from a sprite sheet.")
    ap.add_argument("sheet")
    ap.add_argument("--grid", default="3x3", help="columns x rows, e.g. 3x3")
    ap.add_argument("--auto-grid", action="store_true",
                    help="detect cell boundaries from background gutters "
                         "instead of assuming --grid is exact")
    ap.add_argument("--contact", metavar="FILE",
                    help="write a numbered contact sheet of every cell and exit")
    ap.add_argument("--no-align", action="store_true",
                    help="skip body re-centring. Required for MOTION sheets: "
                         "re-centring each frame cancels the movement the "
                         "animation is made of, and a limb thrown out to one "
                         "side drags the bounding box with it")
    ap.add_argument("--row", action="append", default=[], metavar="STATE=N",
                    help="build a looping clip from every cell in row N "
                         "(for sheets where one row is one animation)")
    ap.add_argument("--repair-edges", action="store_true",
                    help="rebuild sprites the sheet itself cut off, by "
                         "mirroring them about their axis of symmetry")
    ap.add_argument("--scale", type=int, default=1,
                    help="integer upscale of every cell, nearest-neighbour "
                         "(pixel art only - keeps edges crisp)")
    ap.add_argument("--key", default="#00FF00", help="background colour to remove")
    ap.add_argument("--fuzz", type=int, default=15,
                    help="key tolerance %% (default 15 - keep this LOW, see "
                         "despill() and probe_fuzz's docstring for why)")
    ap.add_argument("--out", help="output directory for the clips")
    ap.add_argument("--assign", action="append", default=[],
                    metavar="STATE=INDEX", help="condition state from one pose (bobs)")
    ap.add_argument("--sequence", action="append", default=[],
                    metavar="STATE=I,J,K", help="reaction state from a pose sequence")
    ap.add_argument("--dance", action="append", default=[],
                    metavar="STATE=INDEX",
                    help="state from one pose, with sway+lean instead of a bob")
    ap.add_argument("--sway-amp", type=int, default=8, help="dance sway in px")
    ap.add_argument("--rot-amp", type=float, default=5.0, help="dance lean in degrees")
    ap.add_argument("--probe-fuzz", action="store_true",
                    help="report erosion per fuzz level and exit")
    ap.add_argument("--bob-amp", type=int, default=3, help="bob height in px")
    ap.add_argument("--delay", default="12", help="frame delay in 1/100s")
    ap.add_argument("--ext", default="webp", help="clip format (default webp)")
    ARGS = ap.parse_args()

    if not shutil.which("magick"):
        die("ImageMagick ('magick') is required and was not found on PATH")
    if not os.path.isfile(ARGS.sheet):
        die(f"no such file: {ARGS.sheet}")

    m = re.fullmatch(r"(\d+)x(\d+)", ARGS.grid)
    if not m:
        die(f"--grid must look like 3x3, got {ARGS.grid!r}")
    cols, rows = int(m.group(1)), int(m.group(2))

    workdir = tempfile.mkdtemp(prefix="mascot_sheet_")
    try:
        if ARGS.auto_grid:
            print(f"\nSlicing {ARGS.sheet} on detected gutters")
            cells = slice_auto(ARGS.sheet, ARGS.key, ARGS.fuzz, workdir)
        else:
            print(f"\nSlicing {ARGS.sheet} as {cols}x{rows}")
            cells = slice_sheet(ARGS.sheet, cols, rows, ARGS.key, ARGS.fuzz, workdir)
            print(f"  {len(cells)} cells")

        if ARGS.probe_fuzz:
            probe_fuzz(os.path.join(workdir, "raw_0.png"))
            return 0

        if ARGS.scale > 1:
            # -filter point, so a 2x upscale duplicates pixels rather than
            # interpolating them. Any smooth filter turns pixel art to mush,
            # and Qt would do exactly that if it had to scale these up to the
            # widget's size at runtime instead.
            print(f"  upscaling {ARGS.scale}x (nearest-neighbour)")
            for c in cells:
                magick(c, "-filter", "point", "-resize", f"{ARGS.scale * 100}%",
                       "+repage", c)

        if ARGS.contact:
            labelled = []
            for i, c in enumerate(cells):
                lab = os.path.join(workdir, f"lab_{i:03d}.png")
                magick(c, "-resize", "150x150", "-background", "rgb(38,38,48)",
                       "-gravity", "center", "-extent", "160x160",
                       "-gravity", "northwest", "-fill", "yellow", "-pointsize", "22",
                       "-annotate", "+6+26", str(i), lab)
                labelled.append(lab)
            per_row = max(1, int(len(cells) ** 0.5 + 0.5))
            magick("montage", *labelled, "-tile", f"{per_row}x", "-geometry", "+3+3",
                   "-background", "rgb(20,20,26)", ARGS.contact)
            print(f"  contact sheet -> {ARGS.contact}")
            return 0

        if not ARGS.out:
            die("--out is required unless --probe-fuzz is given")
        os.makedirs(ARGS.out, exist_ok=True)

        if ARGS.no_align:
            W, H = (int(v) for v in magick(cells[0], "-format", "%w %h", "info:").split())
            aligned = {i: c for i, c in enumerate(cells)}
            baseline = H - 2
            print(f"Alignment skipped - cells used as-is, canvas {W}x{H}")
        else:
            print("Aligning poses on the body")
            aligned, W, H, baseline = align(cells, workdir)
            print(f"  canvas {W}x{H}, baseline y={baseline}, {len(aligned)} poses aligned")

        print("Building clips")
        built = 0
        for spec in ARGS.assign:
            state, _, idx = spec.partition("=")
            if not idx.isdigit() or int(idx) not in aligned:
                print(f"  {state}: no such pose {idx!r} - skipped")
                continue
            out = os.path.join(ARGS.out, f"{state}.{ARGS.ext}")
            build_bob(aligned[int(idx)], out, W, H, ARGS.bob_amp, ARGS.delay)
            print(f"  {state:<10} pose {idx}, {len(BOB_OFFSETS)}-frame bob")
            built += 1

        for spec in ARGS.row:
            state, _, n = spec.partition("=")
            if not n.isdigit():
                print(f"  {state}: bad row {n!r} - skipped")
                continue
            start = int(n) * cols
            idxs = [start + c for c in range(cols) if (start + c) in aligned]
            out = os.path.join(ARGS.out, f"{state}.{ARGS.ext}")
            if build_sequence(idxs, aligned, out, ARGS.delay):
                print(f"  {state:<10} row {n} ({len(idxs)} frames)")
                built += 1

        for spec in ARGS.dance:
            state, _, idx = spec.partition("=")
            if not idx.isdigit() or int(idx) not in aligned:
                print(f"  {state}: no such pose {idx!r} - skipped")
                continue
            out = os.path.join(ARGS.out, f"{state}.{ARGS.ext}")
            build_dance(aligned[int(idx)], out, W, H, baseline,
                        ARGS.sway_amp, ARGS.rot_amp, ARGS.bob_amp, ARGS.delay)
            print(f"  {state:<10} pose {idx}, {DANCE_FRAMES}-frame sway "
                  f"({ARGS.sway_amp}px, {ARGS.rot_amp}deg)")
            built += 1

        for spec in ARGS.sequence:
            state, _, lst = spec.partition("=")
            # Accepts "4,4,2,0" and "40-44", mixed: "72,40-44,72". Ranges
            # matter on motion sheets, where one animation is a contiguous
            # run of frames that rarely lines up with a row.
            idxs = []
            try:
                for part in lst.split(","):
                    if "-" in part.strip("-"):
                        a, b = part.split("-")
                        step = 1 if int(b) >= int(a) else -1
                        idxs.extend(range(int(a), int(b) + step, step))
                    else:
                        idxs.append(int(part))
            except ValueError:
                print(f"  {state}: bad sequence {lst!r} - skipped")
                continue
            out = os.path.join(ARGS.out, f"{state}.{ARGS.ext}")
            if build_sequence(idxs, aligned, out, ARGS.delay):
                print(f"  {state:<10} sequence {lst}, {len(idxs)} frames")
                built += 1

        print(f"\n{built} clip(s) written to {ARGS.out}")
        print("Next: scripts/mascot_validate.py " + ARGS.out)
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
