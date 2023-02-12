INCLUDE "P16F877A.INC"

	LIST   P=PIC16F877A
	__CONFIG 0x3731

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;DATA SEGMENT;;;;;;;;;;;;;;;;;
DCounter1 EQU 0X1C
DCounter2 EQU 0X2D
DCounter3 EQU 0X2E
DCount EQU 0X2F

OPTIONS_REG EQU 0x81
check_space_end EQU 60

W_TEMP EQU 62
STATUS_TEMP EQU 63
CounterHundred EQU 65
HundredFlag EQU 66
Timer1	EQU	70		; 1ms count register
TimerX	EQU	71		; Xms count register
Register1 EQU 72
EnableCounter EQU 73
letter EQU 74 
counter_high EQU 75
counter_mid EQU 77
counter_low EQU 76

Temp EQU 61
n1 EQU 78
n2 EQU 79
n3 EQU 7A
n4 EQU 7B
n5 EQU 7C
index EQU 7D
runningPhaseCounter EQU 7F
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;CODE SEGMENT;;;;;;;;;;;;;;;;

ORG	0x0000 		; Start of program memory
goto start


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Interrupt Service Routine;;;;;;;;;;;;
ORG	0x0004 ;Here this function will handle the catched interrupt
; Clear the Timer1 OVERFLOW FLAG
	MOVLW	b'00100111'		; MOVE VALUE TO LOWER TMR1 REGISTER
	MOVWF	TMR1L			; 
	MOVLW	b'11111111'		; MOVE VALUE TO LOWER TMR1 REGISTER
	MOVWF	TMR1H			; CLEAR OVERFLOW FLAG
	BCF 	PIR1,TMR1IF	
	BTFSS	INTCON,INTF	; Check if has RB0/INT has Occured
	GOTO 	TIMER_ISR
	GOTO 	BUTTON_ISR

;//////////////////////////////////////////////////////////////////
TIMER_ISR


;CALL 	check_if_space_end 
BTFSS STATUS, Z ; Test the zero flag in the STATUS register
goto jump



btfss check_space_end,0
goto jump

;disable the timer ISR
BANKSEL PIE1            ;DISABLE TMR1 INTERRUPT FLAG
BCF PIE1,TMR1IE
BCF STATUS, RP0 ;
BCF STATUS, RP1 ; Bank0

CALL return_index 
GOTO step_2

jump

;if it is the first time dont do anythin
btfsc check_space_end,1 ;
goto not_first_time


;first time
MOVLW	0xC0		  
CALL	SendCommand	 ; and send code
CALL    Cursor       ;print letter A
BCF 	PIR1,TMR1IF      ;clear the Timer1 OVERFLOW FLAG  
bsf check_space_end,1
retfie

;not first time
not_first_time
;CALL    increment_index

MOVLW	0x14		 ; INCREMENT Cursor 
CALL	SendCommand	 ; and send code
movfw 	letter
movwf 	Temp
CALL    store_index
CALL    increment_index
CALL 	increment_counter



CALL    check_if_space_end
;set the index to the first index  
movlw 	0x41	
movwf 	letter
movwf 	Temp
CALL 	Cursor


BCF 	PIR1,TMR1IF      ;clear the Timer1 OVERFLOW FLAG  
;CALL 	increment_letter

retfie


;//////////////////////////////////////////////////////////////////
; Interrupt Service Routine (ISR) for timer0 (Timer0 interrupt occurred)
BUTTON_ISR
CALL increment_letter
CALL Cursor
CALL check_if_Z
CALL check_if_space
BCF PIR1,TMR1IF		;clear the Timer1 OVERFLOW FLAG
BCF INTCON,INTF 	; Reset �Interrupt Flag� of INT
retfie



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Things need to be done before looping in main
start 


;Sending DATA "Enter Operation" Message 
movlw 0x41
movwf letter
movwf Temp

;clean;
movlw 0x00
movwf n1
movwf n2
movwf n3
movwf n4
movwf n5


CALL return_index

