# WoW Legends — Complete Player Command Reference (for the Player Addon)

## ▶ Start here — prompt for the addon build

**Read this whole file, then build the _WoW Legends Player Addon_.**

**What it is:** an in-game addon for **World of Warcraft 3.3.5a (WotLK)** that gives players a clean, friendly panel to do everything in this file *without typing commands* — build a party of AI bots, summon them, set their roles, run dungeons, change their own XP rate, manage their personal Companion, and opt into Hardcore.

**Your goal:** the **nicest, cleanest, best-organized** player addon you can make — intuitive, good-looking, minimal clicks, WoW-native feel. Every control simply sends one of the chat commands documented below; the addon needs **no special permissions** (it only ever sends the player's own commands).

**Design principles:**
- A tidy, tabbed/sectioned window organized by what players *do*: **Party · Roles · Combat · Dungeon · XP · Companion · Hardcore**.
- Clear icons, helpful tooltips, sensible defaults; **confirm destructive actions** (Hardcore is permanent!).
- Target **WoW 3.3.5a (WotLK) — client build 12340**: `.toc` header `## Interface: 30300`, Lua 5.1 + XML, the WotLK FrameXML API only (no retail/modern API).
- Implementation is just chat: **dot-commands** (`.xp set 5`) go to the server; **bot orders** (`$follow`, `$summon`) go to **whisper** (one bot) or **party/raid** chat (all your bots).
- **Testing the commands:** the live realm's Remote Access is wired to the **wow-legends MCP** — use `ra_command` to run dot-commands against the running server and verify their behaviour/output (e.g. `.xp view`, `.companion`, `.playerbots bot list`). The `$` bot orders are in-world chat, so test those on a character in-game.

The complete, source-verified command spec follows — build the UI around it. The "Addon-builder notes" (§9) suggest a panel layout.

---

Every command a **regular player** can use — building & commanding bots, summoning, XP rate, companion, hardcore/Mak'gora. Source-verified against v1.1.0 (2026-06-29). **GM-only commands are intentionally excluded** (no `.worldpvp`, `.wlevent`, `.gear`, `initself`, debug, etc.).

---

## 0. The TWO command types (read first)

| Type | Prefix | Where typed | Example |
|------|--------|-------------|---------|
| **Dot-command** | `.` | any chat box (like a slash command) | `.companion summon`, `.xp set 5` |
| **Bot order** | **`$`** | **whisper a bot**, or **say in party/raid chat** | `$follow`, `$summon`, `$talents spec arms` |

**⚠️ Bot orders need the `$` prefix.**
- A **plain whisper** to a bot (no `$`) → that's **AI chat**: the bot talks back in character. It is **not** an order.
- A **`$`-prefixed** message (whisper, or party/raid chat) → is an **order** (the `$` is stripped, the rest runs).
- Whisper `$cmd` → only that bot acts. Say `$cmd` in **party/raid** → all your bots act (silently).
- Chain commands in one message with the configured separator; add a reply-channel prefix (`#w #p #r #a #g`) right after the `$` to force where the bot replies.

So the addon sends **`.` commands to the chat box** and **bot orders as `$cmd` to whisper or party chat**. Tables below show the bare word — send it as `$word`.

---

## 1. Build your party — `.playerbots bot ...`
(There is no bare `.bot` alias — always `.playerbots bot ...`.)

| Command | What it does |
|---------|--------------|
| `.playerbots bot list` | Your bots: online (`+`), your offline alts (`-`), randoms in your group. |
| `.playerbots bot addclass <class> [male\|female]` | Summon a fresh, pre-geared **disposable** class bot of your faction — the fastest way to fill a party. Classes in §8.1. (DK needs you to meet the heroic level requirement.) |
| `.playerbots bot lookup` | List the classes available for `addclass`. |
| `.playerbots bot add <Name[,Name2,...]>` | Add **your own** character(s) as bots (you become their master). No name = current target. Their progress **persists** (great for long playthroughs). |
| `.playerbots bot addaccount <Account\|CharName>` | Add **all** characters on your account as bots at once. |
| `.playerbots bot login <Name>` | Bring one of your offline bots online. |
| `.playerbots bot remove <Name>` | Remove/log out one of your bots. Aliases: `logout`, `rm`. |

> **addclass vs your own alts:** addclass bots are shared, disposable pool characters — perfect for *quickly forming a party*, they don't persist. Adding **your own** characters (`add`/`addaccount`) puts your real, persistent chars under bot control — best for a long-term personal party.

### Re-gear / refresh (addclass bots only)
| Command | What it does |
|---------|--------------|
| `.playerbots bot init=auto <Name\|*>` | Re-gear addclass bot(s) scaled to **your** gear. `*` = all bots in your group. *(`init=auto` is the player option; specific quality tiers may be restricted to GMs depending on the server's `AutoInitOnly` setting.)* |
| `.playerbots bot levelup` | Re-roll the bot at its current level. |
| `.playerbots bot refresh` | Re-roll its consumables/gear. |
| `.playerbots bot random` | Full re-randomize. |
| `.playerbots bot quests` | Initialize its instance quests. |

### Control a trusted friend's characters — `.playerbots account ...`
The **only** legitimate way to command someone else's characters (friending does **not** grant control). Needs the server's `AllowTrustedAccountBots` enabled.

| Command | What it does |
|---------|--------------|
| `.playerbots account setKey <key>` | Set a security key on your account so a friend can link to it. |
| `.playerbots account link <account> <key>` | Link your account to a friend's using their key → you can add their characters as bots. |
| `.playerbots account linkedAccounts` | List accounts linked to yours. |
| `.playerbots account unlink <account>` | Remove a link. |

> **Who can command a bot:** only its **master** (whoever added it). Friending a bot does *not* let you command it. A few "unsecured" orders any nearby player may give any bot: `$who $wts $sendmail $invite $leave $lfg $pvp stats $rpg status`.

---

## 2. Command your bots (bot orders — `$`)
Prefix every word below with `$`. Whisper one bot, or say it in party/raid for all your bots.

### Movement & positioning
| Cmd | Effect | | Cmd | Effect |
|---|---|---|---|---|
| `follow` | follow you | | `stay` | hold position |
| `flee` | fall back / flee | | `runaway` | run from the group |
| `grind` | resume roaming/grinding | | `move from group` | spread away |
| `disperse` | spread out | | `summon` | pull bot(s) to you (dungeons) |
| `home` | set/return home | | `go <where>` | travel to a place/coords |
| `position [set]` | report/set formation pos | | `formation <name>` | set group formation |
| `taxi` | take a flight path | | `teleport` | teleport (e.g. to you) |
| `enter vehicle` / `leave vehicle` | mount/dismount a vehicle | | | |

### Combat
| Cmd | Effect |
|---|---|
| `attack` | attack your current target |
| `pull` | pull your target (`pull back`, `pull rti` variants) |
| `tank attack` | the tank engages your target |
| `max dps` | switch to maximum-DPS posture |
| `cast <spell> [target]` | cast a named spell (`castnc <spell>` = non-combat) |
| `focus heal [targets]` | tell a healer which target(s) to prioritize |
| `save mana` / `drink` | conserve / restore mana |
| `rti [icon]` | set/report the raid-target icon the bot focuses |
| `rtsc` | real-time click control of the bot |
| `stance <name>` | warrior/druid stance or form |
| `cancel <form>` | druid: drop a form (tree/travel/bear/dire bear/cat/moonkin/aquatic) |
| `naxx` / `bwl` | apply a Naxxramas / Blackwing Lair combat preset |
| *(info, whisper)* | `dps`, `target`, `attackers`, `spell [name]`, `spells`, `ss` |

### Pets
`tame [pet]` (hunter) · `pet` (manage/summon) · `pet attack`

### Gear & items (whisper)
| Cmd | Effect | | Cmd | Effect |
|---|---|---|---|---|
| `equip <item>` / `e` | equip linked item | | `unequip <item>` / `ue` | take it off |
| `autogear` | best available | | `autogear bis` | best-in-slot |
| `equip upgrade` | equip inventory upgrades | | `use <item>` / `u` | use/consume |
| `open items` / `unlock items` | open lockboxes | | `destroy <item>` | destroy |
| `repair` | repair gear | | `craft <recipe>` | craft a recipe |
| `c [item]` / `items` / `inv` | report inventory | | `maintenance` | repair/sell housekeeping |

### Loot, trade, money, mail
| Cmd | Effect | | Cmd | Effect |
|---|---|---|---|---|
| `add all loot` / `loot all` | loot nearby (party ok) | | `ll` | loot strategy/list |
| `roll <pass\|need\|greed>` | loot-roll behaviour (party ok) | | `trade [item]` / `t` | trade |
| `nt [item]` | exclude from auto-trade | | `sell <item>` / `s` | sell to vendor |
| `buy <item>` / `b` | buy from vendor | | `reward <quest>` / `r` | choose quest reward |
| `wts [item]` | "want to sell" | | `bank` | bank deposit/withdraw |
| `gb` / `gbank` | guild bank | | `mail` / `sendmail <x>` | read / send mail to you |
| `emblems` | report badge currency | | | |

### Quests
`accept [quest]` · `talk` (turn in) · `quests` · `q [item/quest]` · `qi [item]` · `drop [quest]` · `share [quest]` · `clean quest log` · `rpg status` / `rpg do quest`

### Info & buffs (whisper)
`stats` · `who` · `rep`/`reputation` · `pvp stats` · `los` · `aura` · `range [v]`/`ra` · `buff [class]` · `glyphs` / `glyph equip` / `remove glyph`

### Group & guild
`invite` · `join` · `leave` · `give leader` · `lfg` · `ginvite` · `guild promote`/`demote`/`remove`/`leave`

### Death & recovery
`release` (corpse run) · `revive` (spirit healer)

### Utility
`help` (bot whispers its full command list) · `reset` / `reset botAI` · `chat` · `emote` · `calc <item>` · `wipe` / `ready` · `trainer`

> Plain (non-`$`) whispers feed the bot's **AI chat** / small-talk, not commands. `hire`, and `logout`/`wait` as bot orders, are disabled in this build.

---

## 3. Roles & specs (bot orders — `$talents ...`)
A bot's **dungeon role (tank/heal/dps) = its spec.** Set roles by changing spec.

| Command | What it does |
|---|---|
| `$talents` | Report current spec + help. |
| `$talents spec list` | List the class's premade specs. |
| `$talents spec <name>` | Switch spec — **this sets tank/heal/dps**. Names in §8.2. |
| `$talents switch <1\|2>` | Activate primary/secondary dual-spec. |
| `$talents autopick` | Auto-pick a full tree for the level. |
| `$talents apply <link>` | Apply a specific talent link. |

**Spec → role:** Tank = Protection (warrior/paladin) · Blood (DK) · Feral *(druid, needs Thick Hide)*. Heal = Holy/Discipline (priest/paladin) · Restoration (druid/shaman). Everything else = DPS.

**Strategy toggles (advanced):** `$co <list>` (combat) · `$nc <list>` (non-combat) · `$de <list>` (dead). `<list>` = `+name` add / `-name` remove / `~name` toggle / `?` list / `!` reset. e.g. `$co +heal,-flee`.

---

## 4. Dungeons & summoning
**The Dungeon Finder won't drag your bots into the instance** — use `$summon`.

**Flow:** 1) build your party (`.playerbots bot addclass ...` / `add`), 2) set roles (`$talents spec <name>` — get a tank, healer, dps), 3) gear if needed (`.playerbots bot init=auto *`), 4) walk into the dungeon, 5) say **`$summon`** in party chat → your whole party teleports in, 6) drive the fight (`$tank attack`, `$attack`, `$focus heal`).

