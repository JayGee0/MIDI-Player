; ===============================================================
;               Keyboard Library
;               J. GEORGIS
;               VERSION 2.0
;               09.05.2024
;
; This is a library of Keyboard related functions
; ===============================================================

Keyboard_config     EQU     :0001_1111                    ; Output bits 765, Input bits 43210 

; ===============================================================
;               INITIALISE THE KEYBOARD TO INPUT
; ===============================================================
INIT_KEYBOARD    
                MOV    R0, #FPGA_area          
                MOV    R1, #Keyboard_config
                STRB   R1, [R0, #Keyboard_control]        ; Send keyboard config to the keyboard control

                ; Clear global variables in initialisation
                ADRL   R0, KEYBOARD_STATUS_MATRIX               
                MOV    R2, #(KEYBOARD_DEBOUNCE_MATRIX_END-KEYBOARD_STATUS_MATRIX) ; Span both matrices
                MOV    R1, #0 
INIT_KEYBOARD_LOOP
                SUBS   R2, R2, #1
                MOVLT  PC, LR
                STRB   R1, [R0, R2]
                MOV    PC, LR

; ===============================================================
;               RETURN THE LAST READ KEY IN ASCII AND
;               OVERWRITE LAST_KEY_PRESSED WITH \0
;               R2 - OUTPUT
; ===============================================================
POP_LAST_KEY_PRESSED
                PUSH   {R1}
                ADRL   R0, LAST_KEY_PRESSED               
                MOV    R1, #0
                LDRB   R2, [R0]                           ; Load in last key pressed 
                STRB   R1, [R0]                           ; Overwrite address with \0
                POP    {R1}
                MOVS   PC, LR

; ===============================================================
;               RETURN THE LAST READ KEY IN ASCII
;               WITHOUT OVERWRITING
;               R2 - OUTPUT
; ===============================================================
PEAK_LAST_KEY_PRESSED
                ADRL   R0, LAST_KEY_PRESSED               
                LDRB   R2, [R0]                           ; Load in last key pressed 
                MOVS   PC, LR

; ===============================================================
;               SCAN THE KEYBOARD AND UPDATE THE DEBOUNCE
;               MATRIX. THIS IS AN SVC CALLED BY READ_KEYBOARD
; ===============================================================
SCAN_KEYBOARD
                PUSH   {R0-R4}
                ADDS   R0, R0, R0                         ; Clear carry bit for future use
                MOV    R0, #FPGA_area
                MOV    R1, #&84                           ; R1 <- Control line enable bit + loop end bit (loop 3 times)
                ADRL   R3, KEYBOARD_DEBOUNCE_MATRIX_END-1 ; Last byte of debounce matrix       
SCAN_LOOP  
                STRB   R1, [R0, #Keyboard_data]           ; Enable certain lines for scanning
                LDRB   R2, [R0, #Keyboard_data]
                AND    R2, R2, #&0F                       ; Read which keys are down
                ORR    R2, R2, #&80                       ; Loop status bit
UPDATE_DEBOUNCE_LOOP
                LDRB   R4, [R3]                           ; Get key in debounce matrix
                ASRS   R2, R2, #1                         ; Shift right and take the LSB as carry                       
                ADC    R4, R4, R4                         ; Shift left and take carry into space left behind 
 
                STRB   R4, [R3]                           ; Store the debounce status MOD 256 back to the byte
                SUB    R3, R3, #1                         ; Point to next-to-read byte
                TST    R2, #&08                           ; TST for the loop end bit (Terminate after 4 cycles)
                BEQ    UPDATE_DEBOUNCE_LOOP                


                ASRS   R1, R1, #1
                BCC    SCAN_LOOP        
END_SCAN                
                POP    {R0-R4}
                MOVS   PC, LR

; ===============================================================
;               SCAN AND READ KEYBOARD AND PRINT ASCII
;               TRANSLATION. CALLED BY INTERRUPT SIGNAL
;
;               ALTERNATIVELY, THIS COULD BE TURNED INTO AN
;               SVC, WHERE WE ALLOW INTERRUPTS TO HAPPEN. 
;               THIS WILL ALLOW THE USER TO ACCESS WHAT THE
;               KEYPAD HAS WRITTEN.
; ===============================================================
READ_KEYBOARD
                PUSH   {R0-R6, LR}
                MOV    R0, #SVC_Scan_keyboard
                SVC    SVC_Scan_keyboard

                MOV    R4, #-1                                                 ; R4 <- Posedge button
                MOV    R1, #12                                                 ; R1 <- Offset
                MOV    R3, #0                                                  ; R3 <- Button down signifier
                ADR    R5, KEYBOARD_DEBOUNCE_MATRIX
                ADR    R6, KEYBOARD_STATUS_MATRIX
READ_KEYBOARD_LOOP
                SUBS   R1, R1, #1
                BMI    EXIT_KEYBOARD_LOOP
                LDRB   R2, [R5, R1]                                            ; Read the debounce matrix

                CMP    R2, #&00                                                ; If we have reached 00...
                STREQB R2, [R6, R1]                                            ; Update the status with 00
                BEQ    READ_KEYBOARD_LOOP                                      ; and continue searching for characters

                CMP    R2, #&FF                                               
                BNE    READ_KEYBOARD_LOOP                                      ; If debounce matrix does not read FF, keep searching for characters

                ;R2 = FF
                MOV    R2, R1
                ORR    R2, R2, #&40
                MOV    R0, #SVC_Play_note_A
                SVC    SVC_Play_note_A                                         ; Either Play a note if key pressed, or Stop the buzzer
                MOV    R3, #1
                
                LDRB   R2, [R6, R1]
                CMP    R2, #&FF
                BEQ    READ_KEYBOARD_LOOP                                      ; Keep searching for characters if the character read is being held down
                
                MOV    R4, R1                                                  ; Store the current to-read character
                B      READ_KEYBOARD_LOOP
EXIT_KEYBOARD_LOOP 
                CMP    R3, #0
                MOVEQ  R0, #SVC_Disable_buzzer_A
                SVCEQ  SVC_Disable_buzzer_A                                    ; If nothing down, disable buzzer A
                
                CMP    R4, #-1
                BEQ    EXIT_READ_KEYBOARD

                MOV    R1, #&FF
                ADR    R5, KEYBOARD_ASCII_TABLE
                STRB   R1, [R6, R4]                                            ; Acknowledge the key as being read
                LDRB   R2, [R5, R4]                                            ; Get the ASCII
                ADR    R5, LAST_KEY_PRESSED
                STRB   R2, [R5]                                                ; Store back ASCII in last key pressed
EXIT_READ_KEYBOARD
                POP   {R0-R6, PC}

LAST_KEY_PRESSED
DEFB            '\0'
ALIGN


; ===============================================================
;               Translate input key from keyboard code
;               to <OCTAVE : NOTE>
; ===============================================================
KEYBOARD_NOTE_TABLE
DEFB            &42, &45, &48, &4B  ; COLUMN 2 [3,6,9,#] +0
DEFB            &41, &44, &47, &4A  ; COLUMN 1 [2,5,8,0] +4
DEFB            &40, &43, &46, &49  ; COLUMN 0 [1,4,7,*] +8

; ===============================================================
;               Translate input key from keyboard code
;               to ASCII
; ===============================================================
KEYBOARD_ASCII_TABLE
;DEFB            '3', '6', '9', '#'  ; COLUMN 2 [3,6,9,#] +0
;DEFB            '2', '5', '8', '0'  ; COLUMN 1 [2,5,8,0] +4
;DEFB            '1', '4', '7', '*'  ; COLUMN 0 [1,4,7,*] +8

DEFB            '#', '9', '6', '3'  ; COLUMN 2 [3,6,9,#] +0
DEFB            '0', '8', '5', '2'  ; COLUMN 1 [2,5,8,0] +4
DEFB            '*', '7', '4', '1'  ; COLUMN 0 [1,4,7,*] +8


; ===============================================================
;               KEY STATUS MATRIX, 
;               FF if pressed and read, 0 otherwise
; ===============================================================
KEYBOARD_STATUS_MATRIX
DEFB            &00, &00, &00, &00  ; COLUMN 2 [3,6,9,#] +0
DEFB            &00, &00, &00, &00  ; COLUMN 1 [2,5,8,0] +4
DEFB            &00, &00, &00, &00  ; COLUMN 0 [1,4,7,*] +8


; ===============================================================
;               DEBOUNCE BYTE MATRIX
; ===============================================================
KEYBOARD_DEBOUNCE_MATRIX
DEFB            &00, &00, &00, &00  ; COLUMN 2 [3,6,9,#] +0
DEFB            &00, &00, &00, &00  ; COLUMN 1 [2,5,8,0] +4
DEFB            &00, &00, &00, &00  ; COLUMN 0 [1,4,7,*] +8
KEYBOARD_DEBOUNCE_MATRIX_END

