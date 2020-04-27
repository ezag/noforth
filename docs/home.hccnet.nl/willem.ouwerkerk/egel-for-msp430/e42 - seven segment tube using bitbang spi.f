(* E42 - For noForth C&V2553 lp.0, bitbang SPI on MSP430G2553 using port-2.
   The program uses a compare timer interrupt with machine code.
   Control of seven segment display's using a display module with 74HC595.
   It takes 4x39=156us every 12388us to fill the tube display = 1,26% cpu time.

  Connect a 74HC595 display module, pin-1 to VCC, pin-2 to P2.2{SCLK}, 
  pin-3 to P2.0 {RCLK}, pin-4 to P2.1 {DIO} and  pin-5 to ground! all 
  outputs are connected to a 7-segm. display module. See schematic.
  On the HC595: OE\ = low, when OE\ is high the outputs are disabled.
                MR = high, when MR=low the shift register is reset.
  		        DS is data input, SHCP is clock input, STCP is strobe
                and acts on a positive transition.

Hexadecimal codes for the display:
0	   1	  2	     3	    4	   5	  6	     7	    8	   9	  A	     
0xC0,  0xF9,  0xA4,  0xB0,  0x99,  0x92,  0x82,  0xF8,  0x80,  0x90,  0x88,  

b	   c	  d	     E	    F	   -	  .	     off
0x83,  0xA7,  0xA1,  0x86,  0x8E,  0xbf,  0x7F,  0xFF

  Register addresses for Timer-A, P1 & P2
  0160 = TA0CTL    - Timer A control
  0162 = TA0CCTL0  - Timer A Comp/Capt. control 0
  0172 = TACCR0    - Timer A Compare register
  0029 = P2OUT     - Port-2 output register
  002A = P2DIR     - Port-2 direction register
  0020 = P1IN      - Input register
  0021 = P1OUT     - Output register
  0022 = P1DIR     - Direction register
  0026 = P1SEL     - 0C0
  0027 = P1REN     - Resistance on/off
  0041 = P1SEL2    - 0C0
  0029 = P2OUT     - port-2 output with 8 leds
  002A = P2DIR     - port-2 direction register
  002E = P2SEL     - port-2 selection register 

  The first digit send is the character code, the second digit selects 
  one of four displays. A zero means that a led in the display is on!
  The digits are selected  with the lower four bits and 
  are active high. One is the most left digit, Eight the most left!
  Needs a buffer and timer interrupt to display a whole number.
  User words: COUNTER  TU.  TCLR  TDASH  TMESSAGE
 *)

hex
create DIGITS  4 allot  \ Hold number for tube display
value SEGM              \ Segment pointer
value PTR				\ Digit pointer

routine >SPI    ( -- adr )
	#8 zz mov
	begin,
		sun sun .b add  \ Get highest bit
		cs? if,         \ High?
            #2 29 & .b bis \ P2OUT  P2.1  Yes
        else, 
            #2 29 & .b bic \ P2OUT  P2.1  No
        then,
		#4 29 & .b bis  \ P2OUT  P2.2  Clock
        #4 29 & .b bic  \ P2OUT
        #-1 zz add      \ Decrease bit counter
	=? until,           \ Zero?
	rp )+ pc mov        \ Ready
end-code

\ Display data from the array digits on 4-digit tube display
\ This interrupt has to be triggered 100 to 200 times each second!!
routine TUBE    ( -- adr )
    sun push            \ Save Forth registers
    day push
    adr segm & day mov  \ Contents of segm
    digits # yy mov     \ Addr of number array
    4 # xx cmp          \ All numbers done?
    =? if,              \ Yes,
        #0 xx mov       \ restart digit pointer
        #8 day mov      \ and display selector
    then,
    xx yy add           \ Yes, add pointer
    yy ) sun .b mov     \ Read bitmap
	>spi # call         \ Send bitmap
	day sun .b mov      \ Get segment
    >spi # call         \ Select display
	#1 29 & .b bis      \ P2OUT  P2.0  Display one digit
    #1 29 & .b bic      \ P2OUT
    day .b rrc          \ To next digit
    #1 xx add           \ To next digit
\   #1 21 & xor>        \ P1OUT  Toggle P1.0 for debug
    day adr segm & mov  \ Save display selector
    rp )+ day mov       \ Restore Forth registers
    rp )+ sun mov
    reti
end-code

code TUBE-ON)   ( -- )  #0 xx mov  #8 sr bis next  end-code
code TUBE-OFF   ( -- )  010 # 162 & bic  #8 sr bic next  end-code \ TA0CCTL0

\ Set timer compare interrupt on with SMCLK, the interval in TACCR0
: TUBE-ON       ( -- )
    tube-off            \ Interrupts off
    07 02A *bis         \ P2DIR    Set pins with 0,1,2 to output
    04 029 *bic         \ P2OUT    Start with clock low
    0214 0160 !         \ TA0CTL   Set timer mode SMCLK/1
    2000 0172 !         \ TACCR0   Every 1.0 ms a char ~200 Hz
    010 0162 **bis      \ TA0CCTL0 Enable interrupts on Compare 0
    1 to segm           \ Init. segment pointer
    8 to ptr  tube-on)  \ Init. conversion pointer
    digits 4 FF fill ;  \ Blank display

\ Numbers for a 7-segment display using 74HC595 0 t/m F, dash and dot
\ Layout of 7-segm. Display  +-01-+
\                            20  02
\ Driver 74HC595             +-40-+
\                            10  04
\ Dec. dot is 80 !!          +-08-+
CREATE NUMBERS  ( Building characters )
  bn 11000000 c, bn 11111001 c, bn 10100100 c, bn 10110000 c, ( 0, 1, 2, 3 )
  bn 10011001 c, bn 10010010 c, bn 10000010 c, bn 11111000 c, ( 4, 5, 6, 7 )
  bn 10000000 c, bn 10010000 c, bn 10001000 c, bn 10000011 c, ( 8, 9, A, b )
  bn 11000110 c, bn 10100001 c, bn 10000110 c, bn 10001110 C, ( C, d, E, F )
  bn 10111111 c, bn 01111111 c, bn 11111111 c,  align         ( -, ., and off )

: TRANSLATE     ( x -- b )  \ Send number u to digits
    12 umin numbers + c@ ;  \ From binary to 7-segment

: >TUBE)		( c -- +n )
	dup bl = if  drop 12 exit  then
	dup ch . = if  drop 11 exit  then
	dup ch - = if  drop 10 exit  then
	ch 0 -  dup 09 > if 7 - then ;

: >TUBE	        ( c -- )        >tube) translate  ptr digits + c! ;
: HOME          ( -- )          0 to ptr ;
: TEMIT	        ( c -- )        >tube  ptr 3 < if  incr ptr  then ;
: TTYPE         ( a u -- )      bounds ?do  i c@ temit  loop ;
: TSPACES		( u -- )        0 ?do  bl temit  loop ;
: RTTYPE		( a n r -- )    home  2dup min - tspaces  ttype ;
: TU.           ( x -- )        0 du.str  4 rttype ;
: TDASH	        ( -- )          s" ----" home ttype ;
: TMESSAGE      ( -- )          s"  -F-" home ttype ;
: TCLR          ( -- )          home 4 tspaces ;

: COUNTER       ( -- )
    tube-on  tdash 100 ms  tmessage 100 ms  0
    begin  dup tu.  1+  50 ms  key? until  drop  tclr ;

tube  FFF2 vec! \ Set Timer-A0 vector
shield tube\  freeze

\ End 
