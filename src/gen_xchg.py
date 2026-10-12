# Generate exchange routines between game object slots and per-clone context store.
STORE = 0x7F00
FIELDS = [0x28, 0x70, 0x84, 0x98, 0xAC, 0x380, 0x394, 0x3A8, 0x3BC, 0x3D0, 0x3E4]
NF = len(FIELDS)
def S(c, f, idx): return STORE + (c * NF + f) * 7 + idx
def gen(prefix, fields0, fieldsW, fieldsD=None):
    out = []
    for c in range(3):
        out.append('%s0_%d:' % (prefix, c))
        for f in fields0:
            g = FIELDS[f]; s = S(c, f, 0)
            out += ['    LDA $%04X' % g, '    LDY $%04X' % s, '    STA $%04X' % s, '    STY $%04X' % g]
        out.append('    RTS')
        if fieldsD:
            out.append('%sD_%d:' % (prefix, c))
            for f in fieldsD:
                g = FIELDS[f] + 0x0D; s = S(c, f, 1)
                out += ['    LDA $%04X' % g, '    LDY $%04X' % s, '    STA $%04X' % s, '    STY $%04X' % g]
            out.append('    RTS')
        out.append('%sW_%d:' % (prefix, c))
        for f in fieldsW:
            g = FIELDS[f]; s = S(c, f, 1) - 0x0D
            out += ['    LDA $%04X,X' % g, '    LDY $%04X,X' % s, '    STA $%04X,X' % s]
            if g < 0x100: out.append('    STY $%02X,X' % g)
            else: out += ['    TYA', '    STA $%04X,X' % g]
        out.append('    RTS')
    return '\n'.join(out) + '\n'
WF = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
txt = gen('Xchg', [1, 2, 3, 4, 9, 10], WF)
for c in range(3):
    txt += 'LoadW_%d:\n' % c
    for f in WF:
        g_ = FIELDS[f]; s_ = S(c, f, 1) - 0x0D
        txt += '    LDA $%04X,X\n' % s_
        txt += ('    STA $%02X,X\n' % g_) if g_ < 0x100 else ('    STA $%04X,X\n' % g_)
    txt += '    RTS\n'
    txt += 'UnloadW_%d:\n' % c
    for f in WF:
        g_ = FIELDS[f]; s_ = S(c, f, 1) - 0x0D
        txt += ('    LDA $%02X,X\n' % g_) if g_ < 0x100 else ('    LDA $%04X,X\n' % g_)
        txt += '    STA $%04X,X\n' % s_
    txt += '    LDA #$00\n    STA $AC,X\n    RTS\n'
open('xchg_main.inc', 'w').write(txt)
# collision subset: slot0 X,Y,Dir ; weapons X,Y,Dir,State,AnimCounter,MovingLimit,GridOffset
open('xchg_coll.inc', 'w').write(gen('CXchg', [1, 2, 3], [1, 2, 3, 4, 9, 5, 6]))
# symbolic accessors
with open('store.inc', 'w') as f:
    names = ['TIMER', 'X', 'Y', 'DIR', 'STATE', 'MLIM', 'GRID', 'PFRAC', 'QSPD', 'ACNT', 'AFRM']
    for fi, n in enumerate(names):
        for c in range(3):
            f.write('ST_%s_%d = $%04X\n' % (n, c, S(c, fi, 0)))
        f.write('ST_%s = $%04X ; base, index = c*%d (+slotidx)\n' % (n, S(0, fi, 0), NF * 7))
    f.write('STORE_END = $%04X\n' % (STORE + 3 * NF * 7))
print(open('store.inc').read())
