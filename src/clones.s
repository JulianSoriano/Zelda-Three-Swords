; ---------------------------------------------------------------------------
; Legend of Zelda (Rev 1) - "Three Swords" CPU partner Links
;
; Two invincible CPU-controlled Links (red and blue) follow the player in a
; V formation, fight monsters with the player's own sword, sword beams and
; free arrows, bomb breakable walls, and never harm the player.
; (The code was written for three partners; NCL sets how many run.)
;
; Each CPU Link owns a private copy of the "Link context": object slot 0
; (Link) and the weapon slots $0D-$12.  Every frame the context is swapped
; into the real slots, the game's own weapon code runs on it, and it is
; swapped back.  Monster collision checks are extended the same way.
; ---------------------------------------------------------------------------

.include "game.inc"
.include "store.inc"

MYBANK = 0               ; bank holding the per-frame partner code

; ---- game RAM -------------------------------------------------------------
CurLevel        = $10
IsUpdatingMode  = $11
GameMode        = $12
FrameCounter    = $15
Random          = $18
ObjX            = $70
ObjY            = $84
ObjDir          = $98
ObjState        = $AC
RoomId          = $EB
TriggeredDoorCmd = $54
CurOpenedDoors  = $EE
Sprites         = $200
RollingSpriteIndex = $341
LeftSpriteOffset = $343
RightSpriteOffset = $344
RoomBoundLeft   = $346
RoomBoundRight  = $347
RoomBoundUp     = $348
RoomBoundDown   = $349
ObjectFirstUnwalkableTile = $34A
ObjType         = $34F
ObjAnimCounter  = $3D0
ObjAnimFrame    = $3E4
ObjInputDir     = $3F8
ObjMetastate    = $405
ObjCollidedTile = $49E
ObjAttr         = $4BF
ObjInvincibilityTimer = $4F0
UsedCandle      = $513
SampleRequest   = $601
EffectRequest   = $603
SelectedItemSlot = $656
Items           = $657
InvBombs        = $658
InvArrow        = $659
Bow             = $65A
InvCandle       = $65B
InvRecorder     = $65C
UsedFlute       = $51B
InvRupees       = $66D
HeartValues     = $66F
HeartPartial    = $670
InvBoomerang    = $674
InvMagicBoomerang = $675
InvMagicShield  = $676
RupeesToSubtract = $67E

