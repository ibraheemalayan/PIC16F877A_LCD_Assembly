	PROCESSOR 16F877A
	__CONFIG 0x3731 ; Clock = XT 4MHz, standard fuse settings
	INCLUDE "P16F877A.INC"


; ----------- Data Area -----------

LCD_RS_PIN	EQU 4		; Register select output bit
LCD_E_PIN	EQU 5		; Enable display input

; 	Uses GPR 70 - 75 for LCD Data
Timer1	EQU 0x70		; 1ms count register
TimerX	EQU 0x71		; Xms count register
Var	EQU 0x72		; Output variable
Point	EQU 0x73		; Program table pointer
TEMP	EQU 0x75		; Temp store
TEMP2	EQU 0x76		; Temp2 store

LCD_CUSROR	EQU 0x22; LCD_CUSROR register
blinkDelay	EQU 0x50; Delay time for cursor blink :can be adjusted as needed

CSR_LOC		EQU D'124'	; CSR_LOC: "  |  "
WHITE		EQU D'32'	; WHITE space character

ACHAR		EQU	D'65'; A
ACHAR		EQU	D'65'; A
currentCharReg	EQU	0x23;


; ---------------------------------
; ----------- Code Area -----------
; ---------------------------------

    ORG	0x0000 		; Start of program memory
    NOP			; For ICD mode
    GOTO START_EXECUTION

ORG	0x0004 ; ISR

	MOVLW	b'00100111'		; least significant bits of TMR1
	MOVWF	TMR1L
	MOVLW	b'11111111'		; most significant bits of TMR1
	MOVWF	TMR1H

	; CLEAR OVERFLOW FLAG
	BCF 	PIR1,TMR1IF	

	BTFSS	INTCON, INTF	; based on INTCON INTF Bit
	GOTO 	ISR_FOR_TIMER
	GOTO 	ISR_FOR_BTN

ISR_FOR_TIMER

; TODO increment_letter, check if Z, check if space

    BCF 	PIR1,TMR1IF     ; clear the TMR1 ov flag 
	BCF		INTCON,INTF		; clear the External Interrupt Flag bit
    RETFIE


ISR_FOR_BTN

; TODO increment_letter, check if Z, check if space

    

	BSF PORTC,3
	BSF PORTC,4


	MOVLW	0xAF ; set delay iterations
	
	CALL DELAY_W
	CALL DELAY_W
	CALL DELAY_W

	CLRF PORTC

	
	CALL DELAY_W
	CALL DELAY_W
	CALL DELAY_W

	BSF PORTC,4
	BSF PORTC,5
	BSF PORTC,6
	BSF PORTC,7



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

	MOVWF	LCD_CUSROR	; Store the value in the LCD_CUSROR register

	MOVLW	ACHAR		; Load initial value of char 'A' To W
	MOVWF	currentCharReg	; Store the value in the currentCharReg register

	CALL	SETUP_LCD ; Initialise the display FOR LCD
	CALL	LCD_WRITE_PROMPT


	CALL	LABEL_REACH ; announce reaching this line



; used to announce reaching a section of the code
LABEL_REACH

    BANKSEL PORTC
	CLRF PORTC
    
	MOVLW	0x80 ; set delay loop to 60 iterations

	BSF PORTC,0
	CALL DELAY_W
	BSF PORTC,1
	CALL DELAY_W

	MOVLW	0xFF ; set delay loop to 255 iteration
	CALL DELAY_W

	BCF PORTC,0
	BCF PORTC,1

	CALL DELAY_W

	GOTO LABEL_REACH ; loop for ever

; 200 instructions delay
DELAY_W	
	MOVWF	TEMP
loop_start

	NOP
	NOP
	NOP
	NOP
	NOP
	NOP

	DECFSZ	TEMP
	GOTO	loop_start
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
;	Send a command byte in two nibbles from RB4 - RB7
;	Receives command in W, uses PulseE and Onems
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

;--------------------------------------------------------------End LCD CODE-------------------------------------
DONE
	END
	