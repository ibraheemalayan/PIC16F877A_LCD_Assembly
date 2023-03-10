	PROCESSOR 16F877A
	__CONFIG 0x3731 ; Clock = XT 4MHz, standard fuse settings
	INCLUDE "P16F877A.INC"


; ----------- Data Area -----------

LCD_RS_PIN	EQU 4		; Register select output bit
LCD_E_PIN	EQU 5		; Enable display input
MAX_CHARS	EQU 5


; 	Uses GPR 70 - 75 for LCD Data
Timer1	EQU 0x70		; 1ms count register
TimerX	EQU 0x71		; Xms count register
Var	EQU 0x72		; Output variable
Point	EQU 0x73		; Program table pointer


TEMP	EQU 0x75		; Temp store
TEMP2	EQU 0x76		; Temp2 store

RESET_PROG	EQU 0x77		; resets program

blinkDelay	EQU 0x50; Delay time for cursor blink :can be adjusted as needed

CRS_LOCATION_IN_ANIMATION EQU 0x41

CSR_LOC		EQU D'124'	; CSR_LOC: "  |  "
WHITE		EQU D'32'	; WHITE space character

CURRENT_CHAR EQU 0x26

COUNT EQU 0x29

CURRENT_CHAR_INDEX EQU 0x30

C1 EQU 0x35
C2 EQU 0x36
C3 EQU 0x37
C4 EQU 0x38
C5 EQU 0x39

TIMER_INDEX		   EQU 0x28

STRINGLEN		   EQU 0x51
; ---------------------------------
; ----------- Code Area -----------
; ---------------------------------

    ORG	0x0000 		; Start of program memory
    NOP			; For ICD mode
    GOTO START_EXECUTION

	ORG	0x0004 ; ISR

		
	BCF 	PIR1,TMR1IF
	BTFSS	INTCON, INTF	; based on INTCON INTF Bit
	GOTO 	ISR_FOR_TIMER
	GOTO 	ISR_FOR_BTN

RESET_TIMER
	MOVLW	0
	BANKSEL	TMR1L
	MOVWF	TMR1L
	MOVWF	TMR1H
	MOVLW	0x02
	BANKSEL	TIMER_INDEX
	MOVWF	TIMER_INDEX
	RETURN


ISR_FOR_TIMER

; TODO increment_letter, check if Z, check if space

	BANKSEL	TIMER_INDEX
	DECFSZ	TIMER_INDEX
	GOTO	SKIP1
	CALL	MOVE_TO_NEXT_CHAR
	MOVLW	0x7f ; reset the timer
	MOVWF	TIMER_INDEX
	BANKSEL	CURRENT_CHAR
	MOVF CURRENT_CHAR, W
	SUBLW 0x21 ; ASCII Of Space + 1	
	BTFSS	STATUS, Z
	GOTO	SKIP1
	BANKSEL PORTC
	BSF	PORTC, 5
	; CALL	FINISH_STRING

SKIP1
    BCF 	PIR1,TMR1IF     ; clear the TMR1 ov flag 
	BCF		INTCON,INTF		; clear the External Interrupt Flag bit
    RETFIE


ISR_FOR_BTN
	CALL RESET_TIMER
    CALL INCREMENT_CURRENT_CHAR
    CALL CHECK_IF_Z
	CALL CHECK_IF_SPACE
	; CALL TEST_CHECK_TO_MOVE


	CALL DISPLAY_CURRENT_CHAR

	; TODO increment_letter, check if Z, check if space
    BCF 	PIR1,TMR1IF     ; clear the TMR1 ov flag 
	BCF		INTCON,INTF		; clear the Interrupt flag 
    RETFIE

SETUP_PORTS_DIGITAL

	BANKSEL ADCON1 
	MOVLW	0x06		; Disable A/D Conversion
	MOVWF	ADCON1

	BANKSEL CMCON 
	MOVLW	0x07		; Disable Comparator
	MOVWF	CMCON

	RETURN