BCF STATUS, RP0 ;
BCF STATUS, RP1 ; Bank0
CLRF PORTA ; Initialize PORTA by clearing output data latches
BSF STATUS, RP0 ; Select Bank 1
MOVLW 0x06 ; Configure all pins
MOVWF ADCON1 ; as digital inputs
MOVLW 0x00 ; Value used to initialize data direction
MOVWF TRISA ; Set all As outputs 
BANKSEL PORTA ; Bank 0 






;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;First Message to Print on the First Line
CALL onems; To PowerON LCD DELAY
CALL onems; To PowerON LCD DELAY

;Configuring the Crystal to run
;using the 4-bit mode nibble by nibble
MOVLW	0x02		; Initialize Lcd in 4-bit mode
CALL	SendCommand		; and send code
MOVLW	0x28		; enable 5x7 mode for chars 
CALL	SendCommand		; and send code
MOVLW	0x01		; Clear Display
CALL	SendCommand		; and send code
; MOVLW	0x0E		; No Cursor ;No Blink
; CALL	SendCommand		; and send code
MOVLW	0x80		; Move the cursor to beginning of First Line
CALL	SendCommand		; and send code
;MOVLW	0x10	;	 ; INCREMENT Cursor 
;CALL	SendCommand	 ; and send code
 
 
call onems
movlW A'E' 
call PrintChar
movlW A'N' 
call PrintChar
CALL onems
movlW A'T' 
call PrintChar
movlW A'E' 
call PrintChar
movlW A'R' 
call PrintChar
movlW A' ' 
call PrintChar
movlW A'S' 
call PrintChar
movlW A'T' 
call PrintChar
movlW A'R' 
call PrintChar
movlW A'I' 
call PrintChar
movlW A'N' 
call PrintChar
movlW A'G' 
call PrintChar
movlW A':' 
call PrintChar

;This Function is to put the cursor on the start of the second Line
MOVLW	0xC0		; Move the cursor to beginning of Second Line
CALL	SendCommand		; and send code



; Configure Hardware interrupt
;Configure RB0 as input
 BANKSEL TRISB ; Bank 1 
 BSF TRISB,0 ; Set Port B, Bit Zero as an �Input� 
 BSF OPTIONS_REG, INTEDG ; Set �Rising� Edge INTEDG 
 BCF INTCON,INTF ; Reset �Interrupt Flag� of INT 
 BSF INTCON,INTE ; Set �Interrupt Enable Bit� of INT 
 BSF INTCON,GIE ; Set �Global� Int Enable  
 BCF STATUS, RP0 ;Bank0 
 BCF STATUS, RP1 ;  

bcf check_space_end,0 ;clear bit to check if last input is space

bcf check_space_end,1 ;clear bit to check if last input is space

; Configuring Timer 1 //////////////////////////////////////////////////////////////
	BANKSEL T1CON
	bsf     INTCON, PEIE        ; Enable Peripheral Interrupts
	bsf     INTCON, GIE         ; Enable Global Interrupt	
	MOVLW	b'00111001'		; TMR1 initialisation code
	MOVWF	T1CON			; Int clock, prescale128	
	MOVLW	b'10100011'		; MOVE VALUE TO LOWER TMR1 REGISTER
	MOVWF	TMR1L			; 
	MOVLW	b'11110100'		; MOVE VALUE TO LOWER TMR1 REGISTER
	MOVWF	TMR1H			; CLEAR OVERFLOW FLAG
	
BANKSEL PIE1            ;ENABLE TMR1 INTERRUPT FLAG
	BSF PIE1,TMR1IE

BANKSEL PIR1
BCF PIR1, TMR1IF ;clear TMR1 interrupt flag

;Start the timer:
BSF T1CON, TMR1ON ;set TMR1 on bit	
BCF PIR1, TMR1IF


	



main:
GOTO main

step_2:
MOVLW	0x01		; Clear Display
CALL	SendCommand		; and send code


MOVLW	0x80		; Move the cursor to beginning of First Line
CALL	SendCommand		; and send code

; *********************TODO: TEST FOR LESS THAN 5 CHARS???(SPACE CASE)
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar
movfW 0x20  
call PrintChar


movfW n1  
call PrintChar

movfW n2  
call PrintChar

movfW n3  
call PrintChar

movfW n4  
call PrintChar

movfW n5  
call PrintChar

MOVLW	0xC0	; begining of second line
CALL	SendCommand		; and send code


