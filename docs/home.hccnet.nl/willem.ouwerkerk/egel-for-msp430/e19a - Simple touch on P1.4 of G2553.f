(* E19a - For noForth C&V 200202: bit output & capacitive touch using timer-A0
  on MSP430G2553 using port-1. More info, see page 369ff of SLAU144J.PDF
  Selecting the pin function see SLAS735J page 42ff.
  CapTouch switch controlling LEDS. Use the timer count up function with INCLK input.

  Basic process: reset counter of TA0, wait a short while, read count register.
  The count gives an indication of whether the switch is touched.
  No interrupts are used!

  Forth words are: TOUCH?  TOUCH-ON  SHOW  TOUCH

  Register addresses for Timer-A
    160 - TA0CTL   Timer A0 control
    170 - TAR0     Timer A0 counter

  Bits in TA0CTL with INCLK
    004 - TACLR      \ Reset TAR register {bit2}
    020 - MC-1       \ Timer counts to FFFF {bit4,5}
    000 - ID-3       \ Input divider /1 {bit =6,7}
    300 - TASSEL-2   \ INCLK as clock source {bit8,9}

  Setup for timer A0 captive touch counter
      3 = inclk
      2 = inclk/1 count up to FFFF
      0 = no interrupts

     21 - P1OUT      \ Output reg.
     22 - P1DIR      \ Direction reg.
     26 - P1SEL      \ Selection register
     41 - P1SEL2     \ Selection register 2

Select captive touch on port-1, P1SEL = 0, P1SEL2 = 1

https://youtu.be/BnzMyqOsCzo

 *)

hex
: GREEN       ( -- )      40 21 *bis  1 21 *bic ;  \ P1OUT G2553 Launchpad LEDs on P1.0 & P1.6
: RED         ( -- )      1 21 *bis  40 21 *bic ;  \ P1OUT
: LEDS-OFF    ( -- )      41 21 *bic ;             \ P1OUT
: INIT-LEDS   ( -- )      41 22 *bis ;             \ P1DIR

\ TA counter setup: 3 = inclk is clock source, 2 = continuous up mode, 4 = clear timer
: SENSOR@       ( -- u )
    324 160 !  ( TA0CTL )  1 ms  170 @  ( TA0CNT ) ;

value REF                   \ Remember the base of an untouched capkey
\ 10 26 *bic  10 41 *bis = P1.4 as capacitive touch input
: TOUCH-ON      ( -- )
    init-leds  leds-off     \ P1DIR    Set pins with LED1,2 to output
    320 160 !               \ TA0CTL   Set timer mode to INCLK/2. count up & ints off
    10 26 *bic  10 41 *bis  \ P1SELx   Enable P1.4 pin osc.
    sensor@  to ref ;       \ do reference measurement

\ Drift compensation on negative or 'small' postive numbers only
: ADAPT     ( cnt -- )      \ Drift compensation & switch treshold calculation
    ref swap -              \ Calculate difference
    dup 1 8 within +to ref  \ Difference positive, decrease REF
    0< abs +to ref ;        \ Difference negative, increase REF

: .DEC      ( u -- )        decimal  4 .r  space  hex ;
: TOUCH@    ( -- cnt )      sensor@  dup adapt ; \ Do one Capacitive Touch measurement
: TOUCH?    ( -- f )        ref touch@ - 7 > ;   \ Difference of REF > 7
: ?LED      ( f -- )        if  green  else  red  then ; \ Switches red on when true, otherwise green

: .TOUCH        ( -- )      \ Show CapKey sensor data
    cr ref dup .dec  touch@ \ Show REF & read current measurement
    dup .dec  space - dup .dec \ Show measurement & difference
    7 > if  ."  On "  then ;

\ This routine shows the inner working of the read-cap routine
\ Shows ref, capture counter, border and drift adjusting for a while
: SHOW      ( -- )
     touch-on  begin  .touch  touch? ?led  80 ms  key? until  leds-off ;

: TOUCH     ( -- )          \ Control two leds by capacitive touch
     touch-on  begin  touch? ?led  40 ms  key? until  leds-off ;

' show  to app
shield TOUCH\  freeze

\ End ;;;
