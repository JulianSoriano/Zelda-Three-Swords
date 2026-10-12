# Zelda Three Swords

A ROM hack of the original NES **The Legend of Zelda** (USA, Rev 1) featuring CPU-controlled
**Red Link** and **Blue Link** to help assist the player. They fly in a V formation behind
you, fight everything in the room with your sword, sword beams and free arrows, bomb
breakable walls for you, and can never hurt you or be hurt.

> **No ROM is included.** This repository contains an IPS patch and the 6502 source only.
> You need your own copy of the original game.

---

## Quick start

1. Get a copy of **Legend of Zelda, The (USA) (Rev 1)** in iNES format (131,088 bytes,
   including the 16-byte header). Check it before patching:

   | | |
   |---|---|
   | CRC32 | `02bb0c56` |
   | MD5 | `f4095791987351be68674a9355b266bc` |
   | SHA-1 | `3701381a82fc7d52b2dd3e8892047b30a114ab43` |

2. Apply [`patch/Zelda Three Swords Mod Final.ips`](patch/) with any IPS patcher
   (Floating IPS, Lunar IPS, RomPatcher.js, …).
3. Load the patched ROM in any NES emulator or flash cart. Your existing save files work.

## What you get

### The partners
| | |
|---|---|
| **V formation** | With nothing to fight they fly back-left and back-right of the way you face. Where that spot is inside a wall (corridors, doorways) they fall in line behind you on your path, and form the V again when there is room. When you stop, they stop. |
| **Aggressive fighting** | Each partner goes for the nearest monster anywhere in the room; the two split up over different targets and only switch when another monster is clearly nearer. |
| **Your sword** | Wooden, white or magical, with its damage. At full health they fire sword beams. |
| **Unlimited arrows** | Monsters lined up but out of sword reach get an arrow, even if you have no bow or arrows, at no rupee cost (wooden damage, silver if you own the silver arrow). |
| **No swinging at the air** | When they can't shoot (crowded room, weapon already out) they walk up instead; they don't swing at a monster that is still reeling from a hit, and they leave flying peahats alone until they land. |
| **Walking round obstacles** | Blocks, rocks and trees are walked around instead of pushed into. Boxed in, they wait rather than shuffle. A monster they can't reach is left alone for a few seconds. |
| **Wall bombing** | If you own at least one bomb and nothing needs fighting, one partner bombs each bombable dungeon wall in the room, and the rock walls that hide caves on the overworld. Free. |
| **Invincible and harmless** | They can't be hurt, monsters ignore them, and nothing they do can hurt you. Their kills count normally (drops, shutter doors, room clears). They leave the people in caves alone and don't pick up items. |

### Title screen
The title screen now reads "THREE SWORDS ROM HACK / BY RAMENPHOLIFE" inside the frame.

### Game changes
- A new save file starts with **255 rupees**.
- Monsters do **double damage** to you (rings still halve / quarter it).

### Menus
| Screen | Controls |
|---|---|
| File select | **Up/Down** move the heart, **A** (or Start) chooses. |
| Register your name | D-pad picks a letter, **A** types it, **B** erases the last letter, **Start** saves and returns from anywhere. |
| Elimination mode | **Up/Down** move the heart, **A** erases the chosen file (or leaves on END), **B** returns to the file select. |

Select still works everywhere as in the original. Also fixed: the original game's
register-screen bug that wrote the name cursor's position into the heart cursor's sprite, and a
bug in v2/v3 where a stray flag in uninitialised memory could bounce you straight back out of
the register screen and leave the heart cursor mispositioned.

### Performance
The partners stick to their swords in crowded rooms to keep the game at full speed; in the
busiest rooms tested, slowdown stays around 0.1–0.6 % of frames.

### Limits
- Eight sprites per scanline: as in the original game, sprites flicker when many are in a row.
- Partners' sword beams vanish on impact instead of splitting.
- Bosses with special weak points (Dodongo, Digdogger, Gohma's eye, Ganon) still need you.
- Emulator save-states made with older versions won't load.

## Building from source

Requirements: **cc65** (`ca65` + `ld65`) and **Python 3**.

```sh
# put the original ROM in the repository root, named exactly:
#   "Legend of Zelda, The (USA) (Rev 1).nes"
cd src
python3 build.py              # -> src/out/Zelda_Three_Swords_Mod.nes
# or: python3 build.py path/to/original.nes path/to/output.nes
# (set CC65_HOME if ca65 isn't on your PATH)
```

The build is byte-identical to the ROM the IPS patch produces.

## Documentation

- [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) — technical breakdown: memory map, every
  code patch, how a partner is simulated with the game's own weapon code, and the AI.
- [CHANGELOG.md](CHANGELOG.md) — what changed in each version and how it was tested.

## Repository layout

```
patch/        IPS patch for Legend of Zelda (USA) (Rev 1)
src/          clones.s     the partners: hooks, AI, drawing, weapon handling (6502)
              menu.s       the file-select / register / elimination controls
              clones.cfg   ld65 memory layout (which free ROM space each part uses)
              build.py     assembles and patches the original ROM
              gen_xchg.py  generates the slot-exchange routines (run by build.py)
              game.inc     addresses of the game routines the mod calls (Rev 1)
              targets.inc  which monster types the partners attack
              tools/       regenerate game.inc from the Zelda 1 disassembly
docs/         technical write-up
```

## Credits

Mod by **RamenPhoLife**. The Legend of Zelda © Nintendo 1986.
Game routine and variable names come from the community
[Zelda 1 disassembly](https://github.com/aldonunez/zelda1-disassembly).
This is an unofficial fan modification and is not affiliated with or endorsed by Nintendo.
