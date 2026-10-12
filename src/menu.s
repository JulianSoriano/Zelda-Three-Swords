; ---------------------------------------------------------------------------
; Menu controls (bank 2, called from the file-select, register-name and
; elimination screens in place of their first "LDA ButtonsPressed").
;
;   File select:   Up/Down move the heart, A or Start chooses.
;   Register name: D-pad picks a letter (as before), A types it,
;                  B erases the previous letter, Start saves and finishes
;                  (from anywhere, no need to go to END first).
;   Elimination:   Up/Down move the heart, A erases the chosen file (or
;                  leaves on END), B leaves.
; Select still works everywhere as in the original game.
; ---------------------------------------------------------------------------
.segment "B2CODE"

M_Pressed   = $F8
M_Slot      = $16
M_ObjX      = $70
M_Sprites   = $200
M_DynTile   = $302
M_Tune1Req  = $602
M_Tune0Req  = $604
M_Active    = $633
M_Names     = $638
M_NameInit  = $420
M_NameOff   = $421
M_NameBuf   = $422
M_FromElim  = $1B1           ; (partner RAM, unused in menus) leave register at once
M1_WriteCursor  = $A5BE         ; UpdateMode1Menu_Sub0 @WriteCursorSprite
MEF_SlotYs      = $9DAF         ; ModeEandFSlotCursorYs

BTN_A   = $80
BTN_B   = $40
BTN_SEL = $20
BTN_ST  = $10
BTN_UP  = $08
BTN_DN  = $04

; File select.  Returns A = ButtonsPressed & Start (flags set), like
; the "LDA ButtonsPressed / AND #$10" it replaces.
MenuMode1:
    LDA M_Pressed
    AND #BTN_UP
    BEQ @notup
    ; Up: previous active option
    LDA #$01
    STA M_Tune1Req
@prev:
    DEC M_Slot
    BPL :+
    LDA #$04
    STA M_Slot
:   LDY M_Slot
    LDA M_Active, Y
    BEQ @prev
    PLA                         ; leave the caller's code path:
    PLA                         ; draw the heart and the Links as Select does
    JMP M1_WriteCursor
@notup:
    LDA M_Pressed
    TAX
    AND #BTN_A
    BEQ :+
    TXA
    ORA #BTN_ST
    TAX
:   TXA
    AND #BTN_DN
    BEQ :+
    TXA
    ORA #BTN_SEL
    TAX
:   STX M_Pressed
    TXA
    AND #BTN_ST
    RTS

; Elimination.  Returns A = ButtonsPressed, flags of CMP #$10.
MenuModeF:
    LDA M_Pressed
    AND #BTN_UP
    BEQ @notup
    LDA #$01
    STA M_Tune1Req
    DEC M_Slot
    BPL :+
    LDA #$03
    STA M_Slot
:   LDY M_Slot
    LDA MEF_SlotYs, Y
    STA M_Sprites
    LDA #$00
    STA M_Pressed
    BEQ @ret
@notup:
    LDA M_Pressed
    AND #BTN_B
    BEQ :+
    LDA #$03                    ; B: leave (as if END was chosen)
    STA M_Slot
    LDA #BTN_ST
    STA M_Pressed
    BNE @ret
:   LDA M_Pressed
    AND #BTN_A
    BEQ :+
    LDA #BTN_ST
    STA M_Pressed
    BNE @ret
:   LDA M_Pressed
    AND #BTN_DN
    BEQ @ret
    LDA #BTN_SEL
    STA M_Pressed
@ret:
    LDA M_Pressed
    CMP #BTN_ST
    BNE :+
    LDA M_Slot                  ; leaving through END: the register screen
    CMP #$03                    ; it goes to saves and closes at once
    BNE :+
    LDA #$01
    STA M_FromElim
:   LDA M_Pressed
    CMP #BTN_ST
    RTS

; Register your name.  Returns A = ButtonsPressed & Start (flags set).
MenuModeE:
    LDA M_FromElim
    BEQ :+
    LDA #$00
    STA M_FromElim
    LDA #BTN_ST
    STA M_Pressed
:   LDA M_Pressed
    AND #BTN_ST
    BEQ :+
    LDA #$03                    ; Start: save and finish from anywhere
    STA M_Slot
    BNE @ret
:   LDA M_Slot
    CMP #$03
    BNE @slot
    LDA M_Pressed               ; on END: A finishes too
    AND #BTN_A
    BEQ @ret
    LDA #BTN_ST
    STA M_Pressed
    BNE @ret
@slot:
    LDA M_Pressed
    AND #BTN_B
    BEQ @ret
    LDA M_Pressed               ; B: erase the previous letter
    AND #<~BTN_B                ; (instead of skipping forward)
    STA M_Pressed
    LDA M_NameInit
    BEQ @ret                    ; nothing typed in this field yet
    LDY M_Slot
    LDA M_NameOff
    AND #$07
    BEQ @ret                    ; already at the first letter
    DEC M_NameOff
    DEC M_NameBuf+1
    LDA M_ObjX
    SEC
    SBC #$08
    STA M_ObjX
    LDX M_NameOff
    LDA #$24                    ; blank
    STA M_Names, X
    LDY #$02
:   LDA M_NameBuf, Y
    STA M_DynTile, Y
    DEY
    BPL :-
    LDA #$24
    STA M_DynTile+3
    LDA #$FF
    STA M_DynTile+4
    LDA #$20                    ; same click as typing
    STA M_Tune0Req
@ret:
    LDA M_Pressed
    AND #BTN_ST
    RTS
