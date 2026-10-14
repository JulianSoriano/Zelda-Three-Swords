"""New NPC text for the Three Swords hack (v4).

Every hint below states something that was checked against the game's own
code or data (the references are in the comments).  Text the original game
already worded clearly is left alone: only the strings listed in TEXT are
replaced, the others keep their original bytes.

A text is a list of 1-3 lines of at most 24 characters.  The font has only
A-Z, 0-9, space and  , ! ' & . " ? -   (no colon, slash, plus or brackets).

TEXT[i] replaces the NPC string with index i (0-37).  Several NPCs can share
one string; the comments say who.  Start screen = room $77.
"""

TEXT = {
    # white sword cave ($6C) and magical sword cave ($6D) share this text.
    # Heart checks in the cave code: $40 -> 5 containers, $B0 -> 12.
    1: ["WHITE SWORD NEEDS 5", "HEARTS. THE MAGICAL ONE", "NEEDS 12 HEARTS."],
    # "take any road" caves: stairs warp to one of the other three road caves.
    2: ["TAKE ANY ROAD YOU WANT.", "EACH ONE LEADS TO", "A DIFFERENT PLACE."],
    # the dead-end tree: a secret bush burns when a candle's flame stands on it.
    3: ["A BUSH AT A DEAD END", "HIDES A SECRET. BURN IT", "WITH THE CANDLE."],
    # money game: one of 20/50 to win, the other two lose 10 and 10/40.
    4: ["MONEY MAKING GAME!", "ONE WINS 20 OR 50, THE", "OTHER TWO LOSE RUPEES."],
    # door repair man: RupeesToSubtract += $14 (20).
    5: ["PAY 20 RUPEES FOR THE", "DOOR REPAIR CHARGE."],
    6: ["TAKE THIS LETTER TO THE", "OLD WOMAN WHO SELLS", "POTIONS."],
    # potion shop: the letter must be selected and used with B first.
    8: ["SELECT THE LETTER, PRESS", "B, THEN BUY A POTION.", "IT REFILLS YOUR HEARTS."],
    # the two pay-for-a-hint caves ($75: 5/10/20 rupees, $76: 10/30/50).
    9: ["PAY ME THE RIGHT PRICE", "AND I WILL GIVE A HINT."],
    10: ["THAT IS NOT ENOUGH.", "MY HINT COSTS MORE."],
    # CheckMazes: mountain maze = room $1B, UP x4; forest maze = room $61,
    # UP, LEFT, DOWN, LEFT.  Start is $77 (column 7, row 7).
    11: ["LOST HILLS - 4 EAST AND", "6 NORTH OF START. LEAVE", "UP 4 TIMES IN A ROW."],
    12: ["LOST WOODS - 6 WEST AND", "1 NORTH OF START. LEAVE", "UP, LEFT, DOWN, LEFT."],
    13: ["YOU PAID TOO MUCH!", "THE HINT COSTS 30", "RUPEES."],
    # $7B-$7D: the secret moblin pays 30, 100 or 10 rupees.
    17: ["YOU FOUND A SECRET!", "TAKE THE RUPEES."],
    # the Goriya that wants food (the bait item).
    18: ["GRUMBLE, GRUMBLE...", "GIVE ME BAIT AND I WILL", "LET YOU PASS."],
    19: ["THE SECRET IS ON THE", "EASTMOST PENINSULA.", "REACH IT WITH THE RAFT."],
    # Dodongo_CheckBombHit: a bomb blast in range puts it in state 2 (stunned).
    20: ["BOMBS STUN A DODONGO.", "DROP ONE NEAR ITS MOUTH,", "THEN USE YOUR SWORD."],
    # a big Digdogger splits up when the recorder is played.
    24: ["DIGDOGGER HATES THE", "RECORDER. PLAY IT, THEN", "HIT THE SMALL ONES."],
    # the bomb man: -100 rupees, MaxBombs += 4 and the bombs are refilled.
    25: ["WANT TO CARRY MORE", "BOMBS? PAY ME 100", "RUPEES FOR 4 MORE."],
    26: ["IF YOU GO IN THE", "DIRECTION OF THE ARROW,", "YOU WILL FIND A SECRET."],
    # life-or-money man: one heart container or 50 rupees.
    27: ["TO GO ON, LEAVE ONE", "HEART CONTAINER OR", "50 RUPEES."],
    29: ["SHOOT ARROWS AT THE", "EYE OF GOHMA WHEN IT", "IS OPEN."],
    # HandleMonsterDied / the item-drop code: the 10th kill since the last
    # guaranteed drop gives a bomb if a bomb made the kill, else 5 rupees.
    33: ["THE 10TH ENEMY YOU KILL", "DROPS A BOMB IF YOU USED", "A BOMB, ELSE 5 RUPEES."],
    # level 9's door needs InvTriforce = $FF (all eight pieces).
    34: ["YOU CAN'T ENTER WITHOUT", "ALL EIGHT PIECES OF", "THE TRIFORCE."],
    37: ["THE EYES OF THE SKULL", "HIDE A SECRET."],
}

# index -> original wording, for reference (these keep their original bytes):
#  0 IT'S DANGEROUS TO GO ALONE! TAKE THIS.   7 MEET THE OLD MAN AT THE GRAVE.
# 14 BUY SOMETHIN' WILL YA!   15 BOY, THIS IS REALLY EXPENSIVE!   16 TAKE ANY ONE YOU WANT.
# 21 DID YOU GET THE SWORD FROM THE OLD MAN ON TOP OF THE WATERFALL?   22 WALK INTO THE WATERFALL.
# 23 SECRET POWER IS SAID TO BE IN THE ARROW.   28 THERE ARE SECRETS WHERE FAIRIES DON'T LIVE.
# 30 SOUTH OF ARROW MARK HIDES A SECRET.   31 THERE'S A SECRET IN THE TIP OF THE NOSE.
# 32 SPECTACLE ROCK IS AN ENTRANCE TO DEATH.   35 PATRA HAS THE MAP.   36 GO TO THE NEXT ROOM.

CHARS = {' ': 0x24, ',': 0x28, '!': 0x29, "'": 0x2A, '&': 0x2B, '.': 0x2C, '"': 0x2D, '?': 0x2E, '-': 0x2F}
for _i, _c in enumerate('0123456789'): CHARS[_c] = _i
for _i in range(26): CHARS[chr(65 + _i)] = 10 + _i
WIDTH = 24
LINE_FLAG = {0: 0x80, 1: 0x40}      # end of line 1 -> start line 2; end of line 2 -> start line 3


def encode(lines):
    """Bytes for one text: centred, leading blanks use the instant space $25."""
    assert 1 <= len(lines) <= 3, lines
    out = bytearray()
    for n, line in enumerate(lines):
        assert 0 < len(line) <= WIDTH and line == line.strip(), line
        assert all(c in CHARS for c in line), (line, [c for c in line if c not in CHARS])
        out += bytes([0x25]) * ((WIDTH - len(line)) // 2)
        out += bytes(CHARS[c] for c in line)
        out[-1] |= 0xC0 if n == len(lines) - 1 else LINE_FLAG[n]
    return bytes(out)
