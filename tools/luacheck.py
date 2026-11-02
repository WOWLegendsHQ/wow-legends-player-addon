#!/usr/bin/env python3
"""Validate every addon Lua file parses as Lua 5.1 (WoW's version), and that no
DISPLAYED string carries a non-ASCII character.

The second check exists because of a real escape: four em-dashes sat inside
quoted strings through v0.2.0 and rendered in-game as "?" - the WotLK 3.3.5a
client font has no glyph for them. Comments are free to use whatever they like
(and this file's neighbours do), so the sweep looks only at string literals,
which is where the damage happens.

    pip install luaparser
    python tools/luacheck.py            # checks ../WoWLegendsPlayer
    python tools/luacheck.py <dir>      # checks a specific directory
"""
import sys, glob, os, re
from luaparser import ast

HERE = os.path.dirname(os.path.abspath(__file__))
root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "WoWLegendsPlayer")

# Quoted Lua strings ('...' / "..."), backslash escapes respected. Long-bracket
# strings ([[...]]) are matched separately.
STRINGS = re.compile(r'"((?:[^"\\\n]|\\.)*)"' r"|'((?:[^'\\\n]|\\.)*)'", re.M)
LONG_STRINGS = re.compile(r"\[(=*)\[(.*?)\]\1\]", re.S)


def non_ascii_strings(src):
    """[(line, text)] for every string literal holding a non-ASCII character."""
    out = []
    for m in STRINGS.finditer(src):
        text = m.group(1) if m.group(1) is not None else m.group(2)
        if text and any(ord(ch) > 127 for ch in text):
            out.append((src.count("\n", 0, m.start()) + 1, text.strip()))
    for m in LONG_STRINGS.finditer(src):
        if any(ord(ch) > 127 for ch in m.group(2)):
            out.append((src.count("\n", 0, m.start()) + 1, m.group(2).strip()[:60]))
    return out


files = sorted(glob.glob(os.path.join(root, "**", "*.lua"), recursive=True))
bad = 0
nonascii = 0
for f in files:
    rel = os.path.relpath(f, root)
    src = open(f, "r", encoding="utf-8").read()
    try:
        ast.parse(src)
    except Exception as e:
        bad += 1
        print("FAIL " + rel + "  -> " + (str(e).splitlines() or [""])[0])
        continue

    hits = non_ascii_strings(src)
    if hits:
        nonascii += len(hits)
        print("FONT " + rel)
        for line, text in hits:
            print("       line %d: %s" % (line, text))
    else:
        print("OK   " + rel)

print("\n%d file(s), %d failed" % (len(files), bad))
if nonascii:
    print("%d displayed string(s) with non-ASCII characters - they render as '?' "
          "in the WotLK client font." % nonascii)

# The App compares the installed TOC's `## Version` with the latest release tag
# (agreed with the app desk 2026-11-02), so it must be plain X.Y.Z - no "-beta",
# no "v", no fourth number - and the release tag is "v" + exactly this string.
version_bad = False
tocs = glob.glob(os.path.join(root, "*.toc"))
for toc in tocs:
    m = re.search(r"^## Version:\s*(.*?)\s*$", open(toc, encoding="utf-8").read(), re.M)
    ver = m.group(1) if m else None
    if not ver or not re.fullmatch(r"\d+\.\d+\.\d+", ver):
        version_bad = True
        print("VERSION %s: '## Version: %s' must be plain X.Y.Z (the App compares it with the "
              "release tag vX.Y.Z)" % (os.path.basename(toc), ver))
    else:
        print("version %s (release tag must be v%s)" % (ver, ver))

sys.exit(1 if (bad or nonascii or version_bad) else 0)
