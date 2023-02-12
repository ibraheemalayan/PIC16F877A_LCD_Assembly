	PROCESSOR 16F877A
	__CONFIG 0x3731 ; Clock = XT 4MHz, standard fuse settings
	INCLUDE "P16F877A.INC"


; ----------- Data Area -----------

RS	EQU 1		; Register select output bit
E	EQU 2		; Enable display input

; 	Uses GPR 70 - 75 for LCD Data
Timer1	EQU 0x70		; 1ms count register
TimerX	EQU 0x71		; Xms count register
Var	EQU 0x72		; Output variable
Point	EQU 0x73		; Program table pointer
Select	EQU 0x74		; Used to set or clear RS bit
OutCod	EQU 0x75		; Temp store for output code


counter	EQU 0x20	; Counter register
counterBlink	EQU 0x21; counter FOR Blinking register

LCD_CURSOR	EQU 0x22; LCD_CURSOR register
Location	EQU 0xC0; counter for LCD_CURSOR
blinkDelay	EQU 0x50; Delay time for cursor blink :can be adjusted as needed

CURSOR		EQU D'124'	; CURSOR: "  |  "
WHITE		EQU D'32'	; WHITE space character

ACHAR		EQU	D'65'; A
ACHAR		EQU	D'65'; A
currentCharReg	EQU	0x23;
TEMP	EQU 0x24; variable for temporar data


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
	MOVWF	LCD_CURSOR	; Store the value in the LCD_CURSOR register

	MOVLW	ACHAR		; Load initial value of char 'A' To W
	MOVWF	currentCharReg	; Store the value in the currentCharReg register
    


; Initialise Timer0 for push button

	BANKSEL OPTION_REG
	
	MOVLW	b'11011000'	; TMR0 initialisation code
	MOVWF	OPTION_REG		; Int clock, no prescale	
	
	CALL LABEL_REACH ; announce reaching this line

	BANKSEL	INTCON		; Select bank 0
	MOVLW	b'10100000'	; INTCON init. code
	MOVWF	INTCON		; Enable TMR0 interrupt


; Port & display setup
	BANKSEL TRISD ; Select bank 1
	CLRF TRISD ; Port D as output to LCD

	BANKSEL PORTD ; Select bank 0
	CLRF PORTD ; Clear display outputs


;Port B defaults to inputs for the push button :using pin 1

	CALL	initialize_display ; Initialise the display FOR LCD
	CALL	PUTEnterStringOnLCD



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
	BSF Select,RS ; Set to data mode
	MOVF LCD_CURSOR, W ; Load the current position into the W register
	ADDWF Point, F ; Calculate the address of the character to be shifted
	MOVF Point, W ; Load the address of the character to be shifted into the W register
	; CALL read ; Read the value at that address
	MOVWF OutCod ; Store the value in OutCod
	BCF Select,RS ; Set to command mode
	MOVLW 0x14 ; Move cursor one position to the right
	ADDWF LCD_CURSOR, F ; Update the cursor position
	MOVLW 0x80 ; Move cursor to the second row, first column
	ADDWF LCD_CURSOR, W ; Calculate the address of the second row, first column
	MOVWF Point ; Store the address in Point
	BSF Select,RS ; Set to data mode
	MOVF OutCod, W ; Load the value stored in OutCod into the W register
	CALL send ; Output the value to the display
	BCF Select,RS ; Set to command mode
	MOVLW 0x10 ; Move cursor one position to the right
	ADDWF LCD_CURSOR, F ; Update the cursor position
	RETURN ; Return to the calling routine


MOVELEFTONLCD
	BSF Select,RS ; Set to data mode
	MOVF LCD_CURSOR, W ; Load the current position into the W register
	ADDWF Point, F ; Calculate the address of the character to be shifted
	MOVF Point, W ; Load the address of the character to be shifted into the W register
	; CALL read ; Read the value at that address
	MOVWF OutCod ; Store the value in OutCod
	BCF Select,RS ; Set to command mode
	MOVLW 0x10 ; Move cursor one position to the left
	ADDWF LCD_CURSOR, F ; Update the cursor position
	MOVLW 0x80 ; Move cursor to the second row, first column
	ADDWF LCD_CURSOR, W ; Calculate the address of the second row, first column
	MOVWF Point ; Store the address in Point
	BSF Select,RS ; Set to data mode
	MOVF OutCod, W ; Load the value stored in OutCod into the W register
	CALL send ; Output the value to the display
	BCF Select,RS ; Set to command mode
	MOVLW 0x14 ; Move cursor one position to the left
	ADDWF LCD_CURSOR, F ; Update the cursor position
	RETURN ; Return to the calling routine

PUTEnterStringOnLCD 
	BCF Select,RS ; command mode
	MOVLW 0x80    ; move cursor to first line, first column
	CALL send     ; output it to display
	BSF Select,RS ; data mode
	MOVLW 'E';
	CALL send;
	MOVLW 'n';
	CALL send; 
	MOVLW 't';
	CALL send;
	MOVLW 'e'; 
	CALL send; 
	MOVLW 'r';
	CALL send;
	MOVLW ' ';
	CALL send;
	MOVLW 'S';
	CALL send;
	MOVLW 't';
	CALL send;
	MOVLW 'r';
	CALL send; 
	MOVLW 'i';
	CALL send;
 	MOVLW 'n'; 
	CALL send; 
	MOVLW 'g';
	RETURN
	
	


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Start Loop senario;;;;;;;;;;;;;;;;;;;;;;;;;;;
LOOPTOLOCATION
	CALL	BLINK		;  blinking the cursor at the Location to Write before pushing the button 
	CALL	LOOPtoIndex	; changing the char
	INCF	LCD_CURSOR, F
	RETURN

