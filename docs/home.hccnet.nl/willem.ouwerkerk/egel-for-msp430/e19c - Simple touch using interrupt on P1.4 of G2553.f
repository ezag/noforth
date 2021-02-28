(*  e19c - For noForth C&V 200202ff on G2553: bit output & capacitive touch using timer-A0
  on MSP430G2553 using port-1. More info, see page 369ff of SLAU144J.PDF
  Selecting the pin function see SLAS735J page 42ff.
  CapTouch switch controlling LEDS. Use the timer count up function with INCLK input.

  Basic process: reset counter of TA0, wait a short while, read count register.
  The count gives an indication of whether the switch is touched.
  The watchdog interval timer interrupt is used to sample Timer-A0

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

*)

hex
value REF       \ Remember the base of an untouched capkey
value SENSOR    \ Hold CapTouch sensor data
value MS)       \ Decreases 976 times each second
\ Clock = 8000000/8192 longest interval 67,10 sec. usable as MS
: READY       ( -- )    5A11 120 ! ;   \ WDTCTL
: >MS         ( u -- )  5A19 120 !  to ms) ;   \ WDTCTL
code INT-ON   ( -- )    D232 ,  next  end-code
\ code INT-ON   ( -- )    #8 sr bis  next  end-code

\ Sample TA0 for touch sensor & decrease MS) until it's zero
routine TOUCH-MS ( -- a )
    4292 ,  170 ,  adr sensor ,
    40B2 ,  324 ,  160 ,
    9382 ,  adr ms) ,  2402 ,
    53B2 ,  adr ms) ,  1300 ,
end-code
\ routine TOUCH-MS ( -- a )
\    170 & adr sensor & mov      \ TA0R    Read timer A0 contents to value
\    324 # 160 & mov             \ TA0CTL  Restart timer-A0 from zero
\    #0 adr ms) & cmp            \         Perform MS
\    <>? if,  #-1 adr ms) & add  then,
\    reti
\ end-code

\ An MS routine using the Watchdog interval mode
: MS          ( u -- )  >ms  begin  ms) 0= until  ready ;
touch-ms    FFF4 vec!   \ Install watchdog interrupt vector


\ Drift compensation on negative or 'small' postive numbers only ( +1 to +border )
: ADAPT     ( diff -- )     \ Drift compensation & switch treshold calculation
    dup 1 8 within +to ref  \ Difference positive, decrease REF
    0< abs +to ref ;        \ Difference negative, increase REF

: GREEN       ( -- )      40 21 *bis  1 21 *bic ;  \ P1OUT G2553 Launchpad LEDs on P1.0 & P1.6
: RED         ( -- )      1 21 *bis  40 21 *bic ;  \ P1OUT
: LEDS-OFF    ( -- )      41 21 *bic ;             \ P1OUT
: INIT-LEDS   ( -- )      41 22 *bis ;             \ P1DIR

: .DEC      ( u -- )        decimal  4 .r  space  hex ;
: TOUCH@    ( -- n )        ref sensor - ;
: TOUCH?    ( -- f )        touch@  dup adapt  07 > ; \ Leave true when sensor is touched
: ?LED      ( f -- )        if  green  else  red  then ; \ Switches green on when true, otherwise red

\ 10 26 *bic  10 41 *bis = P1.4 as capacitive touch input
: TOUCH-ON      ( -- )
    F0 26 *bic  F0 41 *bic  \ P1SELx   Disable all CapKey inputs
    10 41 *bis              \ P1SELx   Enable P1.4 pin osc. only
    ready  1 0 *bis  int-on \ Activate interval interrupt
    init-leds  leds-off     \ P1DIR    Set pins with LED1,2 to output
    324 160 !               \ TA0CTL   Set timer mode to INCLK/1. count up & ints off
    5 ms  sensor  to ref ;  \ Store reference measurement

\ Print: REFerence  Count  Difference ...
: .TOUCH        ( -- )      \ Show CapKey sensor data
    cr ref dup .dec         \ Show REFerence &
    sensor dup .dec  - .dec \ current measurement & difference
    touch? dup if  ."  On"  then  ?led ;

\ This routine shows the inner working of the ADAPTation routine
\ Shows ref, capture counter and drift adjusting for a while
: SHOW      ( -- )
    touch-on  begin  .touch  40 ms  key? until  leds-off ;

: TOUCH     ( -- )          \ Control two leds by capacitive touch
    touch-on  begin  touch? ?led  40 ms  key? until  leds-off ;

' show  to app
shield TOUCH\  freeze

\ end

