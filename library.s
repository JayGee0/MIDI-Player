; ===============================================================
;               OPERATING SYSTEM AND LIBRARY UTILITIES 
;               J. GEORGIS
;               VERSION 1.5
;               09.05.2024
;
; THIS PROVIDES THE OPERATING SYSTEM BACKEND. WILL INITIALISE
; THE HARDWARE BOARD AND DISPATCH SVCS TO DEFINED LIBRARY 
; FUNCTIONS. 
;
; NOTE: SVC OPERATIONS WILL LEAD TO R0 BEING OVERWRITTEN AS WELL
;       AS R1 FOR OUTPUT
; ===============================================================


; ===============================================================
;               DEFINED CONSTANTS
; ===============================================================
Word_length_b    EQU     4                      ; Word length in bytes

Port_area        EQU     &10000000              ; Set the port area at 10 000 000
Data_port        EQU     &0                     ; Set data port area at port area + 0
Control_port     EQU     &4                     ; Set control port at port area + 4
Timer_port       EQU     &8                     ; Set timer port area at port area + 8
Timer_cmp_port   EQU     &C                     ; Set timer port area at port area + 12

FPGA_area        EQU     &20000000              ; Set the FPGA port area at 20 000 000

Port_S0          EQU     &0                     ; Set PIO #S0 port at FPGA port area + 0
Port_S3          EQU     &C                     ; Set PIO #S0 port at FPGA port area + 0

BuzzerA_data     EQU     Port_S0+0              ; Set buzzer A data port to lower port S0 data
BuzzerA_control  EQU     Port_S0+1              ; Set buzzer A control port to lower port S0 control

Keyboard_data    EQU     Port_S0+2              ; Set keyboard data port to upper port S0 data
Keyboard_control EQU     Port_S0+3              ; Set keyboard control port to upper port S0 control

BuzzerB_data     EQU     Port_S3+1              ; Set buzzer B data port to lower port S3 'control'
BuzzerB_control  EQU     Port_S3+0              ; Set buzzer B control port to lower port S3 'data'

IRQ_port         EQU     &18                    ; Set interrupt request port area at port area + &18
IRQ_enab_port    EQU     &1C                    ; Set inerrupt request enable port area at port area + &1C
            
Stack_size       EQU     100                    ; Size of the stack
Max_SVC          EQU     (SVC_END-SVC_TABLE)/4  ; Maximum SVC number
Timer_range      EQU     256                    ; Timer word range = 2^8

CLR_mode         EQU     &1F                    ; Corresponds to bits of the CPSR that handles mode, used to clear the mode
USR_mode         EQU     &10                    ; CPSR code for User mode
SVC_mode         EQU     &13                    ; CPSR code for Supervisor mode
SYS_mode         EQU     &1F                    ; CPSR code for System mode
IRQ_mode         EQU     &12                    ; CPSR code for Interrupt mode

IRQ_disabled     EQU     &80                    ; CPSR interrupt disable bit      
FIQ_disabled     EQU     &40                    ; CPSR fast interrupt disable bit      


Button_lower     EQU     &80                    ; The read bit for the lower button
Button_upper     EQU     &40                    ; The read bit for the upper button
LCD_backlight    EQU     &20                    ; Enable/Disable LCD backlight
LED_enable       EQU     &10                    ; Enable/Disable LEDs
Button_extra     EQU     &08                    ; The read bit for the extra button (top-left)
Read_LCD         EQU     &04                    ; Set to read from LCD (0 = Write, 1 = Read)
DBus_LCD         EQU     &02                    ; Set which bus (0 = Control, 1 = Data)
Enab_LCD         EQU     &01                    ; Set interface active 

IRQ_timer_cmp    EQU     &01                    ; Interrupt bit assignment for timer compare

Interrupt_bits   EQU     IRQ_timer_cmp          ; Enable corresponding interrupt bits 

; ===============================================================
; INTERRUPT BITS
; 7       0
; LUTR EVST
; T - Timer Compare
; S - Spartan FPGA
; V - Virtex FPGA
; E - Ethernet interface
;
; R - Serial RxD ready
; T - Serial TxD ready
; U - Upper button
; L - Lower button
; ===============================================================


ORG 0

RESET           B      INIT
INSTRUCT_ERROR  B      .
SUPERVISOR      B      DISPATCH_SVC      
PFECH_ABORT     B      .
DATA_ABORT      B      .
                B      .                        ; Just in case
IRQ             B      DISPATCH_IRQ 
FIQ             B      .                       


; ===============================================================
;               INITIALISE STACK AND COMPONENTS
; ===============================================================
INIT  

;               INITIALISE SP OF SV, USR, IR
INIT_STACKS
                ADRL   SP, Supervisor_stack_area

                MRS    R0, CPSR                ; Get current status
                BIC    R1, R0, #CLR_mode       ; Clear the mode-defining bits

                ORR    R1, R1, #SYS_mode       ; Enter SYS mode
                MSR    CPSR, R1
                NOP
                ADRL   SP, User_stack_area 
                
                BIC    R1, R1, #CLR_mode       ; Clear the mode-defining bits
                ORR    R1, R1, #IRQ_mode       ; Enter IRQ mode
                MSR    CPSR, R1
                NOP
                ADRL   SP, Interrupt_stack_area


                MSR    CPSR, R0                ; Return to Supervisor mode
                NOP

INIT_COMPONENTS
                BL     INIT_CONTROL_PORT        
                BL     INIT_LCD
                BL     INIT_KEYBOARD
                BL     INIT_INTERRUPTS

DISPATCH_USER_MODE
                MOV    LR, #(USR_mode|FIQ_disabled) ; User mode, no fast interrupts
                MSR    SPSR, LR
                ADRL   LR, MAIN
                MOVS   PC, LR

