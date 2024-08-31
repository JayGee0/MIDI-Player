; ===============================================================
;               MUSIC LIBRARY
;               J. GEORGIS
;               VERSION 1.5
;               09.05.2024
;
; THIS HOLDS A LOOKUP TABLE AND METHOD, AS WELL 
; AS ALL THE MUSIC DATA
;
; MUSIC GENERATED FROM PYTHON SCRIPT midi2armp3.py. USING THE
; pretty_midi LIBRARY TO DECODE MIDIS FROM https://onlinesequencer.net/sequences
; WITH SOME CLEANING.
; ===============================================================

Max_music       EQU     (MUSIC_LOOKUP_TABLE_END-MUSIC_LOOKUP_TABLE)/4  ; Maximum music lookup


; ===============================================================
;               MUSIC LOOKUP TABLE
;               CORRUPTS R0, LOADS MUSIC ADDRESS INTO R1
;               OUTPUTS TRACK ASCII INTO R8
; ===============================================================
MUSIC_LOOKUP
                AND    R0, R2, #&F             ; Extract number part from the ASCII
                CMP    R0, #Max_music
                MOVLO  R8, R2
                LDRLO  R1, [PC, R0, LSL #2]    ; Load up address of pointed-to song
                MOV    PC, LR

MUSIC_LOOKUP_TABLE
DEFW    UNLOCK_SOUND
DEFW    LOONBOON_SONG
DEFW    KIRBY_SONG
DEFW    MEGALOVANIA_SONG
DEFW    FNAF_SONG
DEFW    MIKU_SONG
DEFW    FF_SONG

MUSIC_LOOKUP_TABLE_END

UNLOCK_SOUND
INCLUDE midi/unlock_sound.s

LOONBOON_SONG
INCLUDE midi/loonboon.s

KIRBY_SONG
INCLUDE midi/kirby.s

MEGALOVANIA_SONG
INCLUDE midi/megalovania.s

FNAF_SONG
INCLUDE midi/fnaf.s

MIKU_SONG
INCLUDE midi/miku.s

FF_SONG
INCLUDE midi/ff.s