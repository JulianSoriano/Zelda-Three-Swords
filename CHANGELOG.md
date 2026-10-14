# Changelog

Testing for every release was done in an emulator with scripted play: 21 saved "busy room"
states from the overworld and dungeons 1–9 (room-clear times, slowdown, partner behaviour),
targeted tests for each feature, and a crash test walking through rooms of the overworld and
all nine dungeons.

## v4 — boss tactics, candle, 9 keys, clearer hints
- **Partners use boss weaknesses.** Dodongo: they walk to the spot in front of its mouth, face it
  and drop a bomb (partner bombs now feed and stun it too); once stunned the sword works. Gohma:
  arrows as soon as they are lined up, at any range. Big Digdogger: the partner plays your
  recorder once (if you own one) so it splits into the small ones. Tested: all nine dungeon
  bosses go down in the emulator, including Dodongo (level 2), Digdogger (5) and Gohma (6).
- **Candle.** Once you own a candle (you don't start with one), dark dungeon rooms are lit (room brightness 22 → 90 in the test room) and your partners burn secret bushes
  themselves: one walks to the bush, lights the candle in front of it and the secret opens (tested with
  red and blue candles at several positions; with no candle the bush stays).
- **9 keys** at the start of a new file (the HUD shows `X9`).
- **Clearer NPC text.** 24 of the 38 strings rewritten using facts checked in the game's code
  (hearts for the swords, prices, mazes, boss weaknesses, drop rule); the other 14 were already
  clear and keep their original bytes. Strings are centred and use the game's instant blank for
  padding. Checked by decoding every string from the built ROM and by displaying several in the
  game's own text box.
- Build: `src/hints.py` holds the text; `src/tools/make_ips.py` builds the IPS patch and checks
  that it reproduces the ROM byte for byte.
- Regression: register screen with stale values in the flag from the previous fix (8 values, all
  stay open); random-play crash tests on levels 0, 1, 2, 4, 5, 6 and 8 (5,000 frames each) with no
  crashes or stray writes.

## Final — title credit and menu fix
- Title screen now shows "THREE SWORDS ROM HACK" and "BY RAMENPHOLIFE" inside the title frame.
- Fixed the heart-cursor glitch: the menu code used a flag in the stack page (not cleared at
  power-on). With stale memory (real hardware, some emulators) the register screen closed the
  moment it opened, leaving the cursor sprites in the wrong state. The flag is now cleared on the
  file-select screen. Tested with random power-on memory (12/12 runs enter and leave correctly;
  v3 failed all 12).

## v3 — no more spinning in tight spots
- A partner only turns when it actually takes a step; bumping into a wall no longer flips its
  facing (the main cause of "spinning on the spot" when boxed in).
- Walking towards something it keeps going one way while that still helps, instead of turning
  every step; lining up with a moving monster has hysteresis (start at 6 px off, stop within 3).
- Detours commit to one side; when wedged in on both sides the partner waits instead of rocking.
- Targets only switch when another monster is clearly nearer; an unreachable monster is left
  alone for a few seconds instead of being paced at.
- When the player stands still, nearby partners stay put; partners no longer hop between
  formation spots next to walls.
- Partners can no longer be pushed into the room's border walls at screen edges (they could
  get trapped there).
- Measured (share of frames with 3+ turns in 8 frames, not attacking):
  following 8.7 % → 0.3 %, fighting 3.9 % → 0.1 %, walking to a wall 28 % → 0 %,
  returning 15 % → 0 %. Back-and-forth shuffling while the player stands still: 24 % → <0.1 %.

## v2 — menus, V formation, arrows
- Menus: D-pad navigation on the file select and elimination screens, A accepts, B erases a
  letter / leaves; Start saves from anywhere on the register screen. Fixed the original
  register-screen bug that moved the heart cursor to the name cursor's position.
- V formation behind the player (back-left / back-right of the facing direction).
- Unlimited free arrows for monsters out of sword reach.
- Partners no longer swing at the air when they can't fire a beam: they walk up instead, don't
  swing at a monster still reeling from a hit, and ignore flying peahats.
- Walking round obstacles instead of pushing into them (time spent stuck mid-fight −80 %).
- Room-clear times on the test rooms: often several times faster than the previous version.

## Three Swords — two partners
- The third partner removed: slowdown in the busiest rooms cut to about a third, and no more
  colour problems for a fourth Link (the NES has only four sprite palettes).

## Four Swords v2
- Partners attack any monster in the room, not only those near the player.
- Partners bomb breakable dungeon walls and overworld rock walls (when the player owns bombs).
- New files start with 255 rupees; monsters do double damage.

## Four Swords v1
- Three invincible CPU partner Links using the player's sword and B items.