SETUP_INTERRUPTS

	BANKSEL TRISB	

	BSF TRISB, 0x00 ; Set Port B Direction To Input
	BSF OPTION_REG, INTEDG ; Rising Edge
	BCF INTCON,INTF ; Clear Interrupt Flag
	BSF INTCON,INTE ; Enable RB0 Interrupt Bit 
	BSF INTCON,GIE ; Enable Global Interrupt Bit
	bsf     INTCON, PEIE        ; Enable Peripheral Interrupts
	bsf     INTCON, GIE         ; Enable Global Interrupt	
	BANKSEL T1CON
	MOVLW	b'00111001'		; TMR1 initialisation code
	MOVWF	T1CON			; Int clock, prescale128	
	MOVLW	b'00000000'		; MOVE VALUE TO LOWER TMR1 REGISTER
	MOVWF	TMR1L			; 
	MOVLW	b'00000000'		; MOVE VALUE TO HIGHER TMR1 REGISTER
	MOVWF	TMR1H			; CLEAR OVERFLOW FLAG
	
	BANKSEL PIE1            ; ENABLE TMR1 INTERRUPT FLAG
	BSF PIE1,TMR1IE

	BANKSEL PIR1
	BCF PIR1, TMR1IF ;clear TMR1 interrupt flag

	;Start the timer:
	BSF T1CON, TMR1ON ;set TMR1 on bit	
	BCF PIR1, TMR1IF

	MOVLW	0x7f
	MOVWF	TIMER_INDEX
	; CLEAR OVERFLOW FLAG
	BCF 	PIR1,TMR1IF

	RETURN


INIT_DEBUG_PORT

	; port c is used for debugging
	BANKSEL TRISC
	MOVLW	0x00		; In order to set PORTC Direction to output
	MOVWF	TRISC
	RETURN



START_EXECUTION

	CALL INIT_DEBUG_PORT
	CALL SETUP_INTERRUPTS
	CALL SETUP_PORTS_DIGITAL

	BANKISEL CURRENT_CHAR_INDEX
	BANKSEL CURRENT_CHAR_INDEX

	

	 




	CALL	SETUP_LCD ; Initialise the display FOR LCD
	CALL	LCD_WRITE_PROMPT; write the promp "Enter String:"

	CALL	MOVE_CURSOR_TO_LINE_2_WRITE_A

    MOVLW C1
	MOVWF CURRENT_CHAR_INDEX

	CLRF COUNT
	
	CALL	BLINK_CURSOR ; blink cursor



; used to announce reaching a section of the code
BLINK_CURSOR

	MOVLW	0x0E ; cursor blink
	CALL	PulseWriteCmdToLCD ; send command

	; delay 10ms * 40 = 400ms
	MOVLW 0x28
	CALL DELAY_W_10_MS

	MOVLW	0x0C ; cursor off
	CALL	PulseWriteCmdToLCD ; send command

	; delay 10ms * 20 = 200ms
	MOVLW 0x14
	CALL DELAY_W_10_MS

	GOTO BLINK_CURSOR ; loop for ever

; instruction delay of 10us * W (each instruction is 1us)
DELAY_W	
	MOVWF	TEMP
loop_start

	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP

	DECFSZ	TEMP
	GOTO	loop_start
	RETURN

; instruction delay of ms * W (each loop is 10ms)
DELAY_W_10_MS	
	MOVWF	TEMP2
	MOVLW	0xFA
lp_st
    
	CALL DELAY_W
	CALL DELAY_W
	CALL DELAY_W
	CALL DELAY_W

	DECFSZ	TEMP2
	GOTO	lp_st
	RETURN

;--------------------------------------------------------------Start LCD CODE----------------------------------
;	1ms delay with 1us instruction time (1000 cycles)
;--------------------------------------------------------------
onems	MOVLW	D'249'		; Count for 1ms delay 
	MOVWF	Timer1		; Load count
LP	NOP			; Pad for 4 cycle loop
	DECFSZ	Timer1		; Count
	GOTO	LP		; until Z
	RETURN			; and finish

;--------------------------------------------------------------
;	Generate data/command clock siganl E
;--------------------------------------------------------------
PULSE_LCD_E_PIN	BSF	PORTD, LCD_E_PIN		; Set E high
	CALL	onems		; Delay 1ms
	BCF	PORTD, LCD_E_PIN		; Reset E low
	CALL	onems		; Delay 1ms
	RETURN			; done


;--------------------------------------------------------------
;	Initialise the display
;--------------------------------------------------------------
SETUP_LCD	

	BANKSEL TRISD
	CLRF TRISD ; Port D as output to LCD

	BANKSEL PORTD

	CLRF	PORTD		; and output it to display

	MOVLW	0x40		; wait for display start
	CALL	DELAY_W
	
	
	MOVLW	0x02	; Set 4-bit mode
	CALL	PulseWriteCmdToLCD ; send command
	
	MOVLW	0x28		; Set 5 by 7 mode
	CALL	PulseWriteCmdToLCD ; send command

	; TODO remove
	; MOVLW	0x08		; Switch off display
	; CALL	PulseWriteCmdToLCD ; send command

	MOVLW	0x01		; Code to clear display
	CALL	PulseWriteCmdToLCD ; send command

	MOVLW	0x0E		; Display ON and cursor blinking
    CALL	PulseWriteCmdToLCD	; send command

	; MOVLW	0x06		; Enable cursor auto inc  
	; CALL	PulseWriteCmdToLCD ; send command

	MOVLW	0x80		; move cursor to first line, first column
	CALL	PulseWriteCmdToLCD ; send command

	MOVLW	0x0C		; Turn on display  
	CALL	PulseWriteCmdToLCD ; send command

	RETURN			; Done


