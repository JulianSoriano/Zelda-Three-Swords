"""Zelda Three Swords Mod: assemble the source and patch it into the original ROM.

usage:  python3 build.py [original.nes] [output.nes]

The original must be "Legend of Zelda, The (USA) (Rev 1)" (iNES, 131,088 bytes,
MD5 f4095791987351be68674a9355b266bc).  By default it is looked for one folder
up, in the repository root.  Needs cc65 (ca65 + ld65) on the PATH, or set
CC65_HOME to the folder that contains bin/ca65.
"""
import subprocess, sys, os, hashlib, shutil
os.chdir(os.path.dirname(os.path.abspath(__file__)))
CC = os.path.join(os.environ['CC65_HOME'], 'bin', '') if os.environ.get('CC65_HOME') else ''
if not CC and not shutil.which('ca65'):
    sys.exit('ca65 not found: install cc65 or set CC65_HOME')
os.makedirs('out', exist_ok=True)

def rom_offset(bank, addr):
    """PRG offset (without the iNES header) of a bank address.  Addresses
    $6C90-$7EFF are the common code the game copies from bank 1 ($A500) to
    WRAM at power-on."""
    if 0x6C90 <= addr < 0x7F00:
        return 1 * 0x4000 + (addr - 0x6C90 + 0xA500 - 0x8000)
    return bank * 0x4000 + addr - (0xC000 if bank == 7 else 0x8000)

def run(*a):
    r = subprocess.run(a, capture_output=True, text=True)
    if r.returncode: print(r.stdout, r.stderr); sys.exit(1)
    return r.stdout
subprocess.run(['python3', 'gen_xchg.py'], check=True, capture_output=True)
run(CC+'ca65', 'clones.s', '-o', 'out/clones.o', '-l', 'out/clones.lst', '-g', *(['-D', 'DISABLED=1'] if os.environ.get('DISABLED') else []))
run(CC+'ld65', '-C', 'clones.cfg', '-o', 'out/x', '-m', 'out/map.txt', '-Ln', 'out/labels.txt', '--dbgfile', 'out/clones.dbg', 'out/clones.o')
lab = {}
for line in open('out/labels.txt'):
    p = line.split(); lab[p[2].lstrip('.')] = int(p[1], 16)
src = sys.argv[1] if len(sys.argv) > 1 else '../Legend of Zelda, The (USA) (Rev 1).nes'
dst = sys.argv[2] if len(sys.argv) > 2 else 'out/Zelda_Three_Swords_Mod.nes'
rom = bytearray(open(src, 'rb').read())
if hashlib.md5(rom).hexdigest() != 'f4095791987351be68674a9355b266bc':
    sys.exit('%s is not Legend of Zelda (USA) (Rev 1) (MD5 mismatch)' % src)
H = 16
def put(bank, addr, data, expect=None, free=False):
    o = H + rom_offset(bank, addr)
    old = bytes(rom[o:o+len(data)])
    if free: assert all(b == 0xFF for b in old), ('not free', bank, hex(addr))
    if expect is not None: assert old == bytes.fromhex(expect), ('mismatch', bank, hex(addr), old.hex())
    rom[o:o+len(data)] = data
