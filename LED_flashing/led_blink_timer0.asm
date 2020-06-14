; led_blink_timer0.asm
; Ogureckiy Dmitriy May 2019
;
; PIC12F510 Assembler program, MPLAB v5.15 IDE and mpasm(v5.82) used to build.
;	    debugging was done in the Proteus 8 Professional
; ********************************************************
; ************ LED flashing ******************************
; ********************************************************
;
;---------------------------------------------------------------------
;    Copyright (C) 2019 Ogureckiy Dmitriy 
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <https://www.gnu.org/licenses/>.
;---------------------------------------------------------------------
;
; FUNCTIONS
; =========
; pressing the button selects one of the following modes:
; 1/ led is off
; 2/ led is on
; 3/ LED flashes at 1 Hz
;
; COMMENTS
; =========
; all delays are implemented using a timer0.	    
; PINOUT
; ======
;                   ____  ____
;                  |    \/    |   
;            Vcc --| 1      8 |-- GND
;                  |          |
;   led (out)    --| 2      7 |-- 
;                  |          |
;		 --| 3      6 |-- 
;                  |          |
;  button (in)   --| 4      5 |-- 
;                  |__________|
;
;             Pin | Function    | PIC Name
;            -----|-------------|---------
;              2  | led (out)   |  GP5 (05)
;              4  | button (in) |  GP3 (03)
	    

#include <p12f510.inc>
__config _IntRC_OSC & _CP_OFF & _WDT_OFF & _MCLRE_OFF & _IOSCFS_ON

