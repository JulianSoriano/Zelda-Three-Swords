"""Map labels of the Zelda 1 disassembly (aldonunez/zelda1-disassembly, which
assembles the PRG0 release) to addresses in the Rev 1 ROM this mod patches.

Only needed to regenerate ../game.inc (see gen_game_inc.py).  Set:
  ZELDA_DISASM  folder of a built zelda1-disassembly (with obj/z.dbg, bin/Z.nes)
  ZELDA_ROM     the Rev 1 ROM
"""
import difflib, sys, os, re
DIS = os.environ.get('ZELDA_DISASM', 'zelda1-disassembly')
ROM = os.environ.get('ZELDA_ROM', '../../Legend of Zelda, The (USA) (Rev 1).nes')
import re
segs={}; syms={}
for line in open(DIS + '/obj/z.dbg'):
    if line.startswith('seg\t'):
        d=dict(kv.split('=',1) for kv in line[4:].strip().split(','))
        segs[int(d['id'])]=d['name'].strip('"')
for line in open(DIS + '/obj/z.dbg'):
    if line.startswith('sym\t') and 'type=lab' in line and 'val=' in line and 'seg=' in line:
        d=dict(kv.split('=',1) for kv in line[4:].strip().split(','))
        nm=d['name'].strip('"'); seg=segs[int(d['seg'])]
        bank=int(seg[5:7])
        syms.setdefault(nm,[]).append((bank,int(d['val'],16)))
def S(n):
    v=syms[n]; assert len(set(v))==1,(n,v); return v[0]

A = open(os.path.join(DIS, 'bin/Z.nes'),'rb').read()[16:]
B = open(ROM,'rb').read()[16:]
RAMCODE = (0x6C90, 0x7F00, 1, 0xA500)   # WRAM code: run addr range, bank, load addr
_maps = {}
def bankmap(bank):
    if bank in _maps: return _maps[bank]
    a = A[bank*0x4000:(bank+1)*0x4000]; b = B[bank*0x4000:(bank+1)*0x4000]
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    blocks = [(i, j, n) for i, j, n in sm.get_matching_blocks() if n]
    _maps[bank] = blocks; return blocks
def base(bank): return 0xC000 if bank == 7 else 0x8000
def map_off(bank, off):
    for i, j, n in bankmap(bank):
        if i <= off < i + n: return j + (off - i)
    return None
def rev1(name):
    bank, addr = S(name)
    if 0x6C90 <= addr < 0x7F00:      # WRAM code: identical (bank 1 same)
        return bank, addr
    if bank == 0 and addr >= 0x8000: off = addr - 0x8000
    off = addr - base(bank)
    o2 = map_off(bank, off)
    if o2 is None: raise KeyError('unmapped ' + name)
    return bank, o2 + base(bank)
def rom_offset(bank, addr):
    """file offset (without header) of a bank address (or WRAM code addr)"""
    if 0x6C90 <= addr < 0x7F00: return 1*0x4000 + (addr - 0x6C90 + 0xA500 - 0x8000)
    return bank*0x4000 + addr - base(bank)
if __name__ == '__main__':
    for n in sys.argv[1:]:
        b, a = rev1(n); print(n, b, hex(a), B[rom_offset(b,a):rom_offset(b,a)+8].hex())
