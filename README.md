# WoW Legends — Player Addon

In-game player toolkit for **[WoW Legends](https://wow-legends.eu)** (WotLK 3.3.5a / AzerothCore). Build and command a party of AI bots, set their roles, run dungeons, tune your own XP rate, manage your personal Companion and opt into Hardcore — every command one click away, with input fields and dropdowns right next to it.

The installable addon lives in **[`WoWLegendsPlayer/`](WoWLegendsPlayer/)**. It shares its look and feel with the **[GM addon](https://github.com/WOWLegendsHQ)** — same left menu + top tabs, same widgets and colours.

> The addon only ever *sends your own commands*. It needs **no special permissions** and never elevates anything.

## Install

1. Copy the **`WoWLegendsPlayer`** folder into your client's AddOns directory:
   ```
   World of Warcraft\Interface\AddOns\WoWLegendsPlayer\
   ```
   The path `…\Interface\AddOns\WoWLegendsPlayer\WoWLegendsPlayer.toc` must exist.
2. Launch the game and enable **WoW Legends Player** on the character-select AddOns screen.
3. Log in. Click the button by the minimap, or type `/wlp` (also `/bots`, `/wlplayer`).

## Two command types (important)

WoW Legends bots are driven by **two** kinds of command, and the addon sends each correctly:

| Type | Prefix | Sent as | Example |
|------|--------|---------|---------|
| **Dot-command** | `.` | chat line | `.xp set 5`, `.companion create orc warrior Grom` |
| **Bot order** | `$` | whisper a bot, or party/raid chat for all your bots | `$follow`, `$attack`, `$talents spec arms` |

A plain (no-`$`) whisper to a bot is **AI chat** — the bot talks back in character, it is *not* an order. The **Bots** tab has a scope selector — *All my bots (party)* or *Targeted bot (whisper)* — so every `$` order goes to the right place.

## Tabs (left menu)

- **★ Companion** — your ONE permanent battle-companion: status, summon/dismiss/forget, and a faction-aware Create row with race and class dropdowns and a name field.
- **Bots** — the PlayerBot command center, with top tabs:
  - **Party** — build your party (`.playerbots bot addclass / add / addaccount / login / remove`), re-gear (`init=auto`) and account-linking.
  - **Roles** — set tank/heal/dps by switching spec (`$talents spec …`), with a spec→role reference.
  - **Combat** — movement & combat orders (`$follow`, `$attack`, `$tank attack`, `$focus heal`, …).
  - **Items** — gear, loot & vendor orders (`$autogear`, `$repair`, `$loot all`, `$roll`, …).
  - **Dungeon** — the guided run flow: gear up → summon in → drive the fight → recover.
- **★ XP Rate** — a 1–10 slider + Apply (`.xp set`), plus view / enable / disable / reset.
- **★ Hardcore** — opt into permadeath (`.hardcore on`, with a loud confirm) and Mak'gora.
- **Favorites** / **History** — pinned commands, and the last commands you sent (click to re-run).

## How to use

| Action | Result |
|---|---|
| **Click** a command | Runs it with the values in the input fields |
| **Enter** in a field | Runs that row |
| **Hover** a command | Shows the exact line, its help, and whether it's your command (.) or a bot order ($) |
| **Shift-click** | Drops the built command into the chat box to edit before sending |
| **Right-click** | Pin / unpin to **Favorites** |
| **Shift-drag** the minimap button | Move the launcher |

A coloured pip on each row shows the kind of command: cyan = your command (`.`), tan = a bot order (`$`), orange ★ = a WoW Legends exclusive (Companion / XP / Hardcore). Destructive actions (remove all bots, forget companion, Mak'gora, Hardcore) ask for confirmation first; Hardcore gets its own permadeath warning. The header shows your current **target**, since several actions fall back to it when a name field is blank.

## Slash commands

`/wlp` (also `/bots`, `/wlplayer`) toggles the panel. Sub-commands: `reset` (recenter panel + button), `show` / `hide`, `debug` (module load status).

## Developer notes

- Panels cover the player and bot commands only — GM-only commands are intentionally excluded.
- Built on the stock 3.3.5a UI API — no external libraries. Shares its widget set and palette with the GM addon so both panels feel like one product.

## Credits

Built for [WoW Legends](https://wow-legends.eu). Runs on [AzerothCore](https://www.azerothcore.org/) and the mod-playerbots project.