PulseWriteCmdToLCD
	MOVWF TEMP
	SWAPF TEMP
	MOVF TEMP, W
	ANDLW 0x0f
	MOVWF PORTD
	BCF PORTD, LCD_RS_PIN ;Clearing the LCD_RS_PIN Register for command mode
	call PULSE_LCD_E_PIN
	;call onems
	SWAPF TEMP
	movf TEMP, W
	ANDLW	0x0f
	MOVWF PORTD
	BCF PORTD, LCD_RS_PIN ;Clearing the LCD_RS_PIN Register for command mode
	call PULSE_LCD_E_PIN
	RETURN

;--------------------------------------------------------------
;	Send a char byte
;--------------------------------------------------------------
PulseWriteCharToLCD
    MOVWF TEMP
    SWAPF TEMP
    MOVF TEMP, W
    ANDLW 0x0F ; Clear low nybble
    MOVWF PORTD
    BSF PORTD, LCD_RS_PIN ; set character mode on RS
    call PULSE_LCD_E_PIN ; clock LCD
    call onems
    SWAPF TEMP
    MOVF TEMP, W
    ANDLW	0x0F ; Clear high nybble
    MOVWF PORTD
    BSF PORTD, LCD_RS_PIN 
    call PULSE_LCD_E_PIN 
    RETURN

MOVE_CURSOR_TO_LINE_2_WRITE_A

	MOVLW	0xC0		
	CALL	PulseWriteCmdToLCD ; send command

	MOVLW 'A'
	MOVWF CURRENT_CHAR ; move A to current char

	CALL DISPLAY_CURRENT_CHAR

	RETURN





DISPLAY_CURRENT_CHAR

    MOVLW	0x0C	; turn cursor off
	CALL	PulseWriteCmdToLCD ; send command

    MOVF CURRENT_CHAR, W
	CALL PulseWriteCharToLCD

	MOVLW	0x10 ; shift cursor to left
	CALL	PulseWriteCmdToLCD ; send command

    MOVLW	0x0E	; turn cursor on
	CALL	PulseWriteCmdToLCD ; send command
	
	RETURN

LCD_WRITE_PROMPT 

	MOVLW	0x80		; move cursor to first line, first column
	CALL	PulseWriteCmdToLCD ; send command

	MOVLW 'E';
	CALL PulseWriteCharToLCD;

	MOVLW 'n';
	CALL PulseWriteCharToLCD;

	MOVLW 't';
	CALL PulseWriteCharToLCD;

	MOVLW 'e'; 
	CALL PulseWriteCharToLCD;

	MOVLW 'r';
	CALL PulseWriteCharToLCD;

	MOVLW ' ';
	CALL PulseWriteCharToLCD;

	MOVLW 'S';
	CALL PulseWriteCharToLCD;

	MOVLW 't';
	CALL PulseWriteCharToLCD;

	MOVLW 'r';
	CALL PulseWriteCharToLCD;

	MOVLW 'i';
	CALL PulseWriteCharToLCD;

 	MOVLW 'n'; 
	CALL PulseWriteCharToLCD;

	MOVLW 'g';
	CALL PulseWriteCharToLCD;

	MOVLW ':';
	CALL PulseWriteCharToLCD;

	RETURN

; ----------------------------- LOGIC -----------------------------

CHECK_IF_SPACE

    MOVF CURRENT_CHAR, W
	SUBLW 0x21 ; ASCII Of Space + 1

	BTFSS STATUS, Z ; Test zero & skip
    RETURN

	MOVLW 'A'
	MOVWF CURRENT_CHAR ; move A to current char

	RETURN

CHECK_IF_Z
	MOVF CURRENT_CHAR, W
	SUBLW 0x5B ; ASCII Of 'Z' + 1

	BTFSS STATUS, Z ; Test zero & skip
    RETURN

	MOVLW ' '
	MOVWF CURRENT_CHAR ; move A to current char

	RETURN


TEST_CHECK_TO_MOVE
	MOVF CURRENT_CHAR, W
	SUBLW 0x45 ; ASCII Of 'X' + 1

	BTFSS STATUS, Z ; Test zero & skip
    RETURN

	CALL MOVE_TO_NEXT_CHAR

	RETURN

INCREMENT_CURRENT_CHAR

    INCF CURRENT_CHAR, 1

	RETURN

