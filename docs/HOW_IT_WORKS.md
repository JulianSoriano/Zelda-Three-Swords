# How Zelda Three Swords works

This is a technical tour of the mod for anyone who wants to read or change the source
(`src/clones.s`, `src/menu.s`). Addresses are for **Legend of Zelda (USA) (Rev 1)**; routine and
variable names follow the [Zelda 1 disassembly](https://github.com/aldonunez/zelda1-disassembly).

1. [The big idea](#1-the-big-idea)
2. [Where the code lives](#2-where-the-code-lives)
3. [Every patch to the original code](#3-every-patch-to-the-original-code)
4. [RAM used by the mod](#4-ram-used-by-the-mod)
5. [One frame of the partners](#5-one-frame-of-the-partners)
6. [Weapons: borrowing the game's own code](#6-weapons-borrowing-the-games-own-code)
7. [Hitting monsters](#7-hitting-monsters)
8. [Drawing](#8-drawing)
9. [The AI](#9-the-ai)
10. [Movement and obstacles](#10-movement-and-obstacles)
11. [Breakable walls](#11-breakable-walls)
12. [CPU budget](#12-cpu-budget)
13. [Game changes and menus](#13-game-changes-and-menus)

---

## 1. The big idea

Zelda keeps everything in *object slots*: slot 0 is Link, slots 1–11 are monsters, and slots
$0D–$12 are Link's weapons (sword $0D, sword beam $0E, boomerang $0F, bombs/fire $10–$11,
arrow/rod $12). Each slot is a column across a dozen parallel arrays (`ObjX`, `ObjY`, `ObjDir`,
`ObjState`, …).

A partner is not a new kind of object. Each partner owns a private copy of the **Link
context** — slot 0 plus the weapon slots — stored in battery RAM. When a partner needs to throw
a sword beam, fire an arrow or drop a bomb, its context is **swapped into the real slots**, the
game's own `WieldArrow` / `UpdateRodOrArrow` / `UpdateBombOrFire` code runs exactly as it would
for Link, and the context is swapped back out. That way every weapon behaves, collides and
damages exactly like the original, and the mod never reimplements a weapon.

The cheap things — walking, the sword swing, drawing — are done by the mod directly on the
stored context, because swapping costs CPU time.

## 2. Where the code lives

All new code goes into space the original ROM leaves unused (filled with `$FF`), so nothing of
the game is removed. `clones.cfg` lists the regions:

| Segment | Where | Size used | What |
|---|---|---|---|
| `B3CODE` | bank 0, `$A000-$BF4F` | ~6.7 KB of 8 KB | per-frame partner logic, AI, drawing |
| `B4CODE` | bank 4, `$B470` | ~0.8 KB | collision of partner weapons with monsters |
| `B1CODE` | bank 1, `$B770` | ~40 B | power-on init |
| `B2CODE` | bank 2, `$AFA0` | ~0.3 KB | menu controls |
| `WSTUB` | WRAM `$7EE1` | 26 B | two small hooks in the filler at the end of the common code the game copies to WRAM |
| `FARCALL` | WRAM `$7FE7` | 21 B | bank-switching trampoline, copied there at power-on |
| (inline) | bank 2 `$AF90`, bank 7 `$FF42` | a few bytes | rupee and damage stubs |

The game runs on MMC1 with a fixed bank 7 at `$C000` and one switchable bank at `$8000`.
`FarCall` lets the partner code (bank 0) call a routine in another bank and come back:
`FAR bank, routine` is a macro that sets the target and calls `$7FE7`, which maps the bank,
calls the routine, re-maps bank 0 and returns with X, Y, A and the flags intact.

## 3. Every patch to the original code

| Where | Original | Patched to | Why |
|---|---|---|---|
| bank 7 `$ECB7` | `LDX #$12 / JSR UpdateRodOrArrow` | `JSR MainHook / NOP / NOP` | once per frame, after the player's weapons update: run the partners (`MainHook` re-does the replaced call, maps bank 0 and jumps to `CloneMain`) |
| bank 7 `$E901` | `JSR CopyCommonCodeToRam` | `JSR MyInit` | at power-on, also copy `FarCall` into WRAM and force a partner reset |
| WRAM `$79FD` (bank 1 code) | `JSR CheckLinkCollision` in `CheckMonsterCollisions` | `JSR PostCheck` | after the game checks a monster against Link's weapons, check it against the partners' weapons too |
| bank 4 `$A061` | `JSR CheckLinkCollision` (Wizzrobe) | `JSR WizzHook` | Wizzrobes run their own collision path |
| WRAM `$7B5B` (`Link_BeHarmed`) | `LDY InvRing` | `JSR` stub at bank 7 `$FF42` | double the damage (`ASL $0E / ROL $0D`) before the ring loop |
| bank 2 `$9F49` | `LDY #$25 / LDA #$08 / STA ($C0),Y` | `JSR` stub at bank 2 `$B200` | when a new file is registered, also set its rupees to 255, and its keys to 9 |
| bank 4 `$98AF` | `JSR Dodongo_CheckBombHit` (`UpdateDodongo`) | `JSR DodoBombHook` | a partner's bomb feeds / stuns a Dodongo, not only the player's |
| bank 5 `$B68D`, bank 4 `$B1EA` | `LDA CurLevel / BEQ` at the start of `IsDarkRoom` | `JMP` to a copy in free space (`$B8A0` / `$BA00`) | a dark room counts as lit while Link owns a candle (the level's boss room stays dark) |
| bank 1 `$8000-$85A1`, `$B7A0` | NPC string table and strings | rewritten block (`hints.py`) | clearer NPC text; strings that don't fit the old block move to free space after the bank 1 code |
| bank 2 `$A59A` | `LDA ButtonsPressed / AND #$10` | `JSR MenuMode1 / NOP` | file-select controls |
| bank 2 `$9EF0` | `LDA ButtonsPressed / AND #$10` | `JSR MenuModeE / NOP` | register-name controls |
| bank 2 `$9FC5` | `LDA ButtonsPressed / CMP #$10` | `JSR MenuModeF / NOP` | elimination controls |
| bank 2 `$A236` | `STA $0200` | `STA $0204` | original bug: the name cursor's Y was written into the heart's sprite |

`build.py` checks the original bytes before every patch, so the build fails loudly on a
different ROM revision.

## 4. RAM used by the mod

| Range | What |
|---|---|
| `$0110-$01B6` | partner state and scratch (the low end of the stack page, which the game never reaches). Per-partner arrays (`CL_MODE`, `CL_TGT`, `CL_STUCK`, cooldowns, weapon masks, …), the player's trail, wall-bombing state. |
| `$7F00-$7F99` | the two partner contexts, 77 bytes each (11 slot arrays × 7 slots: 0 and $0D-$12) |
| `$7FA0-$7FAB` | navigation: detour state, "player standing still" counter, unreachable-monster memory |
| `$7FE7-$7FFB` | `FarCall` |

The code was written for up to three partners; `NCL = 2` in `clones.s` sets how many run (the
third context's space now holds the navigation state).

## 5. One frame of the partners

`CloneMain` runs once per frame in play modes (overworld, dungeon, cellar, cave):

1. **Reset check** — new room, new mode or the player jumped more than 32 px (a warp): the
   partners are placed on the player and their state cleared.
2. **Trail** — the player's position is recorded into a 16-entry ring buffer whenever he moves
   4 px; partners walk this trail when they can't use their formation spot.
3. **Timers** — the NMI only counts down the real slots' timers, so bomb fuses and fire in the
   stored contexts are counted down here.
4. **Crowd level** — `HEAVY` = number of objects in the room; it gates the expensive work
   (see [CPU budget](#12-cpu-budget)).
5. **Thinker** — only one partner runs its AI (`Think`) per frame; the other *coasts*,
   repeating its last step. In very crowded rooms nobody thinks on odd frames.
6. **Each partner** (`ProcessClone`): load its slot-0 data into working variables, think or
   coast, advance the sword swing, start any wanted beam / arrow / bomb, then either draw it
   directly (`FastDraw`) or, if a weapon is out, go through the slow path (`Slow`) that swaps
   the context in and runs the game's weapon code.

Player values the weapon code may disturb (input direction, invincibility timer, bomb count,
rupees-to-subtract, sound requests, …) are saved before the first swap and restored after the
last, which is why the partners' bombs and arrows are free.

## 6. Weapons: borrowing the game's own code

- **Sword** — the mod runs a 12-frame swing itself. While the blade is out it writes a sword
  object into the partner's slot-$0D context so the collision code (below) can hit with it.
  Damage follows the player's sword.
- **Sword beam** — at the end of a swing, at full health, `MakeSwordShot` runs on the partner's
  context; `UpdateSwordShotOrMagicShot` moves it each frame. (Partner beams vanish on impact
  instead of splitting into four, which saves a lot of CPU.)
- **Arrows** — `UseArrow` temporarily gives the player a bow and a rupee, calls `WieldArrow`, and
  restores both. While a partner's arrow flies, `InvArrow` is forced to at least 1 so the arrow
  gets wooden damage and a valid palette when the player has none.
- **Bombs** — `WieldBomb` on the partner's context; used for breakable walls.

## 7. Hitting monsters

The game checks each monster against Link's weapons in `CheckMonsterCollisions` (bank 4). The
`PostCheck` hook then calls `CloneHits`, which runs the same checks against each partner's
weapons: the blade with an exact test matching `CheckMonsterStabbingCollision`, and the other
weapons by swapping that partner's weapon slots in and calling the game's own
`CheckMonster…Collision` routines. Kills therefore drop items, open shutters and count toward
room clears exactly like the player's.

Monsters never target or touch the partners: they are not objects the game knows about.

## 8. Drawing

`FastDraw` picks the partner's walking or attack frame, uses Link's tiles with sprite palette 2
(red, borrowed from red monsters) or 1 (blue), and takes sprite records from the game's rolling
sprite pool so flicker is shared fairly with everything else on screen.

## 9. The AI

Each partner is in one of three modes:

- **Follow** — first look for a monster (`FindTarget`). If there is none and a breakable wall
  needs bombing, do that. Otherwise fly in formation: the **V spot** is back-left / back-right of
  the player's facing (`TabFormDX/DY`); if that spot is inside a wall or more than 48 px away,
  walk the trail instead and form up once there is room. After the player has stood still for
  ~40 frames, nearby partners stop moving altogether.
- **Fight** — re-pick the nearest target every 8 frames (16 when crowded), but only switch when
  the new one is clearly nearer. Pick the attack axis (the larger of |dx|, |dy|), then:
  - in reach (lined up within 8 px, closer than 23 px) → swing, unless the monster is still
    flashing from a hit;
  - lined up but far → sword beam at full health, otherwise an arrow; if no weapon may come out
    right now, walk closer instead;
  - otherwise line up on the cross axis (start when off by 6 px, keep going until within 3),
    then close in.
- **Return** — walk back to the player's trail; warp onto it if stuck for long.

**Boss weaknesses.** `BossTactic` runs first in a fight when the target is a boss that only one
weapon hurts: Dodongo (bombs: walk to the spot 24 px in front of its mouth, face it and drop a
bomb; once a bomb has stunned it the sword works), Gohma (arrows only, shot as soon as lined up
at any range) and a big Digdogger (the partner plays the player's recorder once, `DigCheck`, which
splits it into small ones the sword can hit). Bombs and arrows are free for the partners, as
before; the recorder is only played if the player owns one.

`FindTarget` skips monsters that can't be hurt right now (underground, peahats in flight,
people in caves, types not in `targets.inc`), penalises a monster the other partner is already
fighting so the two spread out, and skips a monster this partner recently failed to reach.

## 10. Movement and obstacles

Steps are 1-2 px. A step is refused if the tile ahead of the partner's feet is unwalkable
(the same hot spots the game uses for Link), and a step that only gets pushed back by the
room's edge counts as no move. A partner **only turns when it actually moves** — this is what
stops it spinning on the spot when boxed in.

- **Axis choice** (`AxisOrder`) keeps going the way it was already going while that still gets
  it closer, so diagonal routes are walked in a few long legs rather than turning every step.
- **Detours** (`StepPair`) — when both the preferred and the fallback direction are blocked, the
  partner sidesteps along the obstacle (away from the fallback), trying the blocked direction
  again each step; once it is free it follows it for six steps. If both sides are blocked too it
  stands and waits instead of rocking back and forth.
- **Giving up** — sidestepping counts as no progress, so a monster that can't be reached is
  dropped after a while and ignored for a few seconds.

## 11. Breakable walls

On entering a room the partners scan it once (`ScanWalls`):

- **Dungeons** — `FindDoorTypeByDoorBit` for the four doors; type 4 is a bombable wall. Walls
  already opened (`CurOpenedDoors`) are skipped.
- **Overworld** — the rock-wall tile objects (types `$63` / `$67`) that hide caves, unless
  `IsQuestSecretMismatch` says the secret belongs to the other quest.

If the player owns at least one bomb and nothing needs fighting, one partner claims the job,
walks to a spot in front of the wall (moved up to 16 px closer if blocks are in the way), faces
it and drops a bomb. For overworld rock walls the exploding partner bomb is shown to the game's
own `UpdateRockWall` routine so the cave opens exactly as if the player had bombed it.

## 12. CPU budget

The NES has about 29,780 CPU cycles per frame and Zelda already uses much of it in busy rooms.
The mod keeps to the budget by:

- running the AI for one partner per frame, and nobody on odd frames in very crowded rooms;
- doing walking, the sword and drawing without any slot swapping;
- allowing beams, arrows and bombs only when fewer than 4 objects are in the room (except the
  wall bomb), and at most one extra weapon per partner;
- making partner beams vanish instead of splitting.

Measured on 21 busy test rooms with a scripted player: slowdown stays around 0.1–0.6 % of
frames.

## 13. Game changes and menus

- **255 rupees, 9 keys** — the register code sets up a new file's hearts and bomb
  capacity; a stub also writes 255 to the file's rupees (offset `$16` of the file record), 9 to
  its keys (`$17`).
- **The candle works by itself** — `IsDarkRoom` (banks 4 and 5) returns "lit" whenever
  `InvCandle` is non-zero, so dark dungeon rooms never go dark; Bushes are burnt by the partners: `ScanWalls`
  treats a secret-bush object (type `$64`) as job 5 when Link owns a candle, `PickWall` picks a stand
  spot 24 px from it (the flame lands 32 px ahead), the partner uses `WieldCandle`, and `TreeCheck`
  calls the game's own `UpdateTree` while that partner's standing fire is swapped in. Ganon's room keeps its own darkness handling.
- **NPC text** (`hints.py`) — the 38 strings are 6-bit tile codes; the top two bits of a
  character mark the end of a line (`$80` → line 2, `$40` → line 3, `$C0` → end of text). Leading
  padding uses `$25`, the instant blank. Every replacement states something checked against the
  game's code or data (heart requirements, prices, maze routes, boss weaknesses, drop rules);
  strings that were already clear keep their original bytes.
- **Double damage** — `Link_BeHarmed` keeps the damage in `$0D/$0E`; the stub doubles it right
  before the ring loop halves or quarters it.
- **Menus** (`menu.s`) — each screen's handler starts with `LDA ButtonsPressed`; that
  instruction is replaced by a call that rewrites the pressed buttons into the ones the original
  code understands (A → Start, Down → Select) and handles the new actions itself: Up moves the
  heart back, B erases a letter (blank the character in the name and in the name table, move the
  cursor back), Start on the register screen jumps straight to the END logic, and B on the
  elimination screen goes through END and then closes the register screen it leads to.