; ===============================================================
;               DISPATCH THE REQUIRED SVC
;               R0 - UNSIGNED NUMBER SPECIFYING WHICH SVC 
;                    METHOD TO CALL. WILL BE OVERWRITTEN
; ===============================================================
DISPATCH_SVC    CMP    R0, #Max_SVC            ; Check whether specified R0 exceeds the Max SVC 
                LDRLO  PC, [PC, R0, LSL #2]    ; Point to the right address in the table (PC + R0 * 4) + GOTO the right call
                BHS    HALT                    ; HALT if wrong use of SVC

SVC_TABLE       DEFW   HALT                   
                DEFW   WRITE_CHARACTER        
                DEFW   WRITE_CHAR_BYTES   
                DEFW   WRITE_NUMBER_IN_HEX
                DEFW   WAIT_TILL_LCD_READY
                DEFW   CLEAR_SVC
                DEFW   SHIFT_LCD_CURSOR_LEFT
                DEFW   READ_TIMER
                DEFW   READ_CONTROL
                DEFW   SCAN_KEYBOARD
                DEFW   POP_LAST_KEY_PRESSED
                DEFW   PEAK_LAST_KEY_PRESSED
                DEFW   PLAY_NOTE_B
                DEFW   PLAY_NOTE_A
                DEFW   DISABLE_BUZZER_A

SVC_END
                SVC_Halt             EQU 0
                SVC_Write_char       EQU 1
                SVC_Write_char_bytes EQU 2
                SVC_Write_number     EQU 3
                SVC_Await_lcd        EQU 4                             
                SVC_Clear_lcd        EQU 5                             
                SVC_Shift_left_lcd   EQU 6                             
                SVC_Read_timer       EQU 7 
                SVC_Read_control     EQU 8   
                SVC_Scan_keyboard    EQU 9                          
                SVC_Pop_last_key     EQU 10  
                SVC_Peak_last_key    EQU 11                          
                SVC_Play_note_B      EQU 12  
                SVC_Play_note_A      EQU 13                        
                SVC_Disable_buzzer_A EQU 14    
                     

; ===============================================================
;               INTERRUPT SERVICE ROUTINE
;               THERE IS ONLY ONE INTERRUPT, SO JUMP TABLE NOT
;               REQUIRED FOR NOW. 
; ===============================================================
DISPATCH_IRQ                         
                SUB    LR, LR, #4                   ; Correct the return address
                PUSH   {R0-R3, LR}           

                MOV    R0, #Port_area
                LDRB   R1, [R0, #IRQ_port]      
                LDRB   R2, [R0, #IRQ_enab_port]
                AND    R1, R1, R2                   ; Only those that are enabled AND requires servicing will be serviced
                MOV    R3, #&100

ISR_LOOP
                ASRS   R3, R3, #1
                BEQ    ISR_EXIT                     ; If we have cycled through the bit assignment, exit (false interrupt)
                TST    R1, R3
                BEQ    ISR_LOOP                     ; Test first whether particular interrupt service is enabled

                BIC    R1, R1, R3
                STRB   R1, [R0, #IRQ_port]          ; Acknowledge the interrupt
                
                
                LDRB   R2, [R0, #Control_port]      
                TST    R2, #(Button_upper|Button_lower)
                MOVNE  R9, #0                       ; Check if any end button pressed

                LDRB   R2, [R0, #Timer_port]        ; Load timer value into R2
                
                ADD    R2, R2, #2                   ; 2ms Debounce time
                STRB   R2, [R0, #Timer_cmp_port]

                BL     READ_KEYBOARD
ISR_EXIT
                LDMFD  SP!, {R0-R3,PC}^             ; Restore and Return


; ===============================================================
;               HALT THE PROGRAM BY WRITING TO ADDRESS
;               PORT AREA + &20
; ===============================================================
HALT
                MOV    R0, #Port_area         
                STRB   R0, [R0, #&20]          ; HALT the program
                B      HALT                    ; Cautious
                
; ===============================================================
;               INITIALISE THE CONTROL PORT TO 0x00
; ===============================================================
INIT_CONTROL_PORT
                MOV    R0, #Port_area
                LDRB   R1, [R0, #Control_port]
                BIC    R1, R1, #(LCD_backlight|LED_enable|Read_LCD|DBus_LCD|Enab_LCD)
                STRB   R1, [R0, #Control_port]

                MOV    PC, LR

; ===============================================================
;               INITIALISE THE ENABLING OF REQUIRED 
;               INERRUPTS 
; ===============================================================
INIT_INTERRUPTS
                MOV    R0, #Port_area
                MOV    R1, #Interrupt_bits
                STRB   R1, [R0, #IRQ_enab_port]

                MOV    PC, LR

; ===============================================================
;               READ TIMER
;               OUTPUT TO R1
; ===============================================================
READ_TIMER
                MOV    R1, #Port_area
                LDRB   R1, [R1, #Timer_port]        ; Load timer value into R1
                MOVS   PC, LR

; ===============================================================
;               READ PIO_B CONTROL
;               OUTPUT TO R1
; ===============================================================
READ_CONTROL
                MOV    R1, #Port_area
                LDRB   R1, [R1, #Control_port]      ; Load PIO_B value into R1
                MOVS   PC, LR

; ===============================================================
;               INCLUDE OTHER LIBRARIES
; ===============================================================
INCLUDE         lcd.s
INCLUDE         keyboard.s
INCLUDE         buzzer.s

; ===============================================================
;               SPECIAL ALLOCATED MEMORY
; ===============================================================


DEFS    Stack_size
Supervisor_stack_area  
DEFS    Stack_size
Interrupt_stack_area  
DEFS    Stack_size
User_stack_area  
