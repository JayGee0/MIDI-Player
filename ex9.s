; ===============================================================
;               MIDI PLAYER
;               J. GEORGIS
;               VERSION 1.0
;               09.05.2024
;               THIS IS A MIDI PLAYER, CONTROLS AS FOLLOWS:
;
;               S0 KEYPAD TO INPUT TRACK
;                   
;               LOWER RIGHT PCB BUTTONS FOR STOP
;               
;               GLOBAL VARIABLES: 
;                   R9  - PLAY/END STATUS (IF 0, TRIGGERS END)
; ===============================================================


INCLUDE library.s

MAIN 
                ADR    R1, TEXT                            ; Get address of text and write them  
                MOV    R0, #SVC_Write_char_bytes
                SVC    SVC_Write_char_bytes                        

                MOV    R8, #'0'                            ; R8 <- Next track in ASCII, startup default = 0
                MOV    R7, #'*'                            ; R7 <- Current track in ASCII
                ADRL   R1, UNLOCK_SOUND 

MAIN_LOOP
                MOV    R9, #1                              ; R9 <- Play / End status

                CMP    R8, R7
                BLNE   UPDATE_CURRENT_AND_DISPLAY          ; Only update display if track has been changed
                
                MOV    R0, #SVC_Pop_last_key
                SVC    SVC_Pop_last_key                    ; R2 <- last pushed keym, clear buffer to avoid double-reading
                CMP    R2, #0
                BEQ    MAIN_LOOP                           ; If key buffer empty, keep looping
                
                CMP    R2, #'#'
                BLEQ   PLAY_SONG                           ; Play song if # key pressed on keypad

                BLNE   MUSIC_LOOKUP                        ; Update next track 
                B      MAIN_LOOP


; ===============================================================
;               UPDATE THE CURRENT TRACK VAR
;               AND UPDATE THE DISPLAY ACCORDINGLY
; ===============================================================
UPDATE_CURRENT_AND_DISPLAY
                MOV    R7, R8                              ; Current track <- Next track
                
                MOV    R0, #SVC_Shift_left_lcd
                SVC    SVC_Shift_left_lcd                  ; Clear some space to write character                  
                
                MOV    R2, R7
                MOV    R0, #SVC_Write_char
                SVC    SVC_Write_char                      ; Update display with current track
                
                MOV    PC, LR

TEXT            DEFB    "MIDI PLAYER:  \0"
ALIGN
INCLUDE         music.s