> *(v1.1: on this realm bots also **auto-summon** into a dungeon a few seconds after the group leader zones in — so step 5 is often automatic. `$summon` is the manual backup.)*

---

## 5. XP rate — `.xp ...`
Set your **own** leveling speed. Range: **1 up to the server max (default 10)**; default rate is 1 (Blizzlike).

| Command | What it does |
|---|---|
| `.xp view` | Show your current XP rate and the server maximum. |
| `.xp set <rate>` | Set your XP rate (e.g. `.xp set 5`). Capped at the server max (default 10). |
| `.xp enable` | Turn your custom rate on. |
| `.xp disable` | Turn it off (back to the realm default). |
| `.xp default` | Reset to the default rate. |

*(For the addon: a 1–10 slider + Apply → `.xp set <value>`, with `.xp view` to read the current value and cap.)*

---

## 6. Your Companion — `.companion ...`
One permanent personal battle-companion, bound to you, that fights at your side and remembers you in chat.

| Command | What it does |
|---|---|
| `.companion` | Show your companion's status (or help if you have none). |
| `.companion create <race> <class> <name>` | Claim your one companion. Race must match your faction (§8.3); name 2–12 letters, unique. e.g. `.companion create orc warrior Grommash`. |
| `.companion summon` | Recall it to your side. |
| `.companion dismiss` | Send it away (recall later with `summon`). |
| `.companion forget` | Permanently release it (frees it so you can make a new one). |

