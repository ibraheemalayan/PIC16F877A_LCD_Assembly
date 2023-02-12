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
TEMP	EQU 0x75		; Temp store for output code


counter	EQU 0x20	; Counter register
counterBlink	EQU 0x21; counter FOR Blinking register

LCD_CSR	EQU 0x22; LCD_CSR register
Location	EQU 0xC0; counter for LCD_CSR
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
    GOTO start_exec


start_exec

   

	BANKSEL TRISC
	MOVLW	0x00		; In order to set PORTC Direction to output
	MOVWF	TRISC

	BANKSEL ADCON1
	MOVLW	0x06		; Disable A/D Conversion
	MOVWF	ADCON1

	BANKSEL CMCON 
	MOVLW	0x07		; Disable Comparator
	MOVWF	CMCON

	MOVLW	0x5		; Load initial value of 5 into W
	MOVWF	counter		; Store the value in the counter register

	MOVLW	Location	; Load initial value of Location into W
	MOVWF	LCD_CSR	; Store the value in the LCD_CSR register

	MOVLW	ACHAR		; Load initial value of char 'A' To W
	MOVWF	currentCharReg	; Store the value in the currentCharReg register
    


; Initialise Timer0 for push button

	BANKSEL OPTION_REG

	MOVLW	b'11011000'	; TMR0 initialisation code
	MOVWF	OPTION_REG		; Int clock, no prescale	
	
    ; this is causing everything to crash
	; BANKSEL	INTCON		; select bank 0
	; MOVLW	b'10100000'	; INTCON init. code
	; MOVWF	INTCON		; Enable TMR0 interrupt

	



; Port & display setup
	BANKSEL TRISD ; select bank 1
	CLRF TRISD ; Port D as output to LCD

	BANKSEL PORTD ; select bank 0
	CLRF PORTD ; Clear display outputs


	

;Port B defaults to inputs for the push button :using pin 1

	CALL	SETUP_LCD ; Initialise the display FOR LCD
	CALL	PUTEnterStringOnLCD
	CALL LABEL_REACH ; announce reaching this line




; Main loop of 5 iterations
MAIN
	DECFSZ	counter, F	; Decrement the counter register and skip next instruction if non-zero
	CALL	LOOPTOLOCATION	; Loop senario
	MOVF	counter, W	; Load the value of the file register counter into the W register
	BTFSC	STATUS, Z
	CALL	MovingSTRING	
	;GOTO	MAIN		; Loop back if the value is non-zero
	GOTO 	DONE			; End of program

MovingSTRING
	MOVLW 0x80    ; move cursor to first line, first column
	ANDLW 0x0F ; Mask the lower 4 bits
	BTFSC STATUS, Z ; If the lower 4 bits are 0, skip the next instruction
	CALL MOVELEFTONLCD ; If the lower 4 bits are not 0, call the MOVELEFTONLCD routine
	CALL MOVERIGHTONLCD ; Call the MOVERIGHTONLCD routine

ENDMOVING	
	MOVLW	D'5'		; Load 5 into W
	MOVWF	counter		; Store the value 5 to the counter register to start again
	CALL	PUTEnterStringOnLCD

; used to announce reaching a section of the code
LABEL_REACH

    BANKSEL PORTC
    
	MOVLW	0x80 ; set delay loop to 60 iterations

	BSF PORTC,0
	CALL DELAY_W
	BSF PORTC,1
	CALL DELAY_W
	BSF PORTC,2
	CALL DELAY_W
	BSF PORTC,3
	CALL DELAY_W

	MOVLW	0xFF ; set delay loop to 255 iteration

	CALL DELAY_W

	BCF PORTC,0
	BCF PORTC,1
	BCF PORTC,2
	BCF PORTC,3

	CALL DELAY_W

	GOTO LABEL_REACH ; loop for ever

; 200 instructions delay
DELAY_W	
	MOVWF	TEMP
loop_start	NOP
		DECFSZ	TEMP
		GOTO	loop_start
		RETURN

