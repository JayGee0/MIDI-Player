; ===============================================================
;               Buzzer Library
;               J. GEORGIS
;               VERSION 1.0
;               09.05.2024
;
; This is a library of Buzzer related functions,
; Buzzer A refers to a simple latch buzzer, enable and disable
; with no duration. Useful for feedback-ing to user
;
; Buzzer B refers to a duration buzzer, containing a busy
; signal and enabled through pulsing 'play'. Useful for
; playing music
; ===============================================================
Enable_buzzer_A    EQU     &01                             ; Enable bit of buzzer A
Play_buzzer_B      EQU     &40                             ; Play bit of buzzer B
Busy_buzzer_B      EQU     &80                             ; Busy bit of buzzer B

; ===============================================================
;               PLAY NOTE TO BUZZER B
;               OUTPUT TO R0: 1 if Successful, else 0
; PARAMETERS:   R2 - DESIRED NOTE <DURATION : OCTAVE : NOTE>
; ===============================================================
PLAY_NOTE_B
                PUSH   {R1, LR}

                MOV    R0, #FPGA_area            
                
                LDRB   R1, [R0, #BuzzerB_control]          
                TST    R1, #Busy_buzzer_B                  ; Check if buzzer busy...
                MOVNE  R0, #0
                BNE    END_PLAY_NOTE_B                     ; If so, return unsuccessful


                STRB   R2, [R0, #BuzzerB_data]             ; Load in <Octave:Note> data
                ROR    R2, R2, #8                          ; Move <Duration> half to [7:0]
                ORR    R2, R2, #Play_buzzer_B
                STRB   R2, [R0, #BuzzerB_control]          ; Load in <Duration> data with Play bit ready to pulse
                BIC    R2, R2, #Play_buzzer_B
                STRB   R2, [R0, #BuzzerB_control]          ; Pulse play bit
                ROR    R2, R2, #24                         ; Recover R2, no need for stack

                MOV    R0, #1                              ; Return successful
END_PLAY_NOTE_B
                POP    {R1, LR}
                MOVS   PC, LR                              ; Recover SPSR and return

; ===============================================================
;               LOAD NOTE TO BUZZER A AND ENABLE
; PARAMETERS:   R2 - DESIRED NOTE <OCTAVE : NOTE>
; ===============================================================
PLAY_NOTE_A
                PUSH   {R1}
                MOV    R0, #FPGA_area            
                STRB   R2, [R0, #BuzzerA_data]             ; Load note into buzzer A
                MOV    R1, #Enable_buzzer_A 
                STRB   R1, [R0, #BuzzerA_control]          ; Enable buzzer A
                POP    {R1}
                MOVS   PC, LR

; ===============================================================
;               DISABLE BUZZER A
; ===============================================================
DISABLE_BUZZER_A
                PUSH   {R1}
                MOV    R0, #FPGA_area        
                MOV    R1, #0  
                STRB   R1, [R0, #BuzzerA_control]          ; Disable buzzer    
                POP    {R1}
                MOVS   PC, LR

; ===============================================================
;               PLAY SONG ON DURATION BUZZER
;               NOT PRIVILEGED
; PARAMETERS:   R1 - DESIRED SONG ADDRESS
; ===============================================================
PLAY_SONG
                PUSH   {R0-R2, LR}
SONG_LOOP
                CMP    R9, #0
                BEQ    END_SONG_PLAY                       ; If we have triggered a stop event, exit
                LDR    R2, [R1]
                CMP    R2, #0                              ; If we have reached END_OF_SONG, exit
                BEQ    END_SONG_PLAY

                MOV    R0, #SVC_Play_note_B
                SVC    SVC_Play_note_B
                
                CMP    R0, #0
                ADDNE  R1, R1, #4                          ; If successful, increment song pointer
                
                B      SONG_LOOP
END_SONG_PLAY
                POP    {R0-R2, PC}