Once out, command it like any bot (`$follow`, `$attack`, `$talents spec <name>`, …).

---

## 7. Hardcore & Mak'gora — `.hardcore` / `.makgora`
| Command | What it does |
|---|---|
| `.hardcore on` | Opt this character into **permadeath**. **Level 1 only, irreversible.** Confirm by typing it **twice within 30s** (or use the Herald of the Fallen NPC). |
| `.hardcore status` | Show your state: FALLEN / ACTIVE / normal. |
| `.makgora` | Duel **to the death** with your targeted player. Both must be hardcore, target each other, and **both type `.makgora`**; the next duel within 30s is lethal, the loser falls forever. (Normal duels never kill.) |

---

## 8. Option reference (for dropdowns)

### 8.1 Classes — `addclass` & `.companion create`
`warrior` · `paladin` · `hunter` · `rogue` · `priest` · `dk` · `shaman` · `mage` · `warlock` · `druid`

### 8.2 Specs per class — `$talents spec <name>`
| Class | Specs |
|---|---|
| Warrior | arms, fury, protection |
| Paladin | holy, protection, retribution |
| Hunter | beast mastery, marksmanship, survival |
| Rogue | assasination *(one 's')*, combat, subtlety |
| Priest | discipline, holy, shadow |
| Death Knight | blood, frost, unholy |
| Shaman | elemental, enhancement, restoration |
| Mage | arcane, fire, frost |
| Warlock | affliction, demonology, destruction |
| Druid | balance, feral combat, restoration |