MOVERIGHTONLCD
	BSF PORTD,LCD_RS_PIN ; Set to data mode
	MOVF LCD_CSR, W ; Load the current position into the W register
	ADDWF Point, F ; Calculate the address of the character to be shifted
	MOVF Point, W ; Load the address of the character to be shifted into the W register
	; CALL read ; Read the value at that address
	MOVWF TEMP ; Store the value in TEMP
	BCF PORTD,LCD_RS_PIN ; Set to command mode
	MOVLW 0x14 ; Move cursor one position to the right
	ADDWF LCD_CSR, F ; Update the cursor position
	MOVLW 0x80 ; Move cursor to the second row, first column
	ADDWF LCD_CSR, W ; Calculate the address of the second row, first column
	MOVWF Point ; Store the address in Point
	BSF PORTD,LCD_RS_PIN ; Set to data mode
	MOVF TEMP, W ; Load the value stored in TEMP into the W register
	CALL PulseWriteCharToLCD ; Output the value to the display
	BCF PORTD,LCD_RS_PIN ; Set to command mode
	MOVLW 0x10 ; Move cursor one position to the right
	ADDWF LCD_CSR, F ; Update the cursor position
	RETURN ; Return to the calling routine


MOVELEFTONLCD
	BSF PORTD,LCD_RS_PIN ; Set to data mode
	MOVF LCD_CSR, W ; Load the current position into the W register
	ADDWF Point, F ; Calculate the address of the character to be shifted
	MOVF Point, W ; Load the address of the character to be shifted into the W register
	; CALL read ; Read the value at that address
	MOVWF TEMP ; Store the value in TEMP
	BCF PORTD,LCD_RS_PIN ; Set to command mode
	MOVLW 0x10 ; Move cursor one position to the left
	ADDWF LCD_CSR, F ; Update the cursor position
	MOVLW 0x80 ; Move cursor to the second row, first column
	ADDWF LCD_CSR, W ; Calculate the address of the second row, first column
	MOVWF Point ; Store the address in Point
	BSF PORTD,LCD_RS_PIN ; Set to data mode
	MOVF TEMP, W ; Load the value stored in TEMP into the W register
	CALL PulseWriteCharToLCD ; Output the value to the display
	BCF PORTD,LCD_RS_PIN ; Set to command mode
	MOVLW 0x14 ; Move cursor one position to the left
	ADDWF LCD_CSR, F ; Update the cursor position
	RETURN ; Return to the calling routine


PUTEnterStringOnLCD 

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

	RETURN
	
	


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Start Loop senario;;;;;;;;;;;;;;;;;;;;;;;;;;;
LOOPTOLOCATION
	CALL	BLINK		;  blinking the cursor at the Location to Write before pushing the button 
	CALL	LOOPtoIndex	; changing the char
	INCF	LCD_CSR, F
	RETURN

LOOPtoIndex
	CALL	PINSTABLE
	CALL	waitINT
	CALL	IsReleased
	BCF	PORTD,LCD_RS_PIN	; command mode
	MOVWF	LCD_CSR	; selection Location
	CALL	PulseWriteCmdToLCD ; send command 
	BSF	PORTD,LCD_RS_PIN	; data mode
	MOVF currentCharReg, W	;Write char A on W
	CALL	PulseWriteCharToLCD		; send Data
	CALL	TIMER2S
	CALL	WaitButton	;Increment when button pressed
	RETURN
	
TIMER2S	
	MOVLW D'78' ; Count for 250ms delay
	MOVWF TMR2 ; Load count
	RETURN


WaitButton
	
LOOPTOLOCATION1
    MOVLW D'249' ; Count for 1ms delay
	MOVWF Timer1 ; Load count
LOOP1 NOP ; Pad for 4 cycle loop
	BTFSS  	PORTB,1   	; Test button
	GOTO	PRESED	
	DECFSZ Timer1 ; Count
	GOTO LOOP1 ; until Z
	DECFSZ TMR2 ; Count for 250ms
	GOTO LOOPTOLOCATION1 ; until Z

CheakForWhitSpaceToEndString
	MOVF	currentCharReg, W; Move the contents of currentCharReg to W
	SUBLW	' ' ; Subtract the value of ASCII space from w
	BTFSC	STATUS, Z	; Check if the result of the comparison is zero
	GOTO	SKIPtoNormal	; If the contents of char is not ' ', skip the next instruction
	MOVLW	'A'		; Load initial value of char 'A' To W
	MOVWF	currentCharReg	; Store the value in the currentCharReg register FOR the second iteration
	MOVLW	D'1'		; Load 1 into W
	MOVWF	counter		; Store the value 1 to the counter register TO END
	RETURN
	