MOVE_TO_NEXT_CHAR

    CLRF STATUS

	BANKSEL C1
	BCF STATUS, IRP ; bank select for indirect


	; Load address of array pointer into FSR
	MOVF CURRENT_CHAR_INDEX, W

	NOP
	
	
    MOVWF FSR

	BANKISEL C1
    
	; Load current char into w then into array ptr
	MOVF CURRENT_CHAR, W
	MOVWF INDF

	INCF CURRENT_CHAR_INDEX, 1

	MOVF CURRENT_CHAR, W
	SUBLW 0x20 ; ASCII Of Space + 1

	BTFSC STATUS, Z ; Test zero & skip
    GOTO	FINISH_STRING

	

	MOVLW	0x14 ; shift cursor to right
	CALL	PulseWriteCmdToLCD ; send command

	; check count ; -------------------

	INCF COUNT, 0x1

	CLRW 

	BCF STATUS, Z

	MOVLW 0x41
	MOVWF CURRENT_CHAR ; move A to current char
	CALL	PulseWriteCharToLCD

	MOVLW	0x10 ; shift cursor to left
	CALL	PulseWriteCmdToLCD ; send command


	MOVF COUNT, W
	SUBLW MAX_CHARS
	BTFSC	STATUS, Z ; if reached 5 go to FINISH_STRING
	GOTO	FINISH_STRING

	; ----------------------------------


    RETURN

CHECK_RESET

   MOVLW C1
   MOVWF CURRENT_CHAR_INDEX

   CLRF COUNT
   CLRF C1
   CLRF C2
   CLRF C3
   CLRF C4
   CLRF C5
   
   RETFIE

FINISH_STRING

    MOVLW	0x08 ; turn off display
	CALL	PulseWriteCmdToLCD ; send command

	BSF PORTC, 6

    ; delay 10ms * 100 = 1 s
	MOVLW 0x64
	CALL DELAY_W_10_MS

MOVING_LOOP_S

	MOVLW	0x01 ; clear display
	CALL	PulseWriteCmdToLCD ; send command

	MOVLW	0x0C ; turn on display without cursor
	CALL	PulseWriteCmdToLCD ; send command

	MOVLW	0x80 ; set cursor at begining of 1st line
	CALL	PulseWriteCmdToLCD ; send command
    
    MOVF C1, W 
	CALL	PulseWriteCharToLCD
	MOVF C2, W 
	CALL	PulseWriteCharToLCD
	MOVF C3, W 
	CALL	PulseWriteCharToLCD
	MOVF C4, W 
	CALL	PulseWriteCharToLCD
	MOVF C5, W 
	CALL	PulseWriteCharToLCD



	CLRF CRS_LOCATION_IN_ANIMATION

MOVING_LOOP

    MOVLW	0x80 ; set cursor at begining of 1st line
	CALL	PulseWriteCmdToLCD ; send command

    MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
    
	; delay 10ms * 50 = 500ms
	MOVLW 0x32
	CALL DELAY_W_10_MS

	INCF CRS_LOCATION_IN_ANIMATION, 1

	MOVF CRS_LOCATION_IN_ANIMATION, W
    SUBLW 0x10 ; column 16
    BTFSS STATUS, C
    GOTO REACHED_LINE_END
	GOTO MOVING_LOOP


REACHED_LINE_END

    MOVLW	0x01 ; clear screen
	CALL	PulseWriteCmdToLCD ; send command

	MOVLW	0xC0 ; set cursor at begining of 2nd line
	CALL	PulseWriteCmdToLCD ; send command

	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command
	MOVLW	0x1C ; shift screen to the right
	CALL	PulseWriteCmdToLCD ; send command

	MOVF C1, W 
	CALL	PulseWriteCharToLCD
	MOVF C2, W 
	CALL	PulseWriteCharToLCD
	MOVF C3, W 
	CALL	PulseWriteCharToLCD
	MOVF C4, W 
	CALL	PulseWriteCharToLCD
	MOVF C5, W 
	CALL	PulseWriteCharToLCD

	INCF CRS_LOCATION_IN_ANIMATION, 1
	INCF CRS_LOCATION_IN_ANIMATION, 1
	INCF CRS_LOCATION_IN_ANIMATION, 1
	INCF CRS_LOCATION_IN_ANIMATION, 1
	INCF CRS_LOCATION_IN_ANIMATION, 1

REACHED_LINE_END_LOOP

	MOVLW	0x18 ; shift screen to the left
	CALL	PulseWriteCmdToLCD ; send command
    
	; delay 10ms * 50 = 500ms
	MOVLW 0x32
	CALL DELAY_W_10_MS

	DECF CRS_LOCATION_IN_ANIMATION, 1

	MOVF CRS_LOCATION_IN_ANIMATION, W
    BTFSC STATUS, Z
    GOTO MOVING_LOOP_S
	GOTO REACHED_LINE_END_LOOP

	RETURN

DONE
	END