def jsr(a): return bytes([0x20, a & 255, a >> 8])
fc = open('out/farcall.bin', 'rb').read()
b1 = bytearray(open('out/b1.bin', 'rb').read())
i = lab['FarCallImage'] - 0xB770
b1[i:i+len(fc)] = fc
put(1, 0x7EE1, open('out/wstub.bin', 'rb').read(), free=True)
put(1, 0xB770, bytes(b1), free=True)
put(0, 0xA000, open('out/b3.bin', 'rb').read(), free=True)
put(4, 0xB470, open('out/b4.bin', 'rb').read(), free=True)
put(7, 0xECB7, jsr(lab['MainHook']) + b'\xea\xea', 'a212203ef7')
put(1, 0x79FD, jsr(lab['PostCheck']), '20a77a')
put(4, 0xA061, jsr(lab['WizzHook']), '20a77a')
put(7, 0xE901, jsr(lab['MyInit']), '20008d')
put(4, 0x98AF, jsr(lab['DodoBombHook']), '20b999')   # UpdateDodongo: partners' bombs feed/stun it too
# New game: 255 rupees and 9 keys.  The file-registration code sets up a new profile's
# hearts and max bombs; a stub in bank 2's free space also sets the rest
# ($16 = rupees, $17 = InvKeys).
put(2, 0xB200, bytes.fromhex('a025a90891c0' 'a016a9ff91c0' 'a017a90991c0' '60'), free=True)
put(2, 0x9F49, jsr(0xB200) + b'\xea\xea\xea', 'a025a90891c0')
# Double damage: Link_BeHarmed doubles the damage before the rings halve it.
# (LDY InvRing in WRAM code -> JSR stub in bank 7's free space)
put(7, 0xFF42, bytes.fromhex('060e' '260d' 'ac6206' '60'), free=True)
put(1, 0x7B5B, jsr(0xFF42), 'ac6206')
# Menu controls (menu.s) and the register screen's heart-cursor bug
put(2, 0xAFA0, open('out/b2.bin', 'rb').read(), free=True)
put(2, 0xA59A, jsr(lab['MenuMode1']) + b'\xea', 'a5f82910')
put(2, 0x9EF0, jsr(lab['MenuModeE']) + b'\xea', 'a5f82910')
put(2, 0x9FC5, jsr(lab['MenuModeF']) + b'\xea', 'a5f8c910')
put(2, 0xA236, bytes.fromhex('8d0402'), '8d0002')   # name cursor Y went into the heart's sprite
# Title screen credit: the two blank rows inside the title frame (bank 6's title
# transfer buffer; 24 interior tiles per row, font tiles A-Z = $0A-$23, space = $24).
def _tiles(t): return bytes(0x24 if c == ' ' else (int(c) if c.isdigit() else ord(c) - 55) for c in t)
def _row(t): return _tiles(t.center(24))
_blank = b'\x24' * 24
put(6, 0xAB71, _row('THREE SWORDS ROM HACK'), _blank.hex())
put(6, 0xAB94, _row('BY RAMENPHOLIFE'), _blank.hex())
# v4: the candle works by itself.
#  - dark dungeon rooms never go dark while Link owns a candle (IsDarkRoom in banks 5 and 4)
#  (bushes are burnt by the partners, see TreeCheck / WallTask in clones.s)
# (the level's boss room keeps its darkness: Ganon's scene brightens it itself)
dark = bytes.fromhex('ad5b06' 'f008' 'ccbc6b' 'f003' 'a900' '60' 'a510' 'f005' 'b97e6a' '2980' '60')
put(5, 0xB8A0, dark, free=True)
put(5, 0xB68D, bytes.fromhex('4ca0b8'), 'a510f0')
put(4, 0xBA00, dark, free=True)
put(4, 0xB1EA, bytes.fromhex('4c00ba'), 'a510f0')
# v4: clearer NPC text (hints.py).  Bank 1 holds a table of 38 string addresses at
# $8000 and the strings right after it ($804C-$85A1).  Strings that hints.py does not
# replace keep their original bytes; the block is rewritten and the table re-pointed.
import hints
TB, TS, TE, N = 0x8000, 0x804C, 0x85A2, 38
def r16(a): o = H + rom_offset(1, a); return rom[o] | rom[o + 1] << 8
tab = [r16(TB + 2 * i) for i in range(N)]
assert tab[0] == TS and tab == sorted(tab), 'unexpected text table'
ends = tab[1:] + [TE]
texts = []
for i in range(N):
    if i in hints.TEXT: texts.append(hints.encode(hints.TEXT[i]))
    else: o = H + rom_offset(1, tab[i]); texts.append(bytes(rom[o:o + ends[i] - tab[i]]))
# Pack in order into the original block; what does not fit goes to free space after the bank 1 code.
SP = 0xB7A0
addr, sp, block, spill = TS, SP, bytearray(), bytearray()
for i, t in enumerate(texts):
    if addr + len(t) <= TE: a, addr = addr, addr + len(t); block += t
    else: a, sp = sp, sp + len(t); spill += t
    rom[H + rom_offset(1, TB + 2 * i)] = a & 255
    rom[H + rom_offset(1, TB + 2 * i + 1)] = a >> 8
assert sp <= 0xBF50, 'spill overflows bank 1 free space'
o = H + rom_offset(1, TS)
rom[o:o + TE - TS] = bytes(block) + b'\xff' * (TE - TS - len(block))
put(1, SP, bytes(spill), free=True)
print('npc text: %d bytes (%d in place, %d moved to $%04X)' % (len(block) + len(spill), len(block), len(spill), SP))
open(dst, 'wb').write(rom)
sizes = {k: os.path.getsize('out/' + k + '.bin') for k in ['wstub', 'farcall', 'b1', 'b3', 'b4', 'b2']}
print('built', dst, sizes)