SKIPtoNormal	
	MOVLW	'A'		; Load initial value of char 'A' To W
	MOVWF	currentCharReg	; Store the value in the currentCharReg register FOR the second iteration
	RETURN ;  finish 2 seconds

PRESED	
	CALL	PINSTABLE
	CALL	waitINT
	CALL	IsReleased

INCREMENTCHAR
	BCF	PORTD,LCD_RS_PIN	; command mode
	MOVWF	LCD_CSR	; selection Location
	CALL	PulseWriteCmdToLCD ; send command 
	BSF	PORTD,LCD_RS_PIN	; data mode

CheakForZ
	MOVF	currentCharReg, W; Move the contents of currentCharReg to W
	SUBLW	'Z' ; Subtract the value of ASCII Z from w
	BTFSC	STATUS, Z	; Check if the result of the comparison is zero
	GOTO	CheakForWhitSpace; If the contents of char is not 'Z', skip the next instruction
	MOVLW	' '		; Load the ASCII value of a white space into W
	MOVWF	currentCharReg	; Move W into currentCharReg
	GOTO	MOVETOLCD

CheakForWhitSpace
	MOVF	currentCharReg, W; Move the contents of currentCharReg to W
	SUBLW	' ' ; Compare W to the ASCII value of ' '
	BTFSC	STATUS, Z	; Check if the result of the comparison is zero
	GOTO	SKIP		; If the contents of char is not ' ', skip the next instruction
	MOVLW	'A'		; Load the ASCII value of 'A' into W
	MOVWF	currentCharReg	; Move W into currentCharReg
	GOTO	MOVETOLCD	
	
SKIP	
	INCF currentCharReg, F  ; Increment currentCharReg

MOVETOLCD
	MOVF currentCharReg, W	; Write char on W
	CALL	PulseWriteCharToLCD		; send Data
	CALL	TIMER2S		; Old value for timer 2 to mkae 2s
	GOTO	WaitButton	; To Update the same location
		
PINSTABLE	
	CLRF	TMR0		; Reset timer
	RETURN
waitINT	
	BTFSS	INTCON,2	; Check for time out"INT"
	GOTO	waitINT		; Wait if not
	RETURN
IsReleased	
	BTFSS	PORTB,1		; Check step button
	GOTO	IsReleased	; and wait until released
	RETURN

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
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;End Loop senario;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;Add blinking Delay ;;;;;;;;;;;;;;;;;;;;;;;;;;
BLINK
	MOVLW	blinkDelay	; Load the delay value into W
	CALL	DELAY		; Wait for the delay time to pass
	BTFSS	PORTB,1		; Double cheak  button
	RETURN			;

	BCF	PORTD,LCD_RS_PIN	; command mode
	MOVWF	LCD_CSR	; selection Location
	CALL	PulseWriteCmdToLCD ; send command 
	BSF	PORTD,LCD_RS_PIN	; data mode
	MOVLW	CSR_LOC		; |
	CALL	PulseWriteCmdToLCD		; send CSR_LOC
	

	MOVLW	blinkDelay	; Load the delay value into W
	CALL	DELAY		; Wait for the delay time to pass
	BTFSS	PORTB,1		; Double cheak  button
	RETURN			;

	BCF	PORTD,LCD_RS_PIN	; command mode
	MOVWF	LCD_CSR	; selection Location
	CALL	PulseWriteCmdToLCD ; send command 
	BSF	PORTD,LCD_RS_PIN	; data mode
	MOVLW	WHITE		; 
	CALL	PulseWriteCmdToLCD		; WHITE
	BTFSC	PORTB,1		; Test button
	GOTO	BLINK		; Loop back
	RETURN			; counterBlinking to Zero when clicking the button

DELAY
	MOVWF	counterBlink	; Store the delay value in the counter register
DELAY_LOOP
	BTFSS	PORTB,1		; Double cheak  button
	RETURN			;
	DECFSZ	counterBlink, F	; Decrement the counter and skip next instruction if non-zero
	GOTO	DELAY_LOOP	; Loop back if counter is non-zero	
	RETURN			; Return to main program
;;;;;;;;;;;;;;;;End blinking Delay ;;;;;;;;;;;;;;;;;;;;;;;;;; 


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

;--------------------------------------------------------------End LCD CODE-------------------------------------
DONE
	END
	