movfW n1  
call PrintChar

movfW n2  
call PrintChar

movfW n3  
call PrintChar

movfW n4  
call PrintChar

movfW n5  
call PrintChar


;**********TODO:: CREATE LOOPS FOR THIS AND FOR TEXT
; shift display to the left 
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code
MOVLW	0x18	
CALL	SendCommand		; and send code




runningPhaseLoop:
INCF runningPhaseCounter, 1

call DELAY

MOVLW	0x1C	; shift display to the right
CALL	SendCommand		; and send code

goto runningPhaseLoop


; ******************TODO***************
;		DELAY ONE SECOND


zeri:

goto zeri

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Main of the program



;////////////////////////////////////////////////////////
;You can use this delay for generating one sec delay
;Delay Function to generate a delay of 1s 
DELAY
MOVLW 0Xbd
MOVWF DCounter1
MOVLW 0X4b
MOVWF DCounter2
MOVLW 0X02
MOVWF DCounter3
LOOP
DECFSZ DCounter1, 1
GOTO LOOP
DECFSZ DCounter2, 1
GOTO LOOP
DECFSZ DCounter3, 1
GOTO LOOP
RETURN


;////////////////////////////////////////////////////////
DELAY2
; Load value for 2 seconds delay into W register
MOVLW 0xFF ; Load high byte of 2 seconds delay
MOVWF counter_high ; Move high byte to counter_high register
MOVLW 0xFF ; Load low byte of 2 seconds delay
MOVWF counter_low ; Move low byte to counter_low register
MOVLW 0x07 ; Load low byte of 2 seconds delay
MOVWF counter_mid ; Move low byte to counter_low register
; loop to decrement counter
delay_2s_loop
DECFSZ counter_high, F ; Decrement high byte, skip next instruction if zero
GOTO delay_2s_loop ; End of delay if high byte is zero
DECFSZ counter_low, F ; Decrement low byte, skip next instruction if zero
GOTO delay_2s_loop ; Repeat loop if low byte is not zero
RETURN ;


;////////////////////////////////////////////////////////
;This Function is just for prenting Charachter on the LCD
PrintChar
movwf Register1
swapf Register1
movf Register1, w
ANDLW 0x0f
movwf PORTA
BsF PORTA, 4 ; set character mode on RS
call pulseE
call onems
swapf Register1
movf Register1, w
ANDLW	0x0f
movwf PORTA
BsF PORTA, 4 
call pulseE
RETURN

;////////////////////////////////////////////////////////
;This function prints the charachter in the same position (overwrites on the same position)
Cursor
MOVLW	0x0C		; turn cursor off
CALL	SendCommand		; and send code
movf letter,w
call PrintChar
MOVLW	0x10		; 
CALL	SendCommand		; and send code
MOVLW	0x0E		; 
CALL	SendCommand		; and send code
;call increment_letter
RETURN


;////////////////////////////////////////////////////////
;This Function for Sending a Command to the Command Register in the LCD
SendCommand
movwf Register1
swapf Register1
movf Register1, w
ANDLW 0x0f
movwf PORTA
BcF PORTA, 4 ;Clearing the RS Register for command mode
call pulseE
;call onems
swapf Register1
movf Register1, w
ANDLW	0x0f
movwf PORTA
BcF PORTA, 4 ;Clearing the RS Register for command mode
call pulseE
RETURN






;////////////////////////////////////////////////////////
;This Function for generating one mellisecond of delay
onems	
MOVLW	D'249'		; Count for 1ms delay 
MOVWF	Timer1		; Load count
looping	NOP			; Pad for 4 cycle loop
		DECFSZ	Timer1		; Count
		GOTO	looping		; until Z
		RETURN			; and finish


;////////////////////////////////////////////////////////
;This function To generate an exact number of millisecons delay
xms	
MOVWF	TimerX		; Count for X ms
loopX	CALL	onems		; Delay 1ms
		DECFSZ	TimerX		; Repeat X times 
		GOTO	loopX		; until Z
		RETURN			; and finish


;////////////////////////////////////////////////////////
;This Function is to give a pulse for E pin just to latch the 
;Data to the LCD
pulseE	
BSF	PORTA, 5		; Set E high
CALL	onems		; Delay 1ms
BCF	PORTA,5		; Reset E low
;CALL	onems		; Delay 1ms
RETURN			; done


