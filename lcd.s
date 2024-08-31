; ===============================================================
;               LCD Library
;               J. GEORGIS
;               VERSION 2.0
;               09.05.2024
;
; This is a library of LCD related functions
; ===============================================================

Busy_LCD        EQU     &80                    ; If high, LCD busy
Clear_LCD       EQU     &01                    ; If written to LCD Control, clears it
Shift_LCD_left  EQU     &10                    ; Shifts cursor of LCD left by 1

; ===============================================================
;               CLEAR THE LCD
; ===============================================================
INIT_LCD    
                PUSH   {LR}
                BL     CLEAR
                POP    {PC}

; ===============================================================
;               CLEAR LCD SCREEN AND RETURN TO PREVIOUS MODE
; ===============================================================
CLEAR_SVC
                PUSH   {LR}
                BL     CLEAR
                POP    {LR}
                MOVS   PC, LR

; ===============================================================
;               CLEAR LCD SCREEN
; ===============================================================
CLEAR
                PUSH   {R0-R2, LR}
                BL     WAIT_TILL_LCD_READY
                MOV    R0, #Port_area             
                LDRB   R1, [R0, #Control_port]    
                BIC    R1, R1, #(Read_LCD|DBus_LCD|Enab_LCD)          ; Disable the read bit, Data bus bit, and LCD enable bit
                
                MOV    R2, #Clear_LCD                                 ; R2 <= Clear char
                                
                STRB   R1, [R0, #Control_port]                        ; Write to LCD Control [XXXX X000] -> Control port
                ORR    R1, R1, #Enab_LCD                              ; Trigger LCD Read
                STRB   R2, [R0, #Data_port]                           ; Send clear char to LCD 
                STRB   R1, [R0, #Control_port]                        ; Enable interface [XXXX X0001] -> Control port
                BIC    R1, R1, #Enab_LCD                              ; End LCD trigger
                STRB   R1, [R0, #Control_port]                        ; [XXXX X000] -> Control port
                
                POP    {R0-R2, LR}
                MOV    PC, LR

; ===============================================================
;               SHIFT CURSOR ON LCD LEFT BY 1
; ===============================================================
SHIFT_LCD_CURSOR_LEFT
                PUSH   {R0-R2, LR}
                BL     WAIT_TILL_LCD_READY
                MOV    R0, #Port_area             
                LDRB   R1, [R0, #Control_port]    
                BIC    R1, R1, #(Read_LCD|DBus_LCD|Enab_LCD)          ; Disable the read bit, Data bus bit, and LCD enable bit
                
                MOV    R2, #Shift_LCD_left                            ; R2 <= Shift cursor left
                                
                STRB   R1, [R0, #Control_port]                        ; Write to LCD Control [XXXX X000] -> Control port
                ORR    R1, R1, #Enab_LCD                              ; Trigger LCD Read
                STRB   R2, [R0, #Data_port]                           ; Send char to LCD 
                STRB   R1, [R0, #Control_port]                        ; Enable interface [XXXX X0001] -> Control port
                BIC    R1, R1, #Enab_LCD                              ; End LCD trigger
                STRB   R1, [R0, #Control_port]                        ; [XXXX X000] -> Control port
                
                POP    {R0-R2, LR}
                MOVS   PC, LR


; ===============================================================
;               WAIT TILL LCD GIVES NOT BUSY SIGNAL
; ===============================================================
WAIT_TILL_LCD_READY
                PUSH   {R0-R2}                
                
                MOV    R0, #Port_area          
                LDRB   R1, [R0, #Control_port] 
                
                ORR    R1, R1, #Read_LCD                     ; Enable the read bit
                BIC    R1, R1, #(DBus_LCD|Enab_LCD)          ; Disable the data bus bit and LCD enable bit
                STRB   R1, [R0, #Control_port]               ; Read from LCD Control [XXXX X100] -> Control port
AWAIT_LOOP    
                ORR    R1, R1,  #Enab_LCD                    ; Trigger LCD read
                STRB   R1, [R0, #Control_port]               ; Enable interface [XXXX X101] -> Control port
                LDRB   R2, [R0, #Data_port]                  
                BIC    R1, R1,  #Enab_LCD                    ; End LCD trigger
                STRB   R1, [R0, #Control_port]               ; [XXXX X100] -> Control port
                TST    R2, #Busy_LCD           
                BNE    AWAIT_LOOP
            

                POP    {R0-R2}                 
                MOV    PC, LR                   


; ===============================================================
;               WRITE CHARACTER TO LCD
; PARAMETERS:   R2 - CHARACTER WANTED
; ===============================================================
WRITE_CHARACTER
                PUSH   {R0, R1, LR}
                BL     WAIT_TILL_LCD_READY
                MOV    R0, #Port_area            
                LDRB   R1, [R0, #Control_port]   
                BIC    R1, R1,  #(Read_LCD|Enab_LCD)         ; Enable Write to LCD and LCD Enable bit
                ORR    R1, R1,  #DBus_LCD                    ; Enable the data bus bit

                STRB   R1, [R0, #Control_port]               ; Write to LCD Control [0000 0010] -> Control port

                STRB   R2, [R0, #Data_port]                  ; Place the character onto the data port

                ORR    R1, R1, #Enab_LCD                     ; Trigger LCD
                STRB   R1, [R0, #Control_port]               ; [0000 0011] -> Control port
                BIC    R1, R1, #Enab_LCD
                STRB   R1, [R0, #Control_port]

                POP    {R0, R1, LR}
                MOVS   PC, LR

; ===============================================================
;               WRITE CHARACTER BYTE SEQUENCE TO LCD
; PARAMETERS:   R1 - POINTER TO DESIRED BYTE SEQUENCE 
;                    ENDING WITH \0
; ===============================================================
WRITE_CHAR_BYTES
                MRS    R0, SPSR
                PUSH   {LR, R0-R2}                  ; Save state of LR and SPSR,and R1,R2
WRITE_CHAR_BYTES_LOOP
                LDRB   R2, [R1]                     ; R2 <- Next character
                CMP    R2, #0                       ; If exit character '\0'....
                BEQ    WRITE_CHAR_BYTES_RETURN
                
                MOV    R0, #SVC_Write_char
                SVC    SVC_Write_char               ; Write character with character in R2
                
                ADD    R1, R1, #1                   ; Point to next character
                B      WRITE_CHAR_BYTES_LOOP        ; Continue printing the word

WRITE_CHAR_BYTES_RETURN 
                POP    {LR, R0-R2}                  ; Load state of LR and SPSR again
                MSR    SPSR, R0
                MOVS   PC, LR


; ===============================================================
;               WRITE LOWER DIGITS OF NUMBER IN HEX TO LCD
; PARAMETERS:   R0 - NUMBER WE WANT TO WRITE TO LCD
; ===============================================================        
WRITE_HEX_DIGIT
                PUSH   {R2, LR}
                AND    R2, R0, #&F                  ; Mask off everything except lower 4 bits
                CMP    R2, #10
            
                ADDHI  R2, R2, #('A'-10)            ; If number is >= 10, write hex letter
                ADDLO  R2, R2, #('0')               ; if number is < 10, write arabic numeral
                
                BL     WAIT_TILL_LCD_READY

                MOV    R0, #SVC_Write_char
                SVC    SVC_Write_char
            
                POP    {R2, PC}

; 00 00 00 01

; 00 00 01 00
; 00 01 00 00
; 01 00 00 00
; 00 00 00 01
; Alien message

; ===============================================================
;               WRITE NUMBER IN HEX TO LCD
;               NOT A PRIVILEGED OPERATION
; PARAMETERS:   R1 - NUMBER WE WANT TO WRITE TO LCD
; ===============================================================
WRITE_NUMBER_IN_HEX
                PUSH   {LR, R0-R2}                  ; Save state of LR and SPSR
                MOV    R2, #(Word_length_b)
WRITE_NUMBER_IN_HEX_LOOP

                ROR    R1, R1, #(Word_length_b-1)*8   ; rotate to get desired byte
                ROR    R0, R1, #4
                BL     WRITE_HEX_DIGIT              ; Write the (upper) digit
                MOV    R0, R1                       ; Use the original Hex num
                BL     WRITE_HEX_DIGIT              ; Write the lower digit
                
                SUBS   R2, R2, #1
                BHI    WRITE_NUMBER_IN_HEX_LOOP

                POP    {PC, R0-R2}                  ; Load state of LR and SPSR again