LOOPtoIndex
	CALL	PINSTABLE
	CALL	waitINT
	CALL	IsReleased
	BCF	Select,RS	; command mode
	MOVWF	LCD_CURSOR	; Selection Location
	CALL	send		; send command 
	BSF	Select,RS	; data mode
	MOVF currentCharReg, W	;Write char A on W
	CALL	send		; send Data
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
	BCF	Select,RS	; command mode
	MOVWF	LCD_CURSOR	; Selection Location
	CALL	send		; send command 
	BSF	Select,RS	; data mode

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
	CALL	send		; send Data
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
		
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;End Loop senario;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;Add blinking Delay ;;;;;;;;;;;;;;;;;;;;;;;;;;
BLINK
	MOVLW	blinkDelay	; Load the delay value into W
	CALL	DELAY		; Wait for the delay time to pass
	BTFSS	PORTB,1		; Double cheak  button
	RETURN			;

	BCF	Select,RS	; command mode
	MOVWF	LCD_CURSOR	; Selection Location
	CALL	send		; send command 
	BSF	Select,RS	; data mode
	MOVLW	CURSOR		; |
	CALL	send		; send CURSOR
	

	MOVLW	blinkDelay	; Load the delay value into W
	CALL	DELAY		; Wait for the delay time to pass
	BTFSS	PORTB,1		; Double cheak  button
	RETURN			;

	BCF	Select,RS	; command mode
	MOVWF	LCD_CURSOR	; Selection Location
	CALL	send		; send command 
	BSF	Select,RS	; data mode
	MOVLW	WHITE		; 
	CALL	send		; WHITE
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
loop1	NOP			; Pad for 4 cycle loop
	DECFSZ	Timer1		; Count
	GOTO	loop1		; until Z
	RETURN			; and finish

;--------------------------------------------------------------
;	Delay Xms
;	Receives count in W, uses Onems
;--------------------------------------------------------------
xms	MOVWF	TimerX		; Count for X ms
loopX	CALL	onems		; Delay 1ms
	DECFSZ	TimerX		; Repeat X times 
	GOTO	loopX		; until Z
	RETURN			; and finish

;--------------------------------------------------------------
;	Generate data/command clock siganl E
;--------------------------------------------------------------
pulseE	BSF	PORTD,E		; Set E high
	CALL	onems		; Delay 1ms
	BCF	PORTD,E		; Reset E low
	CALL	onems		; Delay 1ms
	RETURN			; done

;--------------------------------------------------------------
;	Send a command byte in two nibbles from RB4 - RB7
;	Receives command in W, uses PulseE and Onems
;--------------------------------------------------------------
send	MOVWF	OutCod		; Store output code
	ANDLW	0F0		; Clear low nybble
	MOVWF	PORTD		; Output high nybble
	BTFSC	Select,RS	; Test RS bit
	BSF	PORTD,RS	; and set for data
	CALL	pulseE		; and clock display register
	CALL	onems		; wait 1ms for display

	SWAPF	OutCod		; Swap low and high nybbles 
	MOVF	OutCod,W	; Retrieve output code
	ANDLW	0F0		; Clear low nybble
	MOVWF	PORTD		; Output low nybble
	BTFSC	Select,RS	; Test RS bit
	BSF	PORTD,RS	; and set for data
	CALL	pulseE		; and clock display register
	CALL	onems		; wait 1ms for display
	RETURN			; done

;--------------------------------------------------------------
;	Initialise the display
;	Uses Send
;--------------------------------------------------------------
initialize_display	MOVLW	D'100'		; Load count for 100ms delay
	CALL	xms		; and wait for display start
	MOVLW	0F0		; Mask for select code
	MOVWF	Select		; High nybble not masked

	MOVLW	0x30		; Load initial nibble
	MOVWF	PORTD		; and output it to display
	CALL	pulseE		; Latch initial code
	MOVLW	D'5'		; Set delay 5ms
	CALL	xms		; and wait
	CALL	pulseE		; Latch initial code again
	CALL	onems		; Wait 1ms
	CALL	pulseE		; Latch initial code again
	BCF	PORTD,4		; Set 4-bit mode
	CALL	pulseE		; Latch it
	
	MOVLW	0x28		; Set 4-bit mode, 2 lines
	CALL	send		; and send code
	MOVLW	0x08		; Switch off display
	CALL	send		; and send code
	MOVLW	0x01		; Code to clear display
	CALL	send		; and send code
	MOVLW	0x06		; Enable cursor auto inc  
	CALL	send		; and send code
	MOVLW	0x80		; Zero display address
	CALL	send		; and send code
	MOVLW	0x0C		; Turn on display  
	CALL	send		; and send code

	RETURN			; Done

;--------------------------------------------------------------End LCD CODE-------------------------------------
DONE
	END
	