### 8.3 Companion races — must match your faction
- **Alliance:** human · dwarf · nightelf · gnome · draenei
- **Horde:** orc · undead · tauren · troll · bloodelf

---

## 9. Addon-builder notes
- **Dot-commands** (`.`) → send to the chat edit box verbatim.
- **Bot orders** (`$`) → send to **whisper** (one bot) or **PARTY/RAID chat** (all your bots). Never send a bot order without `$` — it'd post as normal chat / go to AI chat.
- Suggested panels:
  - **Party builder** — a button per class (`.playerbots bot addclass <class>`) + "Summon all" → party `$summon`.
  - **Role setter** — per-bot dropdown that whispers `$talents spec <name>` (auto-pick tank/heal/dps by class via §3).
  - **Combat bar** — `$attack` · `$tank attack` · `$pull` · `$max dps` · `$flee` · `$focus heal`.
  - **Utility bar** — `$follow` · `$stay` · `$summon` · `$repair` · `$autogear` · `$revive`.
  - **XP** — 1–10 slider → `.xp set <n>`, `.xp view` to read, enable/disable toggle.
  - **Companion** — `.companion summon/dismiss/forget` + a create form (race/class/name from §8).
  - **Hardcore** — `.hardcore on` (with a clear "permanent!" confirm) + `.makgora`.
- Everything here is the player's own command access — the addon needs **no special permissions**; it just sends the exact text shown.