; ---- mod RAM ($0110-$017F, unused low end of the stack page) ---------------
NCL       = 2           ; number of partner Links (Three Swords: you + 2)
CL_MODE   = $110        ; [3] 0 follow, 1 fight, 2 return
CL_TGT    = $113        ; [3] target monster slot
CL_STUCK  = $116        ; [3]
CL_ACD    = $119        ; [3] sword cooldown
CL_ICD    = $11C        ; [3] item cooldown
CL_MASK   = $11F        ; [3] active weapon slots: b0 $D, b1 $E, b2 $F, b3 $10, b4 $11, b5 $12
CL_CANDLE = $122        ; [3] used blue candle this room
CL_LX     = $125        ; [3]
CL_LY     = $128        ; [3]
CL_WANT   = $12B        ; [3] b0 sword, b1 item
CL_MDIR   = $12E        ; [3] movement direction this frame
TRAIL_X   = $131        ; [16]
TRAIL_Y   = $141        ; [16]
TRAIL_HEAD = $151
LAST_ROOM = $152
LAST_LEVEL = $153
LAST_MODE = $154
HX        = $155        ; player position / direction this frame
HY        = $156
HDIR      = $157
SAV_INPUT = $158
SAV_INV   = $159
SAV_COLL  = $15A
SAV_BOMBS = $15B
SAV_RUPSUB = $15C
SAV_CANDLE = $15D
SAV_EFFECT = $15E
CUR       = $15F        ; current clone index
CUROFF    = $160        ; c * 77
GROUPS    = $161
TX        = $162        ; movement target
TY        = $163
ADX       = $164        ; |dx|
ADY       = $165        ; |dy|
SDX       = $166        ; dir toward target horizontally (1 right / 2 left / 0)
SDY       = $167        ; dir toward target vertically (4 down / 8 up / 0)
SPEED     = $168
COLLIDE   = $169
MOVED     = $16A
TMP       = $16B
TMP2      = $16C
MON       = $16D        ; monster slot (collision pass)
NEAR      = $16E
CPASS     = $16F        ; clone index (collision pass)
LAST_HX   = $170
LAST_HY   = $171
FULLHP    = $172
BESTD     = $173
BESTS     = $174
ALONG     = $175
PERP      = $176
FACE      = $177
CMASK     = $178        ; collision: mask copy
ORIGT     = $179
PALV      = $17A
TMPX      = $17B
TMPY      = $17C
FTD       = $17D
; spare bytes: the third partner's entries in the [3] arrays (NCL = 2)
SAV_ARROW = $124        ; (CL_CANDLE+2) player's arrow type while partners' arrows fly
SAV_BOW   = $127        ; (CL_LX+2)
SAV_RUP   = $12A        ; (CL_LY+2)
PREF      = $192        ; StepPair: preferred direction
FALLB     = $193        ; StepPair: fallback direction
; (the third partner's context in WRAM is free with NCL = 2)
DET_T     = $7FA0       ; [2] detour: thinks left walking round an obstacle
DET_D     = $7FA2       ; [2] detour direction (sidestep)
DET_P     = $7FA4       ; [2] the blocked direction we want to go
LSTILL    = $7FA6       ; frames the player has been standing still
IGN_S     = $7FA8       ; [2] monster this partner gave up on (unreachable)
IGN_T     = $7FAA       ; [2] ... thinks left before trying it again
MX        = $1A7
MY        = $1A8

; ===========================================================================
; WRAM stubs: placed in the unused filler at the end of the common code that
; the game copies to $6C90-$7EFF.
; ===========================================================================
.segment "WSTUB"
MainHook:
    LDX #$12
    JSR UpdateRodOrArrow        ; replaced instruction
    LDA #MYBANK
    JSR SwitchBank
    JMP CloneMain

PostCheck:                      ; replaces JSR CheckLinkCollision in CheckMonsterCollisions
    LDA B4Magic
    CMP #$5A
    BNE :+
    JSR CloneHits               ; only when bank 4 (monster code) is mapped
:   JMP CheckLinkCollision

; ===========================================================================
; FarCall: lives at the end of WRAM, copied there at power-on.
; A = bank to map, FarVec = routine.  MYBANK is restored afterwards.
; X and Y pass through; A and flags of the routine are preserved.
; ===========================================================================
.segment "FARCALL"
FarCall:
    JSR SwitchBank
    JSR FarJmp
    PHP
    PHA
    LDA #MYBANK
    JSR SwitchBank
    PLA
    PLP
    RTS
FarJmp:
    JMP (FarVec)
FarVec:
    .word 0
FarCallEnd:

; ===========================================================================
; Bank 1: power-on init (called instead of CopyCommonCodeToRam)
; ===========================================================================
.segment "B1CODE"
MyInit:
    JSR CopyCommonCodeToRam
    LDX #(FarCallEnd - FarCall - 1)
:   LDA FarCallImage, X
    STA FarCall, X
    DEX
    BPL :-
    LDA #$FF                    ; force a reset of the partners
    STA LAST_MODE
    RTS
FarCallImage:
    ; filled in by the build script (copy of the FARCALL segment)
    .res (FarCallEnd - FarCall), $EA

; group bits (weapon slots swapped for a partner)
G_SWORD = $01           ; slot  $D
G_SHOT  = $02           ; slot  $E
G_BOOM  = $04           ; slot  $F
G_BOMB  = $08           ; slots $10,$11
G_ARROW = $10           ; slot  $12

MAXARMED = 2             ; weapons out (beam, arrow, B item) at once, both partners
CROWD = 4               ; objects in the room that count as crowded
CROWD2 = 6              ; ... as very crowded
LAG = 4                 ; trail points between followers (4 px each)

CX      = $17E          ; working copy of the partner's slot-0 data
CY      = $17F
CDIR    = $180
CSTATE  = $181
CINPUT  = $182
SPX     = $183
SPY     = $184
TILEL   = $185
TILER   = $186
SATTR   = $187
SL      = $188
SR      = $189
FTMP    = $18A
SWING_GATE = $18B
SAVED   = $18C
SAV_T13 = $18D
LOADED  = $18E
THINKER = $18F
LASTSTEP = $190
REMAIN  = $191
; (CL_MDIR at $12E)
CL_MSPD = $195          ; [3]
CL_MCOL = $198          ; [3]
CL_MREM = $19B          ; [3]
CL_FT   = $19E
CL_ATKT = $1A0          ; [3] swing frame (0 = none)
CL_POSE = $1A3          ; [3] item-use pose timer
NEED0   = $1A6
HEAVY   = $1A9
THINKER2 = $1AA
YOFF    = $1AB
WALLS   = $1AC          ; bombable walls left in this room (8 N, 4 S, 2 W, 1 E)
BOMBER  = $1AD          ; partner busy bombing a wall ($FF = none)
WALLSCAN = $1AE         ; 0 = room not scanned yet
BJOB    = $1AF          ; current wall: 0 N, 1 S, 2 W, 3 E, 4 = overworld rock wall
BTIME   = $1B0          ; frames left for the current wall
FORCEBOMB = $1B1        ; UseItem: place a bomb whatever item is selected
ROCKSLOT = $1B2         ; overworld: slot of the bombable rock wall (0 = none)
BPLACED = $1B3          ; the wall bomb has been placed
BSX     = $1B4          ; where to stand to bomb it, and which way to face
BSY     = $1B5
BFACE   = $1B6

; ===========================================================================
; Bank 0 ($A000, free space): per-frame partner logic
; ===========================================================================
.segment "B3CODE"

.macro FAR bank, addr
    LDA #<addr
    STA FarVec
    LDA #>addr
    STA FarVec+1
    LDA #bank
    JSR FarCall
.endmacro

CloneMain:
.ifdef DISABLED
    RTS
.endif
    ; Only in play modes: 5 world, 9 cellar, $B cave, $C shortcut cave.
    LDA GameMode
    CMP #$05
    BEQ @ok
    CMP #$09
    BEQ @ok
    CMP #$0B
    BEQ @ok
    CMP #$0C
    BEQ @ok
    STA LAST_MODE
    RTS
@ok:
    LDA ObjX
    STA HX
    LDA ObjY
    STA HY
    LDA ObjDir
    STA HDIR

    ; Reset the partners when the room / mode changes or the player jumps.
    LDA GameMode
    CMP LAST_MODE
    BNE @reset
    LDA RoomId
    CMP LAST_ROOM
    BNE @reset
    LDA CurLevel
    CMP LAST_LEVEL
    BNE @reset
    LDA HX
    SEC
    SBC LAST_HX
    JSR AbsU
    CMP #$20
    BCS @reset
    LDA HY
    SEC
    SBC LAST_HY
    JSR AbsU
    CMP #$20
    BCC @noreset
@reset:
    JSR ResetClones
@noreset:
    LDA HX                      ; how long has the player been standing still?
    CMP LAST_HX
    BNE :+
    LDA HY
    CMP LAST_HY
    BNE :+
    LDA LSTILL
    CMP #$FF
    BEQ :++
    INC LSTILL
    BNE :++
:   LDA #$00
    STA LSTILL
:   LDA GameMode
    STA LAST_MODE
    LDA RoomId
    STA LAST_ROOM
    LDA CurLevel
    STA LAST_LEVEL
    LDA HX
    STA LAST_HX
    LDA HY
    STA LAST_HY

    JSR RecordTrail
    JSR TickTimers

    ; crowded room?  then the partners stick to their swords and think
    ; half as often (CPU budget)
    LDY #$00
    LDX #$0B
:   LDA ObjType, X
    BEQ :+
    INY
:   DEX
    BNE :--
    STY HEAVY
    CPY #CROWD2
    BCC @think
    LDA FrameCounter
    LSR
    BCC @think
    LDA #$FF                    ; nobody thinks this frame
    STA THINKER
    BNE @thought
@think:
    LDX THINKER2
    INX
    CPX #NCL
    BCC :+
    LDX #$00
:   STX THINKER2
    STX THINKER
@thought:
    LDA SWING_GATE
    BEQ :+
    DEC SWING_GATE
:

    ; Sword-beam condition (same test as MakeSwordShot).
    LDA #$00
    STA FULLHP
    LDA HeartValues
    AND #$0F
    STA TMP
    LDA HeartValues
    LSR
    LSR
    LSR
    LSR
    CMP TMP
    BNE :+
    LDA HeartPartial
    CMP #$80
    BCC :+
    INC FULLHP
:
    LDA #$00                    ; overworld and cellars draw Link 2 px lower
    LDX GameMode
    CPX #$09
    BEQ :+
    LDX CurLevel
    BNE :++
:   LDA #$02
:   STA YOFF
    LDA #$00
    STA SAVED
    STA CUR
    STA CUROFF
@loop:
    JSR ProcessClone
    LDA CUROFF
    CLC
    ADC #77
    STA CUROFF
    INC CUR
    LDA CUR
    CMP #NCL
    BNE @loop

    LDA SAVED
    BEQ :+
    JSR RestorePlayer
:   RTS

; Save player values that partner processing may disturb (once per frame).
SavePlayer:
    LDA SAVED
    BNE :+
    INC SAVED
    LDA ObjInputDir
    STA SAV_INPUT
    LDA ObjInvincibilityTimer
    STA SAV_INV
    LDA ObjCollidedTile
    STA SAV_COLL
    LDA InvBombs
    STA SAV_BOMBS
    LDA RupeesToSubtract
    STA SAV_RUPSUB
    LDA UsedCandle
    STA SAV_CANDLE
    LDA EffectRequest
    STA SAV_EFFECT
    LDA $3B
    STA SAV_T13


:   RTS

RestorePlayer:
    LDA SAV_INPUT
    STA ObjInputDir
    LDA SAV_INV
    STA ObjInvincibilityTimer
    LDA SAV_COLL
    STA ObjCollidedTile
    LDA SAV_BOMBS
    STA InvBombs
    LDA SAV_RUPSUB
    STA RupeesToSubtract
    LDA SAV_CANDLE
    STA UsedCandle
    LDA SAV_EFFECT
    STA EffectRequest
    LDA SAV_T13
    STA $3B

    RTS

; |A| for a difference computed with SEC/SBC (carry set = no borrow)
AbsU:
    BCS :+
    EOR #$FF
    ADC #$01
:   RTS

; ---------------------------------------------------------------------------
ResetClones:
    LDX #$0F
:   LDA HX
    STA TRAIL_X, X
    LDA HY
    STA TRAIL_Y, X
    DEX
    BPL :-
    LDA #$00
    STA TRAIL_HEAD
    STA SWING_GATE
    STA THINKER2
    STA WALLSCAN
    STA FORCEBOMB
    LDA #$FF
    STA BOMBER
    LDX #NCL-1
@c: LDA #$00
    STA DET_T, X
    STA IGN_T, X
    STA CL_MODE, X
    STA CL_STUCK, X
    STA CL_MASK, X
    STA CL_CANDLE, X
    STA CL_WANT, X
    STA CL_ATKT, X
    STA CL_POSE, X
    STA CL_MDIR, X
    STA CL_MREM, X
    STA CL_LX, X
    STA CL_LY, X
    LDA #$10
    STA CL_ACD, X
    LDA #$40
    STA CL_ICD, X
    DEX
    BPL @c
    ; contexts: no weapons out, partners on the player
    LDY #$00
@ctx:
    LDA #$00
    STA ST_STATE+0, Y
    STA ST_STATE+1, Y
    STA ST_STATE+2, Y
    STA ST_STATE+3, Y
    STA ST_STATE+4, Y
    STA ST_STATE+5, Y
    STA ST_STATE+6, Y
    STA ST_AFRM, Y
    LDA HX
    STA ST_X, Y
    LDA HY
    STA ST_Y, Y
    LDA HDIR
    STA ST_DIR, Y
    LDA #$06
    STA ST_ACNT, Y
    TYA
    CLC
    ADC #77
    TAY
    CPY #(77*NCL)
    BNE @ctx
    RTS

; ---------------------------------------------------------------------------
; The NMI counts down the object timers of the real slots only, so count
; down the timers of the partners' stored weapon slots here (bombs, fire).
TickTimers:
    LDX #NCL-1
@c: LDA CL_MASK, X
    BEQ @n
    LDY TabCOff3, X
    LDA #$06
    STA TMP
@s: LDA ST_TIMER+1, Y
    BEQ :+
    SEC
    SBC #$01
    STA ST_TIMER+1, Y
:   INY
    DEC TMP
    BNE @s
@n: DEX
    BPL @c
    RTS
TabCOff3:
    .byte 0, 77, 154

; ---------------------------------------------------------------------------
RecordTrail:
    LDX TRAIL_HEAD
    LDA HX
    SEC
    SBC TRAIL_X, X
    JSR AbsU
    STA TMP
    LDA HY
    SEC
    SBC TRAIL_Y, X
    JSR AbsU
    CLC
    ADC TMP
    CMP #LAG
    BCC :+
    INX
    TXA
    AND #$0F
    TAX
    STX TRAIL_HEAD
    LDA HX
    STA TRAIL_X, X
    LDA HY
    STA TRAIL_Y, X
:   RTS

; trail point for the current partner -> TX, TY
TrailTarget:
    LDX CUR
    LDA TRAIL_HEAD
    SEC
    SBC TabLag, X
    AND #$0F
    TAX
    LDA TRAIL_X, X
    STA TX
    LDA TRAIL_Y, X
    STA TY
    RTS
TabLag:
    .byte LAG*1, LAG*2, LAG*3

; ---------------------------------------------------------------------------
; Exchange helpers (dispatch on CUR)
XchgSlot0:
    LDA CUR
    BEQ :+
    CMP #$01
    BEQ :++
    JMP Xchg0_2
:   JMP Xchg0_0
:   JMP Xchg0_1

XchgSlotX:                      ; X = slot $D..$12 (X preserved)
    LDA CUR
    BEQ :+
    CMP #$01
    BEQ :++
    JMP XchgW_2
:   JMP XchgW_0
:   JMP XchgW_1
LoadSlotX:
    LDA CUR
    BEQ :+
    CMP #$01
    BEQ :++
    JMP LoadW_2
:   JMP LoadW_0
:   JMP LoadW_1
UnloadSlotX:
    LDA CUR
    BEQ :+
    CMP #$01
    BEQ :++
    JMP UnloadW_2
:   JMP UnloadW_0
:   JMP UnloadW_1

; Bring the partner's weapon slots of GROUPS into the real slots.  When the
; player's slot is idle its contents don't matter, so a one-way copy is used.
GroupsIn:
    LDA #$00
    STA LOADED
    LDX #$0D
@l: LDA TabGrpOfSlot-$0D, X
    AND GROUPS
    BEQ @n
    LDA ObjState, X
    BNE @x
    JSR LoadSlotX
    LDA TabSlotBit-$0D, X
    ORA LOADED
    STA LOADED
    JMP @n
@x: JSR XchgSlotX
@n: INX
    CPX #$13
    BNE @l
    RTS

GroupsOut:
    LDX #$0D
@l: LDA TabGrpOfSlot-$0D, X
    AND GROUPS
    BEQ @n
    LDA TabSlotBit-$0D, X
    AND LOADED
    BEQ @x
    JSR UnloadSlotX
    JMP @n
@x: JSR XchgSlotX
@n: INX
    CPX #$13
    BNE @l
    RTS

TabGrpOfSlot:
    .byte G_SWORD, G_SHOT, G_BOOM, G_BOMB, G_BOMB, G_ARROW
TabSlotBit:
    .byte $01, $02, $04, $08, $10, $20

.include "xchg_main.inc"

; ---------------------------------------------------------------------------
; Process one partner.
;
; The partner's sword is handled here (cheap): a 12-frame swing whose
; extended blade is published in the partner's slot-$D context, so the
; game's own collision code (via CloneHits) deals the damage.  Sword beams
; and B items run the game's own code on the swapped-in context.
SWING_LEN = 12

ProcessClone:
    LDY CUROFF
    LDA ST_X, Y
    STA CX
    LDA ST_Y, Y
    STA CY
    LDA ST_DIR, Y
    STA CDIR
    LDX CUR
    LDA #$00
    STA CL_WANT, X
    STA MOVED
    STA CINPUT
    STA GROUPS
    LDA CL_ACD, X
    ORA CL_ICD, X
    ORA CL_POSE, X
    ORA CL_ATKT, X
    BEQ @nocd
    LDA CL_ACD, X
    BEQ :+
    DEC CL_ACD, X
:   LDA CL_ICD, X
    BEQ :+
    DEC CL_ICD, X
:   LDA CL_POSE, X
    BEQ :+
    DEC CL_POSE, X
:   LDA CL_ATKT, X              ; swing in progress
    BEQ @nocd
    INC CL_ATKT, X
    LDA CL_ATKT, X
    CMP #(SWING_LEN+1)
    BCC @nocd
    LDA #$00
    STA CL_ATKT, X
@nocd:
    ; busy swinging or using an item: CSTATE <> 0 freezes movement
    LDA CL_ATKT, X
    ORA CL_POSE, X
    STA CSTATE

    LDA THINKER                 ; one partner thinks per frame, the
    CMP CUR                     ; others keep doing what they decided
    BNE :+
    JSR Think                   ; AI: moves CX/CY, sets CDIR, CINPUT, CL_WANT
    JSR Remember
    JMP :++
:   JSR Coast
:
    LDY CUROFF
    LDA CX
    STA ST_X, Y
    LDA CY
    STA ST_Y, Y
    LDA CDIR
    STA ST_DIR, Y

    ; ---- start a swing ----
    LDX CUR
    LDA CL_WANT, X
    LSR
    BCC @nosw
    LDA CSTATE
    BNE @nosw
    LDA SWING_GATE
    BNE @nosw
    LDA Items
    BEQ @nosw
    LDA #$01
    STA CL_ATKT, X
    LDA #12                     ; sword cooldown (was 18)
    STA CL_ACD, X
    LDA #$04
    LDY HEAVY
    CPY #CROWD2
    BCC :+
    LDA #$08
:   STA SWING_GATE
@nosw:
    LDA CL_ATKT, X
    BEQ :+
    JSR SwordBlade
:

    ; ---- B item ----
    LDX CUR
    LDA CL_WANT, X
    AND #$04                    ; a bomb for a breakable wall
    BEQ @nowb
    LDA CSTATE
    BEQ @wb1
    JMP @noit
@wb1:
    JSR ArmedOk
    BCS @wb2
    JMP @noit
@wb2:
    LDA #$01
    STA FORCEBOMB
    LDA #(G_BOMB | $80)
    ORA GROUPS
    STA GROUPS
    JMP @noit
@nowb:
    LDA CL_WANT, X
    AND #$10                    ; a bomb for a Dodongo (its weakness)
    BEQ @nodb
    LDA CSTATE
    BNE @noit
    JSR ArmedOk
    BCC @noit
    LDA #$03
    STA FORCEBOMB
    LDA #(G_BOMB | $80)
    ORA GROUPS
    STA GROUPS
    JMP @noit
@nodb:
    LDA CL_WANT, X
    AND #$08                    ; an arrow at a far monster
    BEQ @noar
    LDA CSTATE
    BNE @noit
    JSR ArmedOkArrow
    BCC @noit
    LDA #$02
    STA FORCEBOMB
    LDA #(G_ARROW | $80)
    ORA GROUPS
    STA GROUPS
    JMP @noit
@noar:
    LDA CL_WANT, X
    AND #$20                    ; the candle for a secret bush
    BEQ @nofi
    LDA CSTATE
    BNE @noit
    JSR ArmedOk
    BCC @noit
    LDA #$04
    STA FORCEBOMB
    LDA #(G_BOMB | $80)
    ORA GROUPS
    STA GROUPS
    JMP @noit
@nofi:
    LDA CL_WANT, X
    AND #$02
    BEQ @noit
    LDA CSTATE
    BNE @noit
    JSR ArmedOk
    BCC @noit
    LDY SelectedItemSlot
    LDA TabItemGroups, Y
    ORA GROUPS
    STA GROUPS
    LDA #$80                    ; remember: wield an item this frame
    ORA GROUPS
    STA GROUPS
@noit:
    ; ---- weapons already out (beam, boomerang, bombs/fire, arrow/rod) ----
    LDA CL_MASK, X
    AND #$3E
    ORA GROUPS
    BNE :+
    JMP FastDraw
:   LDA CL_MASK, X
    AND #$02
    BEQ :+
    LDA #G_SHOT
    ORA GROUPS
    STA GROUPS
:   LDA CL_MASK, X
    AND #$04
    BEQ :+
    LDA #G_BOOM
    ORA GROUPS
    STA GROUPS
:   LDA CL_MASK, X
    AND #$18
    BEQ :+
    LDA #G_BOMB
    ORA GROUPS
    STA GROUPS
:   LDA CL_MASK, X
    AND #$20
    BEQ :+
    LDA #(G_ARROW | G_SHOT | G_BOMB)
    ORA GROUPS
    STA GROUPS
:   LDA GROUPS
    BEQ :+
    JSR Slow
:   JMP FastDraw

; Is another weapon allowed out now?  (limits the per-frame CPU cost)
; C = 1 if yes.
ArmedOkArrow:                   ; (same CPU budget as the other weapons)
    LDA HEAVY
    CMP #CROWD
    BCS ArmedNo
    BCC ArmedCount
ArmedOk:
    CPX BOMBER                  ; the wall bomber may always place its bomb
    BEQ ArmedCount
    LDA HEAVY
    CMP #CROWD
    BCS ArmedNo
ArmedCount:
    LDA CL_MASK, X
    AND #$3E
    BNE ArmedNo                     ; one extra weapon per partner
    LDA #$00
    STA TMP2
    LDY #NCL-1
:   LDA CL_MASK, Y
    AND #$3E
    BEQ :+
    INC TMP2
:   DEY
    BPL :--
    LDA TMP2
    CMP #MAXARMED
    BCS ArmedNo
    SEC
    RTS
ArmedNo:
    CLC
    RTS

; Publish the blade in the partner's slot-$D context while extended, and
; ask for a sword beam on the frame the blade retracts (full health).
SwordBlade:
    LDX CUR
    LDY CUROFF
    LDA CL_ATKT, X
    CMP #$04
    BCC @off
    CMP #$0C
    BCS @off
    BNE :+
@off:
    LDA #$00
    STA ST_STATE+1, Y
    LDA CL_MASK, X
    AND #$FE
    STA CL_MASK, X
    ; beam at the end of the swing
    LDA CL_ATKT, X
    CMP #$0C
    BNE @rts
    LDA FULLHP
    BEQ @rts
    LDA CL_MASK, X
    AND #$02
    BNE @rts
    JSR ArmedOk
    BCC @rts
    LDA GROUPS
    ORA #(G_SHOT | $40)         ; $40: make a beam
    STA GROUPS
@rts:
    RTS
:   LDA #$02                    ; extended
    STA ST_STATE+1, Y
    LDA CDIR
    STA ST_DIR+1, Y
    JSR DirIndex                ; X = 0 up, 1 down, 2 left, 3 right
    LDA CX
    CLC
    ADC TabSwordDX, X
    STA ST_X+1, Y
    LDA CY
    CLC
    ADC TabSwordDY, X
    STA ST_Y+1, Y
    LDX CUR
    LDA CL_MASK, X
    ORA #$01
    STA CL_MASK, X
    RTS

; X <- 0 up, 1 down, 2 left, 3 right for CDIR
DirIndex:
    LDX #$00
    LDA CDIR
    AND #$08
    BNE :+
    INX
    LDA CDIR
    AND #$04
    BNE :+
    INX
    LDA CDIR
    AND #$02
    BNE :+
    INX
:   RTS

; blade position relative to Link (PlayerToWeaponOffsets, state 2)
TabSwordDX: .byte $FF, $01, $F5, $0B
TabSwordDY: .byte $F6, $0D, $03, $03
; blade sprites: up, down, left, right
TabBladeT1: .byte $20, $20, $82, $82
TabBladeT2: .byte $00, $00, $84, $84
TabBladeX1: .byte $03, $05, $FD, $0B
TabBladeX2: .byte $00, $00, $F5, $13
TabBladeA:  .byte $00, $80, $40, $00

; ---- slow path: run the game's own weapon code on the partner's context ----
; GROUPS: weapon groups to swap in; $40 = make a sword beam, $80 = wield item
Slow:
    JSR SavePlayer
    LDA InvArrow                ; partners' arrows: wooden if the player has none
    STA SAV_ARROW
    BNE :+
    LDA #$01
    STA InvArrow
:
    ; slot 0 (position/direction) is only needed to wield, and for the
    ; boomerang and the rod, which follow their owner
    LDA GROUPS
    AND #($C0 | G_BOOM | G_ARROW)
    STA NEED0
    BEQ :+
    JSR XchgSlot0               ; slot 0 now holds this partner
    LDA #$00
    STA ObjState                ; (Link state of the partner: unused)
:   JSR GroupsIn
    LDA #$01
    STA ObjInvincibilityTimer   ; partners' fire never "harms" slot 0

    BIT GROUPS
    BVC :+
    LDX #$0E                    ; sword beam
    LDA ObjState, X
    BNE :+
    JSR MakeSwordShot
:   BIT GROUPS
    BPL :+
    JSR UseItem
    LDX CUR
    LDA #$08
    STA CL_POSE, X
:
    ; update the weapons with the game's own code
    LDA GROUPS
    AND #G_SHOT
    BEQ :+
    LDX #$0E
    LDA ObjState, X
    BEQ :+
    FAR 5, UpdateSwordShotOrMagicShot
    ; partners' beams vanish instead of splitting (saves a lot of CPU)
    LDA ObjState+$0E
    AND #$81
    CMP #$01
    BNE :+
    LDA #$00
    STA ObjState+$0E
:   LDA GROUPS
    AND #G_BOOM
    BEQ :+
    LDX #$0F
    LDA ObjState, X
    BEQ :+
    FAR 5, UpdateBoomerangOrFood
:   LDA GROUPS
    AND #G_BOMB
    BEQ :++
    LDX #$10
    LDA ObjState, X
    BEQ :+
    FAR 5, UpdateBombOrFire
:   LDX #$11
    LDA ObjState, X
    BEQ :+
    FAR 5, UpdateBombOrFire
:   JSR RockCheck
    JSR TreeCheck
    LDA GROUPS
    AND #G_ARROW
    BEQ :+
    LDX #$12
    LDA ObjState, X
    BEQ :+
    FAR 5, UpdateRodOrArrow
:
    LDA SAV_ARROW
    STA InvArrow
    ; new active mask for the swapped slots (bit 0, the blade, is ours)
    LDX CUR
    LDA CL_MASK, X
    AND #$01
    STA TMP
    LDA ObjState+$0E
    BEQ :+
    LDA #$02
    ORA TMP
    STA TMP
:   LDA ObjState+$0F
    BEQ :+
    LDA #$04
    ORA TMP
    STA TMP
:   LDA ObjState+$10
    BEQ :+
    LDA #$08
    ORA TMP
    STA TMP
:   LDA ObjState+$11
    BEQ :+
    LDA #$10
    ORA TMP
    STA TMP
:   LDA ObjState+$12
    BEQ :+
    LDA #$20
    ORA TMP
    STA TMP
:   ; (slots not swapped in still hold the player's weapons: keep our bits)
    LDA GROUPS
    AND #G_SHOT
    BNE :+
    LDA CL_MASK, X
    AND #$02
    ORA TMP
    STA TMP
:   LDA GROUPS
    AND #G_BOOM
    BNE :+
    LDA CL_MASK, X
    AND #$04
    ORA TMP
    STA TMP
:   LDA GROUPS
    AND #G_BOMB
    BNE :+
    LDA CL_MASK, X
    AND #$18
    ORA TMP
    STA TMP
:   LDA GROUPS
    AND #G_ARROW
    BNE :+
    LDA CL_MASK, X
    AND #$20
    ORA TMP
    STA TMP
:   LDA TMP
    STA CL_MASK, X

    JSR GroupsOut
    LDA SAV_INV
    STA ObjInvincibilityTimer
    LDA NEED0
    BEQ :+
    LDA #$00
    STA ObjState
    JMP XchgSlot0               ; give slot 0 back to the player
:   RTS

TabItemGroups:  ; boomerang, bomb, arrow, -, candle, flute, food, potion, rod
    .byte G_BOOM, G_BOMB, G_ARROW, 0, G_BOMB, 0, 0, 0, (G_ARROW|G_SHOT|G_BOMB)
    .byte 0, 0, 0, 0, 0, 0, 0

; ---------------------------------------------------------------------------
; Use the player's selected B item (free of charge).
UseItem:
    LDX CUR
    LDA #90
    STA CL_ICD, X
    LDA FORCEBOMB               ; wall bombing: a bomb whatever is selected
    BEQ :++
    LDY #$00
    STY FORCEBOMB
    CMP #$02
    BNE :+
    JMP UseArrow
:   CMP #$03
    BEQ @fbomb
    CMP #$04
    BNE @fb1
    JMP @fcandle
@fb1:
    JMP @bomb
:   LDA SelectedItemSlot
    BNE @notBoom
    LDA InvBoomerang
    ORA InvMagicBoomerang
    BEQ @r0
    LDA ObjState+$0F
    BNE @r0
    FAR 5, WieldBoomerang
@r0:
    RTS
@notBoom:
    CMP #$01
    BNE @notBomb
@bomb:
    LDA ObjState+$10
    ORA ObjState+$11
    BNE @r0
    LDA InvBombs
    BEQ @r0
    JSR WieldBomb               ; (WRAM, no bank switching)
    LDX CUR
    LDA #150
    STA CL_ICD, X
    LDA ObjState+$10
    ORA ObjState+$11
    BEQ :+
    LDA #$01
    STA BPLACED
:   RTS
@fbomb:                         ; a bomb for a Dodongo (not a wall job)
    LDA ObjState+$10
    ORA ObjState+$11
    BNE @r0
    LDA InvBombs
    BEQ @r0
    JSR WieldBomb
    LDX CUR
    LDA #100
    STA CL_ICD, X
    RTS
@notBomb:
    CMP #$02
    BNE @notArrow
    LDA Bow
    BEQ @r1
    LDA InvArrow
    BEQ @r1
    LDA ObjState+$12
    BNE @r1
    FAR 5, WieldArrow
@r1:
    RTS
@notArrow:
    CMP #$04
    BNE @notCandle
@candle:
    LDA InvCandle
    BEQ @r1
    LDA ObjState+$10
    ORA ObjState+$11
    BNE @r1
    LDX CUR
    LDA CL_CANDLE, X
    STA UsedCandle
    JSR WieldCandle
    LDX CUR
    LDA UsedCandle
    STA CL_CANDLE, X
    LDA #120
    STA CL_ICD, X
    RTS
@notCandle:
    CMP #$08
    BNE @r1
    LDA ObjState+$12
    ORA ObjState+$0E
    BNE @r1
    FAR 5, WieldRod
    RTS
@fcandle:                       ; burn a secret bush (whatever item is selected)
    JSR @candle
    LDA ObjState+$10
    ORA ObjState+$11
    BEQ :+
    LDA #$01
    STA BPLACED
:   RTS

; A partner's arrow: free and always available (no bow, arrows or
; rupees needed).  Slow has made InvArrow at least wooden.
UseArrow:
    LDA ObjState+$12
    BNE @r
    LDA Bow
    STA SAV_BOW
    LDA InvRupees
    STA SAV_RUP
    LDA #$01
    STA Bow
    STA InvRupees
    FAR 5, WieldArrow
    LDA SAV_BOW
    STA Bow
    LDA SAV_RUP
    STA InvRupees
    LDX CUR
    LDA #24
    STA CL_ICD, X
@r: RTS

; SL, SR <- next two sprite records from the rolling pool
NextSpritePair:
    LDY RollingSpriteIndex
    LDA SpriteOffsets, Y
    STA SL
    LDA SpriteOffsets+1, Y
    STA SR
    INY
    INY
    CPY #$28
    BCC :+
    TYA
    SBC #$28
    TAY
:   STY RollingSpriteIndex
    RTS

; ---------------------------------------------------------------------------
; Draw the partner (and its blade) straight from its context.
; Zero-page scratch: [00] x, [01] y, [02] left tile, [03] right tile,
; [04] left attr, [05] right attr, [06] palette, [07] original tile
FastDraw:
    LDY CUROFF
    LDX CUR
    LDA TabPal, X               ; red = 2, blue = 1, third partner = 3
    BPL :+
    LDA FrameCounter
    AND #$01
    CLC
    ADC #$01
:   STA $06
    LDA CL_ATKT, X
    ORA CL_POSE, X
    BEQ @walk
    JSR DirIndex                ; attack / item pose
    LDA TabATL, X
    STA $02
    LDA TabATR, X
    STA $03
    LDA TabAAt, X
    JMP @attr
@walk:
    LDA CINPUT
    BEQ @frame
    LDA ST_ACNT, Y              ; walking animation
    SEC
    SBC #$01
    BNE :+
    LDA ST_AFRM, Y
    EOR #$01
    STA ST_AFRM, Y
    LDA #$06
:   STA ST_ACNT, Y
@frame:
    LDX CDIR
    LDA TabDirCat, X
    ORA ST_AFRM, Y
    TAX
    LDA TabFTL, X
    STA $02
    LDA TabFTR, X
    STA $03
    LDA TabFAt, X
@attr:
    ORA $06
    STA $04
    STA $05
    ; shield tiles (same rules as for the player)
    LDX #$00                    ; X = which side (0 left, 1 right)
    LDA InvMagicShield
    BNE @magic
    LDA CDIR
    CMP #$04
    BNE @pos
    LDA $02
    CMP #$0B
    BCS @pos
    STA $07
    ADC #$50
    STA $02
    JMP @fix
@magic:
    LDA CDIR
    LSR
    BCC :+
    INX
:   LDA $02, X
    STA $07
    CMP #$0B
    BCS @pos
    TAY
    LDA TabMagicHead, Y
    BEQ @fix
    STA $02, X
@fix:
    LDA $07
    CMP #$0A
    BNE @pos
    LDA $04, X
    AND #$0F
    STA $04, X
@pos:
    LDA CY
    CLC
    ADC YOFF
    STA $01
    JSR NextSpritePair
    LDX SL
    LDA $01
    STA Sprites, X
    LDA $02
    STA Sprites+1, X
    LDA $04
    STA Sprites+2, X
    LDA CX
    STA Sprites+3, X
    LDX SR
    LDA $01
    STA Sprites, X
    LDA $03
    STA Sprites+1, X
    LDA $05
    STA Sprites+2, X
    LDA CX
    CLC
    ADC #$08
    STA Sprites+3, X

    ; the blade
    LDX CUR
    LDA CL_MASK, X
    LSR
    BCC @rts
    JSR DirIndex
    STX TMP
    JSR NextSpritePair
    LDY TMP
    LDA Items                   ; sword palette: wood 0, white 1, magic 2
    SEC
    SBC #$01
    ORA TabBladeA, Y
    STA $04
    LDA CY
    CLC
    ADC TabSwordDY, Y
    STA $01
    LDX SL
    STA Sprites, X
    LDA TabBladeT1, Y
    STA Sprites+1, X
    LDA $04
    STA Sprites+2, X
    LDA CX
    CLC
    ADC TabBladeX1, Y
    STA Sprites+3, X
    LDX SR
    LDA TabBladeT2, Y
    BEQ @one
    STA Sprites+1, X
    LDA $01
    STA Sprites, X
    LDA $04
    STA Sprites+2, X
    LDA CX
    CLC
    ADC TabBladeX2, Y
    STA Sprites+3, X
    RTS
@one:
    LDA #$F8                    ; vertical blade uses one sprite
    STA Sprites, X
@rts:
    RTS

; attack poses: up, down, left, right
TabATL: .byte $18, $14, $12, $10
TabATR: .byte $1A, $16, $10, $12
TabAAt: .byte $00, $00, $40, $00

TabPal:
    .byte $02, $01, $03         ; red, blue, and the 4th sprite palette
; walking frames by (direction category * 2 + movement frame)
TabDirCat:      ; dir 0..8 -> category*2  (right 0, left 2, down 4, up 6)
    .byte 4, 0, 2, 0, 4, 0, 0, 0, 6
TabFTL: .byte $00, $04, $02, $06, $08, $0A, $0C, $0E
TabFTR: .byte $02, $06, $00, $04, $0A, $08, $0E, $0C
TabFAt: .byte $00, $00, $40, $40, $00, $40, $00, $40
; magic shield head tiles: LinkHeadTiles $02,$06,$08,$0A -> $80,$54,$60,$60
TabMagicHead:
    .byte $00, $00, $80, $00, $00, $00, $54, $00, $60, $00, $60

; ---------------------------------------------------------------------------
; Remember this frame's movement so the next two frames can repeat it.
Remember:
    LDX CUR
    LDA MOVED
    BNE :+
    STA CL_MDIR, X
    RTS
:   LDA CINPUT
    STA CL_MDIR, X
    LDA LASTSTEP
    STA CL_MSPD, X
    LDA COLLIDE
    STA CL_MCOL, X
    LDA REMAIN
    STA CL_MREM, X
    RTS

Coast:
    LDA CSTATE                  ; no moving while swinging
    BNE @rts
    LDX CUR
    LDA CL_MDIR, X
    BEQ @rts
    LDA CL_MREM, X
    BEQ @rts
    CMP CL_MSPD, X
    BCC :+
    LDA CL_MSPD, X
:   STA TMP2
    SEC
    LDA CL_MREM, X
    SBC TMP2
    STA CL_MREM, X
    LDA CL_MCOL, X
    STA COLLIDE
    LDA CL_MDIR, X
    LDX TMP2
    JMP StepDirN
@rts:
    RTS

; ---------------------------------------------------------------------------
; AI.  Works on CX, CY, CDIR, CSTATE.  Sets CINPUT and CL_WANT.
Think:
    LDX CUR
    LDA IGN_T, X
    BEQ :+
    DEC IGN_T, X
:   LDA CL_MODE, X
    CMP #$01
    BNE :+
    JMP Fight
:   CMP #$02
    BNE Follow
    JMP Return

Follow:
    ; look for something to fight every time this partner thinks
    ; (every other frame in crowded rooms: CPU budget)
    LDA HEAVY
    CMP #CROWD
    BCC :+
    LDA FrameCounter
    AND #$01
    BNE @nolook
:   JSR FindTarget
    BCC @nolook
    LDX CUR
    STA CL_TGT, X
    CPX BOMBER                  ; fighting first: let another partner take the wall
    BNE :+
    LDY #$FF
    STY BOMBER
:
    LDA #$01
    STA CL_MODE, X
    LDA #$00
    STA CL_STUCK, X
    JMP Fight
@nolook:
    LDA CSTATE                  ; no moving while swinging
    BEQ :+
    RTS
:   JSR DigCheck                ; a big Digdogger (nothing to hit yet): play the recorder
    JSR WallTask                ; nothing to fight: bomb a breakable wall?
    BCC :+
    RTS
:   LDA LSTILL                  ; the player has stopped a while and we are
    CMP #40                     ; close by: stay put (no shuffling about
    BCC @form                   ; in tight corners)
    LDA HX
    SEC
    SBC CX
    JSR AbsU
    STA TMP
    LDA HY
    SEC
    SBC CY
    JSR AbsU
    CLC
    ADC TMP
    BCS @form
    CMP #$40
    BCS @form
    JMP @idle