;////////////////////////////////////////////////////////
increment_letter
INCF letter, 1  ; Increment the contents of register 'A' by 1
;CALL check_if_Z
;CALL check_if_space
RETURN



;////////////////////////////////////////////////////////
increment_counter	
INCF DCount, 1  ; Increment the contents of register 'A' 
CALL check_if_counter_equal_5
RETURN

;////////////////////////////////////////////////////////
increment_index	
INCF index, 1  ; Increment the contents of register 'A' 
RETURN



;////////////////////////////////////////////////////////
return_index	
;set the index to the first index 
movlw n1 
movwf index 
RETURN


;////////////////////////////////////////////////////////
store_index	
; Load the address of the memory location into the FSR register
MOVF index, W
MOVWF FSR



; Load the value to be stored into the WREG register
MOVFW letter


; Store the value in the memory location
MOVWF INDF

return
;///////////////////////////////////////////////////////
check_if_counter_equal_5
MOVfw DCount
SUBLW d'5' ; Subtract the value of w from 5
;SUBLW 0x43
BTFSS STATUS, Z ; Test the zero flag in the STATUS register
return

;disable the timer ISR
BANKSEL PIE1            ;DISABLE TMR1 INTERRUPT FLAG
BCF PIE1,TMR1IE
;SELECT BANK 0
BCF STATUS, RP0 ;Bank0 
BCF STATUS, RP1 ;  
CALL return_index 

GOTO step_2
 
; if count is 5 go to next line

;////////////////////////////////////////////////////////
check_if_Z
; Check if w is equal to the ASCII code for the letter after Z to print space after it(0x5b)
MOVfw letter
;SUBLW 0x5b ; Subtract the value of w from 0x5b
SUBLW 0x45

BTFSS STATUS, Z ; Test the zero flag in the STATUS register
return
;Sending DATA "Enter Operation" Message 
;BCF STATUS, Z
movlw 0x20
movwf letter
return

;////////////////////////////////////////////////////////
check_if_space:
;Sending DATA "Enter Operation" Message 
bcf check_space_end,0
MOVfw letter
SUBLW 0x21 ; Subtract the value of w from 0x21
BTFSS STATUS, Z ; Test the zero flag in the STATUS register
return
;BCF STATUS, Z
bsf check_space_end,0
movlw 0x41
movwf letter

return

;//////////////////////////////////////////////////////
check_if_space_end:
;Sending DATA "Enter Operation" Message 
MOVfw letter
SUBLW 0x21 ; Subtract the value of w from 0x21
BTFSS STATUS, Z ; Test the zero flag in the STATUS register
return
;disable the timer ISR
BANKSEL PIE1            ;DISABLE TMR1 INTERRUPT FLAG
BCF PIE1,TMR1IE
BCF STATUS, RP0 ;
BCF STATUS, RP1 ; Bank0
CALL return_index
GOTO step_2


TestIF3
BTFSs CounterHundred, 0
return
BTfSs CounterHundred, 1
return
movlw 0x00
movwf CounterHundred
return 


			END                   	; Terminate source code......







 


;In this example, Timer0 is configured to use a pre-scaler value of 256,
;and the Timer0 register is loaded with the value 0xB1 to generate an interrupt every 2 seconds based on a
;4 MHz crystal frequency. The RB0/INT pin is configured as an external interrupt that triggers on the falling edge, 
;and a pull-up resistor is enabled on the pin. The INTCON register is used to enable global interrupts and both the Timer0 and RB0/INT interrupts.
;The ISRs for both interrupts are defined at the beginning of the code and handle the interrupt code for each interrupt. 
;The main program is an infinite loop that continuously executes.
;In this code, the ISR first checks the T0IF flag to determine the source of the interrupt
;If T0IF is set, it means a Timer0 interrupt occurred, and the appropriate ISR for Timer0
;is executed. If T0IF is not set, it means a RB0/INT interrupt occurred, and the appropriate ISR for RB0/INT
;is executed. The ISRs for each interrupt clear the corresponding interrupt flag, and return from the
;interrupt using the retfie instruction