; VARIABLES ---------------------------------------------------------------------	    
udata
COUNT_PRESS res 1		      ;number of button presses			            	|adress=10
COUNT_TMR0  res 1		      ;number of counts, where 1 count corresponds to 16 ms	|adress=11
COUNT_TMR0_PRESS  res 1		      ;number of counts at the time of pressing the button	|adress=12
var res 1			      ;auxiliary variable					|adress=13    
flags res 1			      ;descriptions below			         	|adress=14
COUNT_TMR0_LAST_CHANGE_LED_STATE res 1;number of counts at the time of last led switch          |adress=15
;bits |7|6|5|4|3|2|1|0|
; 0 - COUNT_SEC - determines what value to take in the next pass in order to total 1 sec (0-62,1-63)
; 1 - BUTTON_STATE - current button state  (1-pressed, 0 - not pressed )
; 2 - CHANGE_BUTTON_STATE - button state change (high to low) (1-changed,0-don't changed)
;CONSTANTS ---------------------------------------------------------------------	    
COUNT_SEC1   equ d'62';number of counts for led flashing, corresponds to 62*16=992ms
COUNT_SEC2   equ d'63';number of counts for led flashing, corresponds to 63*16=1008ms (total give 2sec)
COUNT_BOUNCE equ d'3' ;number of counts for Debouncing, corresponds to 3*16=48ms
; START PROGRAM ----------------------------------------------------------------
res_vect  code    0x0000
	    goto    setup_state
main_prog code	    
 
setup_state	    
	    clrf	GPIO
	    movlw	b'11011111' ;GP5-output
	    tris	GPIO
	    ;Initializing Variables
	    clrf	TMR0
	    clrf	COUNT_PRESS
	    clrf	COUNT_TMR0
	    clrf        COUNT_TMR0_PRESS
	    clrf	var
	    clrf	flags
	    clrf	COUNT_TMR0_LAST_CHANGE_LED_STATE
	    
	    movlw b'10010111' ; timer0 selected  
	    option		
	    ; freq at 8/4 MHz =2MHz   with a prescaler 256 - 7812.5Hz - T=128μs - 7.8125*T per 1ms
	    ; 7.8125*16*T = 125*T at 16ms, 1sec = 62.5 count (62 and 63)
	    
main	
	    btfss GPIO,GP3 
	    goto button_on
	    call button_off
	    goto no_press	  	    

    press	
		;Debouncing
		movlw	    b'00000010'
		andwf	    flags,w 
		btfsc	    STATUS,Z	;z=1 flag is omitted (button is off)
		goto	    write_time_press	; record the time the button is pressed, if z = 1
		goto	    dont_write_time_press
	        write_time_press
		movf	    COUNT_TMR0,w
		movwf       COUNT_TMR0_PRESS 
		movlw	    b'00000010' 
		addwf	    flags,f ;raise the flag BUTTON_STATE=1
		dont_write_time_press
		
		
		movf	    COUNT_TMR0,w
		movwf	    var
		movf        COUNT_TMR0_PRESS,w
		subwf       var,w	   ;w=COUNT_TMR0-COUNT_TMR0_PRESS
		subwf	    COUNT_BOUNCE,w ;W=COUNT_TMR0-COUNT_TMR0_PRESS>=COUNT_BOUNCE
		btfsc	    STATUS,C
		goto	    press_true
		goto	    no_press
    press_true 	  
		movlw	    b'00000100' 
		addwf	    flags,f ;raise the flag CHANGE_BUTTON_STATE=1
    
		incf	    COUNT_PRESS,f
		movlw       d'03'
		XORWF       COUNT_PRESS,w
		btfsc	    STATUS,Z
		clrf	    COUNT_PRESS	
    no_press        
		
		movlw       d'00'
		    XORWF       COUNT_PRESS,w
		    btfsc	STATUS,Z
		    bcf		GPIO,GP5
		movlw       d'01'
		    XORWF       COUNT_PRESS,w
		    btfsc	STATUS,Z
		    bsf		GPIO,GP5
		movlw       d'02'
		    XORWF       COUNT_PRESS,w
		    btfsc	STATUS,Z
		    call	blinking
		    
	    movlw	    d'125'
	    subwf	    TMR0,w
	    btfsc	    STATUS,C
	    clrf	    TMR0
	    btfsc	    STATUS,C
	    incf	    COUNT_TMR0  ;+125 count of clock (16 мс)    
	    	    		    
goto main
	
	    
button_on
	    movlw	    d'4' ; CHANGE_BUTTON_STATE flag check
	    andwf	    flags,w 
	    btfsc	    STATUS,Z	;z=1 flag is omitted (don't changed)
	    goto	    press	;run if z=1 (don't changed)
	    goto	    no_press
	    
button_off
	    movlw	    b'11111101' 
	    andwf	    flags,f ;let the flag down BUTTON_STATE=0
	    movlw	    b'11111011' 
	    andwf	    flags,f ;let the flag down CHANGE_BUTTON_STATE=0
	    retlw b'0'
	    
change_state_led
	    movlw b'00100000'
	    xorwf GPIO, f   ;change state led
	    
	    movf	    COUNT_TMR0,w
	    movwf           COUNT_TMR0_LAST_CHANGE_LED_STATE ;COUNT_TMR0_LAST_CHANGE_LED_STATE=COUNT_TMR0
	    
	    movlw	    b'00000001' 
	    xorwf	    flags, f  ;change COUNT_SEC bit in flags variable
	    
	    retlw b'0'
	    
	    
blinking
	    movf	    COUNT_TMR0,w
	    movwf	    var

	    movf	    COUNT_TMR0_LAST_CHANGE_LED_STATE,w
	    subwf	    var,f	   ;var=COUNT_TMR0-COUNT_TMR0_LAST_CHANGE_LED_STATE
	    
	    movlw	    d'1'
	    andwf	    flags,w 
	    btfsc	    STATUS,Z   
	    movlw	    COUNT_SEC1
	    movlw	    COUNT_SEC2 ;w=COUNT_SEC1(if COUNT_SEC=0),w=COUNT_SEC1(if COUNT_SEC=1)
	    
	    subwf	    var,f          ;var=COUNT_TMR0-COUNT_TMR0_LAST_CHANGE_LED_STATE-w  
	    btfsc	    STATUS,C       ;W=COUNT_TMR0-COUNT_TMR0_LAST_CHANGE_LED_STATE>=w ?
	    call	    change_state_led	
	    retlw b'0'
	    
            end