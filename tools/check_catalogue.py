#!/usr/bin/env python3
"""Warband catalogue drift check: Data/WarbandProps.lua vs the server source.

Data/WarbandProps.lua is hardcoded because the server has no query API for the
catalogue, so it can silently rot every time the repack ships. This diffs the
keys the addon offers against the keys the module actually accepts, in both
directions:

  * in cpp, not in addon  -> new content the dropdowns do not offer yet
  * in addon, not in cpp  -> a key the server will refuse with "There is no 'X'"

Both tables are read: g_props (scenery) and g_npcCatalogue (camp staff, v1.6.0)
- they share the `.camp place <key>` command, so from the addon's side they are
one list.

Run it after every repack release. Exit 0 = no drift.

    python tools/check_catalogue.py [path-to-wowlegends_warbandcamp.cpp]
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LUA = os.path.join(HERE, "..", "WoWLegendsPlayer", "Data", "WarbandProps.lua")
CPP_DEFAULT = r"W:\WOWLegends\core\modules\mod-wowlegends\src\wowlegends_warbandcamp.cpp"


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def main():
    cpp_path = sys.argv[1] if len(sys.argv) > 1 else CPP_DEFAULT
    if not os.path.exists(cpp_path):
        print("server source not found: %s" % cpp_path)
        print("(pass the path to wowlegends_warbandcamp.cpp as the first argument)")
        return 2

    # Both catalogue tables start their rows { "key", <number>, "Label", ...
    cpp_keys = [m[0] for m in re.findall(
        r'^\s*\{\s*"([a-z0-9_-]+)",\s*(\d+),\s*"([^"]*)"', read(cpp_path), re.M)]
    # The addon stores { "key", "Label" } pairs.
    lua_keys = [k for k, _ in re.findall(
        r'\{\s*"([a-z0-9_-]+)",\s*"([^"]+)"\s*\}', read(LUA))]

    missing = sorted(set(cpp_keys) - set(lua_keys))   # server has it, we don't offer it
    stale = sorted(set(lua_keys) - set(cpp_keys))     # we offer it, server refuses it

    print("server keys : %d" % len(cpp_keys))
    print("addon keys  : %d" % len(lua_keys))
    if missing:
        print("MISSING from the addon : %s" % ", ".join(missing))
    if stale:
        print("STALE in the addon     : %s" % ", ".join(stale))

    if missing or stale:
        print("\nCATALOGUE DRIFT: FAIL")
        return 1
    print("\nCATALOGUE DRIFT: NONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
