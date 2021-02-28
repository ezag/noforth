(*  e80d - For noForth c&v 59xx v 200202ff, capacitive touch example using 
  the watchdog as .5 ms interval interrupt on MSP430FR59xx. This routine
  samples timer A3, CapTouch oscillates with the switch as capacitor. 
  TA3 counts with that frequency.
  
  Basic process: reset counter of TA3, wait a short while, read count register
  the count gives an indication of whether the switch is touched
  no interrupts are used

  Register address for 59xx: timer A3 - base address = 0x440
  timerA3 is exclusively internal Timer

    0x440 - TA3CTL          \ TA3 control
    0x442 - TA3CCTL0        \ Capture/compare control 0
    0x444 - TA3CCTL1        \ Capture/compare control 1
    0x450 - TA3R            \ TA3 counter
    0x452 - TA3CCR0         \ Capture/compare 0
    0x454 - TA3CCR10        \ Capture/compare 1
    0x460 - TA3EX0          \ TA3 expansion 0
    0x46E - TA3IV           \ TA3 interrupt vector

    Internal clock, continuous count, no interrupts or division
    Bits TA3CTL: 0000 0011 0010 0000 -> 0x0320
    Setting bit 2 resets the TAR=clock counter

    CapTouchIO0: base address 59xx: 0x43E - for TA2
    CapTouchIO1: base address 59xx: 0x47E - for TA3

  CAPTIO0CTL for                                    Pin P1.4    Pin P3.6

    Bit 0       = 0 - NC                            = 000        000
    Bit 1 to 3  = 000 to 111 = Px.0 to Px.7         = 008 (100)  00C (110)
    Bit 4 to 7  = 0000 = PJ, 0001 = P1, etc.        = 010 (001)  030 (011)
    Bit 8       = Capacitive touch on/off. 1 = on   = 100        100
---------------------------------------------------------------------
    Initialisation for choosen pin                  = 0x118    = 0x13C

*)

hex
\ : 5994: ; immediate   : 59x9: postpone \ ; immediate  \ Select this line for the MSP430FR5994
  : 59x9: ; immediate   : 5994: postpone \ ; immediate  \ Select this line for the MSP430FR59x9

value MS)   \ Decreases 976 times each second
code INT-ON   ( -- )    #1 xx mov  #0 yy mov  #8 sr bis  next  end-code

\ Clock = 8000000/8192 longest interval 67,10 sec. usable as MS
\ Decrease MS) until it's zero
\ TA3 counter setup: 3 = inclk is clock source, 2 = continuous up mode, 4 = clear timer
routine MSTIMER  ( -- addr )
    #-1 xx add  0=? if,                 \ One MS passed?
        #0 yy cmp  =? if,               \ Sample flag zero?
            324 # 440 & mov  #-1 yy mov \ TA3CTL  Yes, restart timer A3 from zero
        else,
            450 & zz mov  #0 yy mov     \ TA3R    No, read timer A3 contents
        then,
        #2 xx mov   #0 adr ms) & cmp    \ Handle normal MS routine
        <>? if,  #-1 adr ms) & add  then,
    then,
    reti
end-code

: >MS       ( u -- )    to ms)  5A1D 15C ! ;    \ (Re)start MS timer
: MS        ( u -- )    >ms  begin  ms) 0= until ;
mstimer   FFF2 vec!     \ Install watchdog interrupt vector

: H.        ( u -- )    0 <# # # # #> type space ;

value REF                   \ Remember the base of an untouched capkey
value BORDER                \ Switch border
\ Drift compensation on negative or 'small' postive numbers only ( +1 to +border )
: ADAPT     ( cnt -- )      \ Drift compensation & switch treshold calculation
    ref swap - >r           \ ref - cnt = diff
    r@ 1 < if               \ Difference smaller then 1?
        r> 0< abs +to ref exit \ Yes, increase REFerence when negative, ready
    then
    r@ border < +to ref     \ Difference between 1 & border, decrease ref
    r@ 10 > if              \ Difference greater then 10?
        r@ 3 / to border    \ Yes, adjust switch treshold to 30% (slaa574.pdf page 12)
    then  rdrop ;

5994: : GREEN       ( -- )      2 202 *bis  1 202 *bic ; \ P1OUT 5994 Launchpad LEDs on P1.0 & P1.1
5994: : RED         ( -- )      1 202 *bis  2 202 *bic ; \ P1OUT
5994: : LEDS-OFF    ( -- )      3 202 *bic ;             \ P1OUT
5994: : INIT-LEDS   ( -- )      3 204 *bis ;             \ P1DIR

59x9: : GREEN       ( -- )      1 202 *bis 40 223 *bic ; \ P1OUT P4OUT 5969 Launchpad Leds on P1.0 & P4.6
59x9: : RED         ( -- )      40 223 *bis 1 202 *bic ; \ P4OUT P1OUT
59x9: : LEDS-OFF    ( -- )      1 202 *bic 40 223 *bic ; \ P1OUT P4OUT
59x9: : INIT-LEDS   ( -- )      1 204 *bis 40 225 *bis ; \ P1DIR P4DIR

code SENSOR@      ( -- cnt ) \ Read touch sensor
    tos sp -) mov
    zz tos mov  next
end-code

: TOUCH@    ( -- cnt )      sensor@  dup adapt ; \ Do one Capacitive Touch measurement
: TOUCH?    ( -- f )        ref touch@ -  border > ; \ Leave true when sensor is touched (greater than border)
: ?LED      ( f -- )        if  red  else  green  then ; \ Switches red on when true, otherwise green

\ 1 = capacitive touch enabled, 1 = P1 enabled, 8 = P1.4
: INIT-TOUCH ( -- )         \ Initialise hardware and value
    5A15 15C !  1 100 *bis  int-on   \ SFR1  Activate MS
    init-leds   leds-off    \ P3DIR       init. led i/o
    118 47E !               \ CAPTIO1CTL  captouch activate P1.4
    320 440 !               \ TA3CTL      timer a3 internal clock, continuous
    4 to border   5 ms      \             count, no interrupts or division 
    sensor@  to ref ;       \ do reference measurement

\ Print: REFerence  Count  BORDER  Difference
: .TOUCH        ( -- )      \ Show CapKey sensor data
    cr ref dup h.  touch@ dup h.  \ Show REF & current measurement
    space border h.  space - h. ; \ Show border & difference

\ This routine shows the inner working of the ADAPTation routine
\ Shows ref, capture counter, border and drift adjusting for a while
: SHOW      ( -- )
    init-touch  begin  .touch  touch? ?led  40 ms  key? until  leds-off ;

: TOUCH     ( -- )          \ Control two leds by capacitive touch
    init-touch  begin  touch? ?led  40 ms  key? until  leds-off ;

' show  to app
shield TOUCH\  freeze

\ end