@form:
    JSR VSpot                   ; V formation behind the player
    BCS @trail                  ; (spot in a wall: walk the player's trail)
    JSR Delta
    LDA ADX
    CLC
    ADC ADY
    BCS @trail
    CMP #$30                    ; far from it: catch up along the trail
    BCS @trail
    CMP #$00
    BEQ @idle
    LDX #$01
    CMP #$08
    BCC :+
    INX
:   STX SPEED
    LDA #$01
    STA COLLIDE
    JSR MoveStepDirect
    LDA MOVED
    BNE @rts
    JMP @idle
@trail:
    JSR TrailTarget
    JSR ClampT                  ; (the player can stand outside the bounds
    LDA #$00                    ;  at the room's edge)
    STA COLLIDE
    ; caught up with the trail (the player stopped)?  Then take the
    ; formation spot instead
    LDA TX
    SEC
    SBC CX
    JSR AbsU
    STA TMP
    LDA TY
    SEC
    SBC CY
    JSR AbsU
    CLC
    ADC TMP
    CMP #$06
    BCS :+
    JMP @idle                   ; (stay in line: no hopping between spots)
:   JSR Delta
    LDA ADX
    CLC
    ADC ADY
    BEQ @idle
    LDX #$01
    CMP #$10
    BCC :+
    INX
:   STX SPEED
    JSR MoveStep
    LDA MOVED
    BNE @rts
@idle:
    LDA HDIR                    ; stand facing the same way as the player
    STA CDIR
@rts:
    RTS

; V spot -> TX, TY (kept in the room).  C = 1 if it is in a wall.
VSpot:
    LDA CDIR
    PHA
    LDA HDIR
    STA CDIR
    JSR DirIndex                ; X = 0 up, 1 down, 2 left, 3 right
    PLA
    STA CDIR
    STX TMP
    TXA
    ASL
    ADC TMP                     ; dir*3
    ADC CUR                     ; + partner
    TAX
    LDA TabFormDX, X
    LDY HX
    JSR AddSat
    STA TX
    LDA TabFormDY, X
    LDY HY
    JSR AddSat
    STA TY
    JSR ClampT
    JMP FreeAtT

; A <- Y + A (A signed), saturated to 0..255
AddSat:
    STY TMP2
    CMP #$80
    BCS @neg
    CLC
    ADC TMP2
    BCC :+
    LDA #$FF
:   RTS
@neg:
    CLC
    ADC TMP2
    BCS :+
    LDA #$00
:   RTS

; formation spot behind the player (in front if that is a wall)
Formation:
    LDA #$01
    STA COLLIDE
    LDA CDIR
    PHA
    LDA HDIR
    STA CDIR
    JSR DirIndex                ; X = 0 up, 1 down, 2 left, 3 right
    PLA
    STA CDIR
    STX TMP
    TXA
    ASL
    ADC TMP                     ; dir*3
    ADC CUR                     ; + partner
    TAX
    STX FTMP
    LDA HX
    CLC
    ADC TabFormDX, X
    STA TX
    LDA HY
    CLC
    ADC TabFormDY, X
    STA TY
    JSR ClampT
    LDA TX                      ; clamped onto the player? (in a doorway)
    SEC
    SBC HX
    JSR AbsU
    STA TMP
    LDA TY
    SEC
    SBC HY
    JSR AbsU
    CLC
    ADC TMP
    CMP #$08
    BCC :+
    JSR FreeAtT
    BCC ClampT
:   LDX FTMP                    ; blocked: use the mirrored spot in front
    LDA HX
    SEC
    SBC TabFormDX, X
    STA TX
    LDA HY
    SEC
    SBC TabFormDY, X
    STA TY
; keep (TX,TY) inside the room
ClampT:
    LDA TX
    CMP RoomBoundLeft
    BCS :+
    LDA RoomBoundLeft
:   CMP RoomBoundRight
    BCC :+
    LDA RoomBoundRight
:   STA TX
    LDA TY
    CMP RoomBoundUp
    BCS :+
    LDA RoomBoundUp
:   CMP RoomBoundDown
    BCC :+
    LDA RoomBoundDown
:   STA TY
    RTS

; Is the spot (TX,TY) walkable for Link's feet?  C = 1 if blocked.
FreeAtT:
    LDA TY
    CLC
    ADC #$0B
    SEC
    SBC #$40
    BCC @blk
    LSR
    LSR
    LSR
    STA FTD                     ; row
    LDA TX
    JSR @col
    BCS @blk
    LDA TX
    CLC
    ADC #$0F
    BCS @blk
@col:                           ; A = x -> C = 1 if that column's tile blocks
    AND #$F8
    LSR
    LSR
    TAY
    LDA PlayAreaColumnAddrs, Y
    STA $00
    LDA PlayAreaColumnAddrs+1, Y
    STA $01
    LDY FTD
    LDA ($00), Y
    JMP TileBlocks
@blk:
    SEC
    RTS

; player facing up, down, left, right x partners 0..2 (spots behind him)
; V formation: back-left and back-right of the player (by facing: up, down,
; left, right; partner 0 then 1; the third column is unused with NCL = 2)
TabFormDX: .byte $EC, $14, $00,  $EC, $14, $00,  $14, $14, $1C,  $EC, $EC, $E4
TabFormDY: .byte $10, $10, $18,  $F0, $F0, $E8,  $EE, $12, $00,  $EE, $12, $00

Return:
    LDA CSTATE
    BEQ :+
    RTS
:   JSR TrailTarget
    JSR ClampT                  ; (never into the room's walls)
    JSR Delta
    LDA ADX
    CLC
    ADC ADY
    BCS @warp
    CMP #$06
    BCS :+
    LDX CUR                     ; back in line
    LDA #$00
    STA CL_MODE, X
    RTS
:   CMP #$A0
    BCS @warp
    LDX CUR
    LDA CL_STUCK, X
    CMP #24
    BCS @warp
    LDA #$01
    STA COLLIDE
    LDA #$02
    STA SPEED
    JSR MoveStep
    JMP StuckCheck
@warp:
    LDA TX
    STA CX
    LDA TY
    STA CY
    LDX CUR
    LDA #$00
    STA CL_MODE, X
    STA CL_STUCK, X
    RTS

StuckCheck:
    LDX CUR
    LDA CX
    CMP CL_LX, X
    BNE @moved
    LDA CY
    CMP CL_LY, X
    BNE @moved
    INC CL_STUCK, X
    RTS
@moved:
    LDA CX
    STA CL_LX, X
    LDA CY
    STA CL_LY, X
    LDA CL_STUCK, X
    BEQ :+
    DEC CL_STUCK, X
:   RTS

; ---------------------------------------------------------------------------
Fight:
    ; every 8 frames, switch to whichever monster is now nearest
    ; (every 16 in crowded rooms)
    LDA HEAVY
    CMP #CROWD
    LDA FrameCounter
    BCC :+
    AND #$0F
    BNE @keep
:   AND #$07
    BNE @keep
    JSR FindTarget
    BCC @keep
    LDX CUR
    CMP CL_TGT, X
    BEQ @keep
    STA TMPX                    ; switch only if clearly nearer than the
    LDY CL_TGT, X               ; current one (no flip-flopping between two)
    JSR IsTarget
    BCC @switch
    LDA ObjX, Y
    SEC
    SBC CX
    JSR AbsU
    LSR
    STA TMP
    LDA ObjY, Y
    SEC
    SBC CY
    JSR AbsU
    LSR
    CLC
    ADC TMP
    STA TMP                     ; current target's distance score
    LDA BESTD
    CLC
    ADC #$0C
    BCS @keep
    CMP TMP
    BCS @keep
@switch:
    LDX CUR
    LDA TMPX
    STA CL_TGT, X
    LDA #$00
    STA CL_STUCK, X
@keep:
    LDX CUR
    LDY CL_TGT, X
    JSR IsTarget                ; (no leash: the whole room is fair game)
    BCC @lost
    LDA CL_STUCK, X
    CMP #40
    BCC @go
@lost:
    LDA CL_STUCK, X             ; couldn't get to it: leave it alone a while
    CMP #40
    BCC :+
    LDA CL_TGT, X
    STA IGN_S, X
    LDA #150
    STA IGN_T, X
:   JSR FindTarget              ; straight on to the next monster, if any
    LDX CUR
    PHA
    LDA #$00                    ; (carry kept)
    STA CL_STUCK, X
    PLA
    BCC :+
    CMP CL_TGT, X               ; the one we just gave up on: go back instead
    BEQ :+
    STA CL_TGT, X
    TAY
    JMP @go
:   LDA #$02
    STA CL_MODE, X
    JMP Return
@go:
    LDA ObjX, Y
    STA TX
    LDA ObjY, Y
    STA TY
    JSR Delta
    ; attack along the axis with the larger distance
    LDA ADX
    CMP ADY
    BCC @vert
    LDA SDX
    BNE :+
    LDA #$01
:   STA FACE
    LDA ADX
    STA ALONG
    LDA ADY
    STA PERP
    JMP @decide
@vert:
    LDA SDY
    BNE :+
    LDA #$04
:   STA FACE
    LDA ADY
    STA ALONG
    LDA ADX
    STA PERP
@decide:
    LDA CSTATE
    BEQ :+
    RTS                         ; busy swinging
:   JSR BossTactic              ; bosses with a weakness: use it
    BCC :+
    RTS
:   LDA PERP
    CMP #$09
    BCS @approach
    LDA ALONG
    CMP #$17
    BCS @ranged
    LDA FACE                    ; in reach: swing
    STA CDIR
    LDX CUR
    LDY CL_TGT, X               ; (not while it is still reeling from a hit)
    LDA ObjInvincibilityTimer, Y
    BNE @rts
    LDA CL_ACD, X
    BNE @rts
    LDA CL_WANT, X
    ORA #$01
    STA CL_WANT, X
@rts:
    RTS
@ranged:
    LDA PERP                    ; lined up but far: sword beam or an arrow
    CMP #$05
    BCS @approach
    LDA FACE
    STA CDIR
    LDX CUR
    JSR ArmedOkArrow            ; (nothing to shoot with: walk up instead
    BCC @approach               ;  of swinging at the air)
    JSR ArmedOk
    BCC @arrow
    LDA FULLHP
    BEQ @arrow
    LDA Items
    BEQ @arrow
    LDA CL_MASK, X
    AND #$02
    BNE @arrow
    LDA CL_ACD, X
    BNE @arrow
    LDA CL_WANT, X
    ORA #$01
    STA CL_WANT, X
    RTS
@arrow:
    LDA CL_MASK, X              ; partners have unlimited arrows
    AND #$20
    BNE @approach
    LDA CL_ICD, X
    BNE @approach
    LDA ALONG
    CMP #$B0
    BCS @approach
    LDA CL_WANT, X
    ORA #$08
    STA CL_WANT, X
    RTS
@approach:
    LDA #$01
    STA COLLIDE
    LDA #$02
    STA SPEED
    LDX CUR                     ; line up when off by 6+ px; once lining up,
    LDA FACE                    ; keep at it until within 3 px (fewer turns
    AND #$03                    ; after a moving monster)
    BEQ @apvt
    LDA CL_MDIR, X
    AND #$0C
    JMP @thr
@apvt:
    LDA CL_MDIR, X
    AND #$03
@thr:
    BEQ :+
    LDA #$03
    BNE :++
:   LDA #$06
:   STA TMP
    LDA FACE
    AND #$03
    BEQ @apv
    LDA PERP                    ; horizontal attack: line up Y, then close X
    CMP TMP
    BCC @aph
    LDA SDY
    LDX SDX
    JMP @step
@aph:
    LDA ALONG
    CMP #$0E
    BCC @face
    LDA SDX
    LDX SDY
    JMP @step
@apv:
    LDA PERP
    CMP TMP
    BCC @apv2
    LDA SDX
    LDX SDY
    JMP @step
@apv2:
    LDA ALONG
    CMP #$0E
    BCC @face
    LDA SDY
    LDX SDX
@step:                          ; A = preferred direction, X = fallback
    JSR StepPair
    JMP StuckCheck
@face:
    LDA FACE
    STA CDIR
    RTS


; ---------------------------------------------------------------------------
; Bosses that only one weapon hurts.  Called from Fight with FACE, ALONG, PERP
; and SDX/SDY set for the current target.  C = 1 if handled this frame.
;   Dodongo ($31,$32): bombs.  Walk to the spot just ahead of its mouth, face it
;                      and drop a bomb.  Once a bomb has stunned it the sword
;                      works, so the normal fight takes over.
;   Gohma ($33,$34):   arrows only (the sword does nothing).  Shoot as soon as
;                      lined up, at any range.
;   Big Digdogger ($38,$39): the recorder splits it into small ones the sword
;                      can hurt; played once (if the player owns a recorder).
BossTactic:
    LDX CUR
    LDY CL_TGT, X
    LDA ObjType, Y
    CMP #$31
    BEQ @dodo
    CMP #$32
    BEQ @dodo
    CMP #$33
    BEQ @gohma
    CMP #$34
    BEQ @gohma
    CMP #$38
    BEQ @dig
    CMP #$39
    BEQ @dig
@no:
    CLC
    RTS
@gohma:
    LDA PERP
    CMP #$05
    BCS @no                     ; not lined up yet: walk up as usual
    LDA FACE
    STA CDIR
    LDX CUR
    LDA CL_MASK, X
    AND #$20
    BNE @hold                   ; an arrow is already flying
    LDA CL_ICD, X
    BNE @hold
    JSR ArmedOkArrow
    BCC @hold
    LDA CL_WANT, X
    ORA #$08
    STA CL_WANT, X
@hold:
    SEC
    RTS
@dig:
    LDA UsedFlute
    BNE @no                     ; already played (it has split up)
    LDA InvRecorder
    BEQ @no
    LDX CUR
    LDA CL_ICD, X
    BNE @hold
    JSR WieldFlute
    LDX CUR
    LDA #120
    STA CL_ICD, X
    BNE @hold
@dodo:
    LDA ObjState, Y
    CMP #$02
    BEQ @no                     ; stunned: sword time
    LDA InvBombs
    BEQ @no
    ; target spot (top-left of the partner): 24 px ahead of the mouth
    LDA ObjDir, Y
    AND #$0F
    BEQ @no
    STA TMP
    AND #$03
    BEQ @vert
    LDA ObjX, Y                 ; facing right / left
    CLC
    ADC #$08
    LDX TMP
    CPX #$01
    BEQ @r
    SEC
    SBC #$18                    ; left: centre-24
    JMP @sx
@r: CLC
    ADC #$18
@sx:STA TX
    LDA ObjY, Y
    STA TY
    JMP @goto
@vert:
    LDA ObjX, Y
    STA TX
    LDA ObjY, Y
    LDX TMP
    CPX #$04
    BEQ @d
    SEC
    SBC #$18                    ; up
    JMP @sy
@d: CLC
    ADC #$18
@sy:STA TY
@goto:
    JSR Delta
    LDA ADX
    CLC
    ADC ADY
    CMP #$04
    BCC @there
    LDA #$01
    STA COLLIDE
    LDA #$02
    STA SPEED
    JSR MoveStep
    JSR StuckCheck
    LDX CUR
    LDA CL_STUCK, X
    CMP #30
    BCS @no2                    ; can't get there: fight normally
    SEC
    RTS
@no2:
    CLC
    RTS
@there:
    LDA ObjDir, Y
    AND #$0F
    JSR Opposite                ; face the Dodongo
    STA CDIR
    LDX CUR
    LDA CL_ICD, X
    BNE @hold2
    LDA CL_WANT, X
    ORA #$10
    STA CL_WANT, X
@hold2:
    SEC
    RTS

; A big Digdogger can't be hurt until the recorder splits it up: the partners
; play the player's recorder for him (once per room), as soon as he is around.
DigCheck:
    LDA UsedFlute
    BNE @r
    LDA InvRecorder
    BEQ @r
    LDA CurLevel
    BEQ @r
    LDA GameMode
    CMP #$05
    BNE @r
    LDY #$0B
@l: LDA ObjType, Y
    CMP #$38
    BEQ @go
    CMP #$39
    BEQ @go
    DEY
    BNE @l
@r: RTS
@go:
    JMP WieldFlute

; Is the selected B item usable at this range?  C = 1 if yes.
ItemInRange:
    LDY SelectedItemSlot
    CPY #$09
    BCS @no
    LDA ALONG
    CMP TabItemMin, Y
    BCC @no
    CMP TabItemMax, Y
    BCS @no
    SEC
    RTS
@no:
    CLC
    RTS
TabItemMin: .byte $10, $00, $18, $FF, $00, $FF, $FF, $FF, $18
TabItemMax: .byte $50, $18, $A0, $00, $28, $00, $00, $00, $A0

; ---------------------------------------------------------------------------
; Delta: target (TX,TY) vs (CX,CY) -> ADX, ADY, SDX, SDY
Delta:
    LDA #$00
    STA SDX
    STA SDY
    LDA TX
    SEC
    SBC CX
    BEQ @x0
    BCS @xr
    EOR #$FF
    ADC #$01
    LDX #$02
    STX SDX
    JMP @x0
@xr:
    LDX #$01
    STX SDX
@x0:
    STA ADX
    LDA TY
    SEC
    SBC CY
    BEQ @y0
    BCS @yd
    EOR #$FF
    ADC #$01
    LDX #$08
    STX SDY
    JMP @y0
@yd:
    LDX #$04
    STX SDY
@y0:
    STA ADY
    RTS

; Move toward (TX,TY) by SPEED along one axis at a time (like Link).
MoveStep:
    JSR AxisOrder
    LDY COLLIDE                 ; walls matter: go round obstacles
    BEQ MoveDirect2
    JMP StepPairLim
MoveStepDirect:                 ; (no detours: give up when blocked)
    JSR AxisOrder
MoveDirect2:
    STX FALLB
    CMP #$00
    BEQ :+
    JSR StepDirLim
    LDA MOVED
    BNE @done
:   LDA FALLB
    BEQ @done
    JMP StepDirLim
@done:
    RTS

; Which way to step first: A = preferred, X = fallback (0 = none).
; Keep going the way we were already going while it still gets us closer,
; so a diagonal path is walked in a few long legs instead of turning back
; and forth every step (which looks like spinning on the spot).
AxisOrder:
    LDX CUR
    LDA CL_MDIR, X
    BEQ @std
    CMP SDX
    BEQ @h
    CMP SDY
    BEQ @v
@std:
    LDA ADX
    CMP ADY
    BCC :+
    LDA SDX
    BNE @h
:   LDA SDY
    BNE @v
@h: LDA SDX
    LDX SDY
    RTS
@v: LDA SDY
    LDX SDX
    RTS

; ---------------------------------------------------------------------------
; Step towards a target round obstacles.  A = preferred direction,
; X = fallback (0 = none).  When both are blocked the partner sidesteps
; (away from the fallback) for a while, trying the preferred direction
; first on every step: a simple "follow the wall" detour.
StepPairLim:                    ; the same, limited to the remaining distance
    STA PREF
    STX FALLB
    LDA #$01
    BNE StepPairGo
StepPair:
    STA PREF
    STX FALLB
    LDA #$00
StepPairGo:
    STA FTMP                    ; 1 = limit steps to the distance left
    LDX CUR
    LDA DET_T, X
    BNE :+
    JMP @normal
:   BPL @sidestep
    ; past the obstacle's edge: keep going the blocked way for a bit
    LDA DET_P, X
    JSR StepDir
    LDX CUR
    LDA MOVED
    BEQ @again
    DEC DET_T, X
    LDA DET_T, X
    AND #$7F
    BNE :+
    STA DET_T, X
:   RTS
@again:
    LDA #32                     ; blocked again: keep sidestepping
    STA DET_T, X
@sidestep:
    LDA DET_P, X                ; the way we really want to go free yet?
    JSR StepDir
    LDX CUR
    LDA MOVED
    BEQ :+
    LDA #$86                    ; yes: follow it for 6 steps
    STA DET_T, X
    RTS
:   DEC DET_T, X                ; (bits 0-5: steps left, bit 6: both
    LDA DET_T, X                ;  sides tried)
    AND #$3F
    BNE :+
    STA DET_T, X                ; detour over
    RTS
:   INC CL_STUCK, X             ; (sidestepping is no progress: this
    INC CL_STUCK, X             ;  outweighs StuckCheck's credit for moving)
    LDA DET_D, X
    BNE :+
    RTS                         ; (waiting)
:   JSR StepDir
    LDA MOVED
    BEQ :+
    RTS
:   LDX CUR
    LDA DET_T, X
    AND #$40
    BNE @back
    LDA DET_T, X                ; that side is blocked too: the other one
    ORA #$40
    STA DET_T, X
    LDA DET_D, X
    JSR Opposite
    STA DET_D, X
    JMP StepDir
@back:                          ; wedged in on both sides: stand and wait
    LDA #$00                    ; a while (DET_D = 0) rather than shuffle
    STA DET_D, X                ; back and forth
    LDA #$50
    STA DET_T, X
    RTS
@normal:
    LDA PREF
    BEQ :+
    JSR @try
    LDA MOVED
    BNE @rts
:   LDA FALLB
    BEQ @start
    JSR @try
    LDA MOVED
    BNE @rts
@start:                         ; boxed in: start a detour
    LDX CUR
    LDA PREF
    BNE :+
    LDA FALLB
:   STA DET_P, X
    LDA #32
    STA DET_T, X
    LDA FALLB
    BEQ :+
    CMP DET_P, X
    BEQ :+
    JSR Opposite                ; (the fallback was blocked too)
    JMP @setd
:   LDA DET_P, X                ; either side
    AND #$03
    BEQ :+
    LDA #$04
    BNE @side
:   LDA #$01
@side:
    CPX #$00
    BEQ @setd
    JSR Opposite
@setd:
    STA DET_D, X
    JSR StepDir
    LDA MOVED
    BNE @rts
    LDX CUR
    LDA DET_D, X
    JSR Opposite
    STA DET_D, X
    JMP StepDir
@rts:
    RTS
@try:
    LDX FTMP
    BEQ :+
    JMP StepDirLim
:   JMP StepDir

; A <- the opposite direction
Opposite:
    PHA
    AND #$03
    BEQ :+
    PLA
    EOR #$03
    RTS
:   PLA
    EOR #$0C
    RTS

; step in direction A, limited to the remaining distance
StepDirLim:
    STA TMP
    LDA SPEED
    STA TMP2
    LDA TMP
    AND #$03
    BEQ @v
    LDA ADX
    JMP @c
@v: LDA ADY
@c: CMP TMP2
    BCS :+
    STA TMP2
:   SEC
    SBC TMP2
    STA REMAIN
    LDA TMP
    LDX TMP2
    BNE StepDirN
    RTS

; step in direction A by SPEED
StepDir:
    LDX #$02
    STX REMAIN
    LDX SPEED
StepDirN:                       ; A = dir, X = pixels
    STA TMP
    STX TMP2
    STX LASTSTEP
    LDA COLLIDE
    BEQ @free
    JSR Blocked
    BCC @free
    RTS                         ; (blocked: don't turn either, or a boxed-in
@free:                          ;  partner spins on the spot)
    LDA CX
    STA SPX
    LDA CY
    STA SPY
    LDA TMP
    LSR
    BCC :+
    LDA CX                      ; right
    CLC
    ADC TMP2
    STA CX
    JMP @clamp
:   LSR
    BCC :+
    LDA CX                      ; left
    SEC
    SBC TMP2
    STA CX
    JMP @clamp
:   LSR
    BCC :+
    LDA CY                      ; down
    CLC
    ADC TMP2
    STA CY
    JMP @clamp
:   LDA CY                      ; up
    SEC
    SBC TMP2
    STA CY
@clamp:
    LDA COLLIDE
    BEQ @rts
    LDA CX
    CMP RoomBoundLeft
    BCS :+
    LDA RoomBoundLeft
    STA CX
:   CMP RoomBoundRight
    BCC :+
    LDA RoomBoundRight
    STA CX
:   LDA CY
    CMP RoomBoundUp
    BCS :+
    LDA RoomBoundUp
    STA CY
:   CMP RoomBoundDown
    BCC @rts
    LDA RoomBoundDown
    STA CY
@rts:
    LDA CX                      ; really moved (not just pushed back by the
    CMP SPX                     ; room's edge)?
    BNE :+
    LDA CY
    CMP SPY
    BEQ @none
:   LDA TMP
    STA CDIR
    STA CINPUT
    STA MOVED
@none:
    RTS

; Is the tile ahead of (CX,CY) in direction TMP unwalkable?  C = 1 if blocked.
; (Same hotspots as GetCollidableTile uses for Link.)
Blocked:
    LDA CY
    CLC
    ADC #$0B
    STA SPY                     ; probe Y
    LDA CX
    STA SPX                     ; probe X
    LDA TMP
    AND #$0C
    BEQ @horiz
    AND #$04
    BEQ @up
    LDA SPY                     ; down
    CMP #$DD
    BCS @col
    ADC #$08
    STA SPY
    JMP @col
@up:
    LDA SPY
    SEC
    SBC #$08
    STA SPY
    JMP @col
@horiz:
    LDA TMP
    AND #$01
    BEQ @left
    LDA SPX
    CMP #$F0
    BCS @col
    ADC #$10
    STA SPX
    JMP @col
@left:
    LDA SPX
    CMP #$10
    BCC @col
    SBC #$08
    STA SPX
@col:
    LDA SPY
    SEC
    SBC #$40
    BCC @no                     ; above the play area
    LSR
    LSR
    LSR
    STA FTMP                    ; row
    LDA SPX
    AND #$F8
    LSR
    LSR
    TAY
    LDA PlayAreaColumnAddrs, Y
    STA $00
    LDA PlayAreaColumnAddrs+1, Y
    STA $01
    LDY FTMP
    LDA ($00), Y
    JSR @check
    BCS @yes
    LDA TMP                     ; vertical: also the next column
    AND #$0C
    BEQ @no
    LDA FTMP
    CLC
    ADC #$16
    TAY
    LDA ($00), Y
    JSR @check
    BCS @yes
@no:
    CLC
    RTS
@yes:
    SEC
    RTS
@check:
    JMP TileBlocks

TileBlocks:                     ; A = tile -> C = 1 if unwalkable
    LDX CurLevel
    BNE :++
    LDX #$08                    ; overworld walkable exceptions
:   CMP WalkableTiles, X
    BEQ @walk
    DEX
    BPL :-
:   CMP ObjectFirstUnwalkableTile
    RTS
@walk:
    CLC
    RTS

; ---------------------------------------------------------------------------
; Is slot Y a monster worth attacking?  C = 1 if yes.  Preserves X, Y.
IsTarget:
    CPY #$01
    BCC @no
    CPY #$0C
    BCS @no
    LDA ObjType, Y
    BEQ @no
    CMP #$50
    BCS @no
    STA TMP
    LDA ObjMetastate, Y
    BNE @no
    LDA ObjAttr, Y
    AND #$20
    BNE @no
    LDA GameMode                ; never in caves (the people there)
    CMP #$0B
    BCS @no
    LDA TMP
    CMP #$1A                    ; a peahat can only be hurt once it lands
    BNE :+
    LDA $0444, Y                ; (Flyer_ObjFlyingState 5)
    CMP #$05
    BNE @no
:   STX TMPX
    STY TMPY
    LDA TMP
    LSR
    LSR
    LSR
    TAX
    LDA TMP
    AND #$07
    TAY
    LDA TabBit, Y
    AND TabTargets, X
    LDY TMPY
    LDX TMPX
    CMP #$00
    BEQ @no
    SEC
    RTS
@no:
    CLC
    RTS

; ---------------------------------------------------------------------------
; Breakable walls.  Dungeons: bombable doors (door type 4) not yet opened.
; Overworld: the rock-wall tile object hiding a cave.  One partner at a time
; walks over, faces the wall and drops a bomb (free of charge, like its
; other items), as long as the player owns bombs and nothing needs fighting.
; C = 1 if this partner is busy with a wall this frame.
WallTask:
    LDA GameMode
    CMP #$05
    BNE @no0
    LDA InvBombs
    BNE @have
    LDA CurLevel                ; no bombs: on the overworld the candle can still burn a bush
    BNE @no0
    LDA InvCandle
    BEQ @no0
@have:
    LDA BOMBER
    BMI @free
    CMP CUR
    BEQ :+
@no0:
    CLC
    RTS
:   JMP @work
@free:
    LDA WALLSCAN
    BNE :+
    JSR ScanWalls
:   JSR PickWall
    BCS :+
    JMP @no
:   LDA CUR
    STA BOMBER
    LDA #$C0                    ; ~10 seconds to get it done
    STA BTIME
    LDA #$00
    STA BPLACED
    LDX CUR
    STA CL_STUCK, X
@work:
    JSR JobValid
    BCS :+
    JMP @done
:   LDA BPLACED
    BNE @fin
    DEC BTIME
    BEQ @fin
    LDX CUR
    LDA CL_STUCK, X
    CMP #100                    ; (detours count as no progress: allow some)
    BCC :+
@fin:
    JMP @finish                 ; can't get there
:
@direct:
    LDA BSX
    STA TX
    LDA BSY
    STA TY
    JSR Delta
    LDA ADX
    CLC
    ADC ADY
    CMP #$03
    BCC @there
    CMP #$0C                    ; close, but the last pixels are blocked:
    BCS :+                      ; near enough (the bomb is 16 px wide)
    LDX CUR
    LDA CL_STUCK, X
    CMP #$06
    BCS @there
:
@walk:
    LDA #$01
    STA COLLIDE
    LDA #$02
    STA SPEED
    JSR MoveStep
    JSR StuckCheck
    SEC
    RTS
@there:
    LDA BFACE
    AND #$0F
    STA CDIR
    LDX CUR
    LDA CL_ICD, X
    BNE :+
    LDA BJOB
    CMP #$05
    LDA #$04                    ; a bomb for a wall ...
    BCC @wnt
    LDA #$20                    ; ... the candle for a bush
@wnt:
    ORA CL_WANT, X
    STA CL_WANT, X
:   SEC
    RTS
@finish:
    JSR JobDone
@done:
    LDA #$FF
    STA BOMBER
@no:
    CLC
    RTS

ScanWalls:
    LDA #$01
    STA WALLSCAN
    LDA #$00
    STA WALLS
    STA ROCKSLOT
    LDA CurLevel
    BEQ @ow
    LDA #$08
    STA TMP2
@d: LDA TMP2
    STA $02
    FAR 5, FindDoorTypeByDoorBit
    CMP #$04                    ; bombable
    BNE :+
    LDA TMP2
    ORA WALLS
    STA WALLS
:   LSR TMP2
    BNE @d
    RTS
@ow:
    LDY #$0B
@o: LDA ObjType, Y
    CMP #$64                    ; a bush that hides a secret: needs the candle
    BEQ @bush
    CMP #$63
    BEQ @wall
    CMP #$67
    BNE @nx
@wall:
    LDA InvBombs                ; a rock wall: needs bombs
    BNE @rock
    BEQ @nx
@bush:
    LDA InvCandle
    BNE @rock
@nx:
    DEY
    BNE @o
    RTS
@rock:
    STY TMP2
    FAR 4, IsQuestSecretMismatch    ; a secret of the other quest: leave it
    BCS :+
    LDA TMP2
    STA ROCKSLOT
:   RTS

; C = 1 if there is a wall to bomb; sets BJOB, BSX, BSY, BFACE
PickWall:
    LDA CurLevel
    BNE :+
    JMP @ow
:
    LDA CurOpenedDoors
    EOR #$FF
    AND WALLS
    BEQ @none
    STA TMP
    LDX #$00
    LDA #$08
    STA TMP2
@l: LDA TMP
    AND TMP2
    BNE @got
    INX
    LSR TMP2
    BNE @l
@none:
    CLC
    RTS
@got:
    STX BJOB
    LDA TabJX, X
    STA TX
    LDA TabJY, X
    STA TY
    LDA #$03                    ; spot blocked (blocks in the room)?
    STA FTMP                    ; step up to 16 px closer to the wall
@try:
    JSR FreeAtT
    BCC @ok
    DEC FTMP
    BEQ @skip
    LDX BJOB
    LDA TX
    CLC
    ADC TabNudX, X
    STA TX
    LDA TY
    CLC
    ADC TabNudY, X
    STA TY
    JMP @try
@skip:
    LDX BJOB                    ; can't stand there: forget this wall
    LDA TabJBit, X
    EOR #$FF
    AND WALLS
    STA WALLS
    CLC
    RTS
@ok:
    LDX BJOB
    LDA TX
    STA BSX
    LDA TY
    STA BSY
    LDA TabJBit, X              ; face the wall
    STA BFACE
    SEC
    RTS
@ow:
    LDY ROCKSLOT
    BEQ @none
    LDA #$04
    STA BJOB
    LDA ObjType, Y
    CMP #$64
    BNE :+
    INC BJOB                    ; 5 = a bush to burn
:
    ; stand next to the rock wall: below it, else left, right or above
    LDX #$00
@s: LDA ObjX, Y
    CLC
    ADC TabRockDX, X
    STA TX
    LDA ObjY, Y
    CLC
    ADC TabRockDY, X
    STA TY
    LDA BJOB                    ; a candle flame lands 32 px ahead: stand 8 px farther
    CMP #$05
    BNE :+
    LDA TX
    CLC
    ADC TabBushDX, X
    STA TX
    LDA TY
    CLC
    ADC TabBushDY, X
    STA TY
:   STX FTMP
    JSR FreeAtT
    LDX FTMP
    LDY ROCKSLOT
    BCC @sok
    INX
    CPX #$04
    BCC @s
    LDA #$00                    ; nowhere to stand
    STA ROCKSLOT
    CLC
    RTS
@sok:
    LDA TX
    STA BSX
    LDA TY
    STA BSY
    LDA TabRockF, X
    STA BFACE
    SEC
    RTS

; C = 1 if the current wall still needs bombing
JobValid:
    LDA CurLevel
    BEQ @ow
    LDA TriggeredDoorCmd        ; a door is opening
    BNE @no
    LDX BJOB
    CPX #$04
    BCS @no
    LDA TabJBit, X
    AND CurOpenedDoors
    BNE @no
    LDA TabJBit, X
    AND WALLS
    BEQ @no
    SEC
    RTS
@ow:
    LDY ROCKSLOT
    BEQ @no
    LDA ObjType, Y
    CMP #$63
    BEQ :+
    CMP #$67
    BEQ :+
    CMP #$64
    BNE @no
:   SEC
    RTS
@no:
    CLC
    RTS

JobDone:
    LDX BJOB
    CPX #$04
    BCS @ow
    LDA TabJBit, X
    EOR #$FF
    AND WALLS
    STA WALLS
    RTS
@ow:
    LDA #$00
    STA ROCKSLOT
    RTS

; Overworld: a partner's exploding bomb (only in the real slots while its
; weapons are swapped in) is shown to the rock wall's own update routine.
RockCheck:
    LDA GROUPS
    AND #G_BOMB
    BEQ @r
    LDA CurLevel
    BNE @r
    LDA ObjState+$10
    CMP #$13
    BEQ :+
    LDA ObjState+$11
    CMP #$13
    BNE @r
:   LDX #$0B
@l: LDA ObjType, X
    CMP #$63
    BEQ :+
    CMP #$67
    BNE @n
:   FAR 4, UpdateRockWall       ; (X is kept)
@n: DEX
    BNE @l
@r: RTS

; Overworld: a partner's standing fire (only in the real slots while its
; weapons are swapped in) is shown to each secret bush's own update routine.
TreeCheck:
    LDA GROUPS
    AND #G_BOMB
    BEQ @r
    LDA CurLevel
    BNE @r
    LDA ObjState+$10
    CMP #$22
    BEQ :+
    LDA ObjState+$11
    CMP #$22
    BNE @r
:   LDX #$0B
@l: LDA ObjType, X
    CMP #$64
    BNE @n
    FAR 4, UpdateTree           ; (X is kept)
@n: DEX
    BNE @l
@r: RTS

; dungeon walls N, S, W, E: where to stand (bomb lands on the door hotspot)
TabJX:   .byte $78, $78, $30, $C0
TabJY:   .byte $6D, $AD, $8D, $8D
TabJBit: .byte $08, $04, $02, $01   ; also the direction to face
TabNudX: .byte $00, $00, $F8, $08
TabNudY: .byte $F8, $08, $00, $00
; overworld rock wall: stand below, left, right, above it, facing it
TabRockDX: .byte $00, $F0, $10, $00
TabRockDY: .byte $10, $00, $00, $F0
TabBushDX: .byte $00, $F8, $08, $00
TabBushDY: .byte $08, $00, $00, $F8
TabRockF:  .byte $08, $01, $02, $04

TabBit:
    .byte $01, $02, $04, $08, $10, $20, $40, $80
TabTargets:                     ; bit set = attackable monster type ($00-$4F)
    .include "targets.inc"

; Find the nearest target around this partner.  C = 1, A = slot.
FindTarget:
    LDA #$FF
    STA BESTD
    LDY #$0B
@l: LDA ObjType, Y
    BEQ @next
    JSR IsTarget                ; anywhere in the room
    BCC @next
    LDX CUR                     ; not the one we couldn't reach just now
    LDA IGN_T, X
    BEQ :+
    TYA
    CMP IGN_S, X
    BEQ @next
:
    LDA ObjX, Y
    SEC
    SBC CX
    JSR AbsU
    LSR
    STA FTD
    LDA ObjY, Y
    SEC
    SBC CY
    JSR AbsU
    LSR
    CLC
    ADC FTD                     ; (|dx| + |dy|) / 2
    STA FTD
    LDX #NCL-1                    ; spread out: avoid targets others already fight
:   CPX CUR
    BEQ @pn
    LDA CL_MODE, X
    CMP #$01
    BNE @pn
    TYA
    CMP CL_TGT, X
    BNE @pn
    LDA FTD
    CLC
    ADC #$18
    BCC :+
    LDA #$FE
:   STA FTD
@pn:
    DEX
    BPL :--
    LDA FTD
    CMP BESTD
    BCS @next
    STA BESTD
    STY BESTS
@next:
    DEY
    BEQ :+
    JMP @l
:   LDA BESTD
    CMP #$FF
    BEQ @none
    LDA BESTS
    SEC
    RTS
@none:
    CLC
    RTS

B3End:

; ===========================================================================
; Bank 4: extra collision checks for the partners' weapons.
; Called from CheckMonsterCollisions (via PostCheck) and the Wizzrobe code.
; X = monster slot.  Must preserve X.
; ===========================================================================
.segment "B4CODE"
B4Magic:
    .byte $5A

WizzHook:
    JSR CloneHits
    JMP CheckLinkCollision

CloneHits:
.ifdef DISABLED
    RTS
.endif
    LDA CL_MASK
    ORA CL_MASK+1
    BEQ @rts0
    LDA ObjAttr, X
    AND #$20
    BNE @rts0
    LDA ObjInvincibilityTimer, X
    ORA ObjMetastate, X
    BNE @rts0
    LDA GameMode
    CMP #$0B
    BCC :+
@rts0:
    RTS                         ; (X untouched)
:   STX MON
    JSR GetObjectMiddle         ; monster middle -> [02],[03]
    LDA $02
    STA MX
    LDA $03
    STA MY
    LDA #$00
    STA CPASS
@loop:
    LDX CPASS
    LDA CL_MASK, X
    BEQ @next
    JSR HitsForClone
    LDX MON
    LDA ObjInvincibilityTimer, X
    ORA ObjMetastate, X
    BNE @rts
@next:
    INC CPASS
    LDA CPASS
    CMP #NCL
    BNE @loop
@rts:
    LDX MON
    RTS

; weapon slot for each mask bit
TabWSlot:
    .byte $0D, $0E, $0F, $10, $11, $12

; A = mask of partner CPASS (non-zero)
HitsForClone:
    STA CMASK
    LDA #$00
    STA NEAR
    LDY TabCOff, X              ; Y = c*77
    ; the blade: exact test (same thresholds as CheckMonsterStabbingCollision)
    LSR CMASK
    BCC @others
    LDA ST_DIR, Y               ; partner's facing (slot 0)
    AND #$0C
    BEQ @bh
    LDA ST_X+1, Y               ; vertical: mid (x+6, y+8), thresholds $C, $10
    CLC
    ADC #$06
    SEC
    SBC MX
    BCS :+
    EOR #$FF
    ADC #$01
:   CMP #$0C
    BCS @others
    LDA ST_Y+1, Y
    CLC
    ADC #$08
    SEC
    SBC MY
    BCS :+
    EOR #$FF
    ADC #$01
:   CMP #$10
    BCS @others
    BCC @bhit
@bh:
    LDA ST_X+1, Y               ; horizontal: mid (x+8, y+6), thresholds $10, $C
    CLC
    ADC #$08
    SEC
    SBC MX
    BCS :+
    EOR #$FF
    ADC #$01
:   CMP #$10
    BCS @others
    LDA ST_Y+1, Y
    CLC
    ADC #$06
    SEC
    SBC MY
    BCS :+
    EOR #$FF
    ADC #$01
:   CMP #$0C
    BCS @others
@bhit:
    LDA #$01
    STA NEAR
@others:
    ; other weapons: coarse test around (x+8, y+8)
    LDA CMASK
    BEQ @test
    STY TMP
    LDX #$01                    ; mask bit index 1..5
@p: LSR CMASK
    BCC @pn
    TXA
    CLC
    ADC TMP
    TAY
    LDA ST_X, Y
    CLC
    ADC #$08
    SEC
    SBC MX
    BCS :+
    EOR #$FF
    ADC #$01
:   CMP #$1C
    BCS @pn
    LDA ST_Y, Y
    CLC
    ADC #$08
    SEC
    SBC MY
    BCS :+
    EOR #$FF
    ADC #$01
:   CMP #$1C
    BCS @pn
    LDA NEAR
    ORA TabBit4, X
    STA NEAR
@pn:
    INX
    LDA CMASK
    BNE @p
@test:
    LDA NEAR
    BNE :+
    RTS
:
    JSR CXchg0                  ; partner position/direction into slot 0
    LDY #$00
@w: LDA NEAR
    AND TabBit4, Y
    BEQ @wn
    STY TMP2
    LDX TabWSlot, Y
    JSR CXchgW
    LDA MX
    STA $02
    LDA MY
    STA $03
    LDY TMP2
    LDA TabPrimLo, Y
    STA $0A
    LDA TabPrimHi, Y
    STA $0B
    LDA TabWSlot, Y
    TAY
    LDX MON
    JSR @call
    LDY TMP2
    LDX TabWSlot, Y
    JSR CXchgW
    LDY TMP2
    LDX MON
    LDA ObjInvincibilityTimer, X
    ORA ObjMetastate, X
    BNE @done
@wn:
    INY
    CPY #$06
    BNE @w
@done:
    LDX MON
    JMP CXchg0
@call:
    JMP ($000A)

TabCOff:
    .byte 0, 77, 154
TabWIdx:
    .byte 1, 2, 3, 4, 5, 6
TabPrimLo:
    .byte <CheckMonsterSwordCollision, <CheckMonsterSwordShotOrMagicShotCollision
    .byte <CheckMonsterBoomerangOrFoodCollision, <CheckMonsterBombOrFireCollision
    .byte <CheckMonsterBombOrFireCollision, <CheckMonsterArrowOrRodCollision
TabPrimHi:
    .byte >CheckMonsterSwordCollision, >CheckMonsterSwordShotOrMagicShotCollision
    .byte >CheckMonsterBoomerangOrFoodCollision, >CheckMonsterBombOrFireCollision
    .byte >CheckMonsterBombOrFireCollision, >CheckMonsterArrowOrRodCollision
TabBit4:
    .byte $01, $02, $04, $08, $10, $20, $40, $80

CXchg0:
    LDA CPASS
    BEQ :+
    CMP #$01
    BEQ :++
    JMP CXchg0_2
:   JMP CXchg0_0
:   JMP CXchg0_1
CXchgW:
    LDA CPASS
    BEQ :+
    CMP #$01
    BEQ :++
    JMP CXchgW_2
:   JMP CXchgW_0
:   JMP CXchgW_1

.include "xchg_coll.inc"

; ---------------------------------------------------------------------------
; Dodongo: let the partners' bombs feed / stun it too.  Replaces the
; "JSR Dodongo_CheckBombHit" in UpdateDodongo.  X = Dodongo's slot.
DBX = $115                      ; (CL_TGT+2: unused with NCL = 2)
DodoBombHook:
    JSR Dodongo_CheckBombHit    ; the player's bomb, as before
    LDA CL_MASK
    ORA CL_MASK+1
    AND #$08
    BEQ @done
    LDA ObjState, X
    BNE @done                   ; (only matters while it walks)
    STX DBX
    LDA #$00
    STA CPASS
@lp:
    LDX CPASS
    LDA CL_MASK, X
    AND #$08
    BEQ @next
    LDX #$10
    JSR CXchgW                  ; the partner's bomb into slot $10
    LDX DBX
    JSR Dodongo_CheckBombHit
    LDX #$10
    JSR CXchgW                  ; ... and back
    LDX DBX
    LDA ObjState, X
    BNE @fin
@next:
    INC CPASS
    LDA CPASS
    CMP #NCL
    BNE @lp
@fin:
    LDX DBX
@done:
    RTS

B4End:

.include "menu.s"
