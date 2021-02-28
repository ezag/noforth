(* e19b - For noForth c&v G2553 v 200202ff bit output & capacitive touch using timer-A0
  on MSP430G2553 using port-1. More info, see page 369ff of SLAU144J.PDF
  Selecting the pin function see SLAS735J page 42ff.
  Multiple Capacitive Touch switched & slider controlling LEDS and
  or a mosfet power driver. Use the timer count up function with INCLK input.

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

https://youtu.be/YCwsUXKWx9I 

*)

hex
: GREEN       ( -- )    40 21 *bis  1 21 *bic ; \ P1OUT G2553 Launchpad LEDs on P1.0 & P1.6
: RED         ( -- )    1 21 *bis  40 21 *bic ; \ P1OUT
: LEDS-OFF    ( -- )    41 21 *bic ;            \ P1OUT
: INIT-LEDS   ( -- )    41 22 *bis ;            \ P1DIR
: INIT-PWM    ( -- )    10 2E *bis 10 2A *bis ; \ P2SEL, P2DIR  Set PWM to output pin P2.4

value PAD1  value PAD2      \ Hold two input-bit numbers
create REFS 4 cells allot   \ Remember the base of 4 untouched pads
value BORDER                \ Slider border

\ Calculate reference addres of current input-bit
: REF       ( nr -- a )     3 and  2*  refs + ;

: SELECT-INPUT ( bit -- )   \ Select 'bit' as active captive touch input
    dup 8 4 within ?abort   \ Warn when invalid I/O-bit
    1 swap lshift           \ Convert bitnr to bit-mask
    41 c@ F and  or 41 c! ; \ P1SEL2  Select capacitive touch input

\ TA0 counter used for capacitive touch
\ 3 = Inclk is clock source, 2 = Continuous up mode, 4 = Clear timer
: MEASURE   ( bit -- cnt )  \ Do Capacitive Touch measurement
    select-input  324 160 ! ( TA0CTL )  1 ms  170 ( TA0R ) @ ;

: ADAPT     ( cnt bit -- )  \ Drift correction on 'bit'
    >r  r@ ref @ - dup if   \ Count <> reference?
        0< -2 and 1+        \ Convert flag to -1 or 1
    then  r> ref +! ;       \ Correct reference with 0, 1 or -1

\ Initialise Capacitive touch 
\ 3 = Inclk is clock source, 2 = Continuous up mode, 0 = Stop timer
: INIT-TOUCH ( -- )         \ Initialise hardware and value
    init-leds   leds-off    \             Init. led I/O
    F0 26 *bic  F0 41 *bic  \ P1SELx  P1.4 to P1.7 as cap. touch
    320 160 !               \ TA0CTL      Timer A0 stopped
    8 4 do  i measure       \ Do 4 reference measurements on P1
            i ref !  loop ;

\ Touch switch primitives
: READ?     ( bit -- cnt f )    \ Read input 'bit' using drift correction
    >r r@ measure               \ Get count of bitnr            cnt
    r@ ref @  over -            \ REF - cnt = diff              cnt diff
    10 > if                     \ Difference greater then 10?   cnt
        rdrop  true  exit       \ Yes, ready                    cnt true
    then
    dup r> ADAPT  false ;     \ Do drift correction           cnt false

: TOUCH?    ( bitnr -- f )      read? nip ;


\ Capacitive switch touch demos
: ?LED      ( f -- )    if green else red then ;    \ Switches red on when true, otherwise green
: .DEC      ( n -- )    decimal  5 .r  space  hex ; \ Print small decimals in fixed format

\ This routine shows the inner working of the touch switch routine
\ Shows REF, capture counter and drift adjusting for a while
: .TOUCH    ( bit -- )
    to pad1  init-touch
    begin
        cr pad1 ref @ dup .dec      \ Show reference,
        pad1 read? drop  dup .dec   \ Show measurement
        space -  dup .dec           \ Show difference
        10 > dup ?led  space        \ Toggle leds too
        if ." On " else ." Off"  then  80 ms \ Show switch function too
    key? until ;

: TOUCH     ( bit -- )  \ Control both leds by capacitive touch input 'bitnr'
    init-touch  begin  dup touch? ?led  40 ms  key? until  drop ;

: TOUCH2    ( bit0 bit1 -- )    \ Toggle both leds separately using P1.x & P1.y
    to pad2  to pad1  init-touch
    begin
        pad1 touch? if  red    then
        pad2 touch? if  green  then
        begin  pad1 touch?  pad2 touch?  or 0= until  40 ms \ Touch released? 
    key? until
    leds-off ;

: TOUCHTWO  ( -- )      4 5 touch2 ; \ Toggle both leds separately using P1.4 & P1.5


\ Slider implementation with one timer only!
: SETBORDER ( -- )      \ Set slider activation at .75 % of reference
    pad1 ref @  pad2 ref @ +    \ Add reference values
    3 dm 400 */ to border ;     \ Put .75 % of reference as border

: INIT-SLIDE ( bit0 bit1 -- )   \ Activate slider
    to pad2  to pad1  init-touch  setborder ;

: >DATA     ( cnt1 cnt2 diff -- +n | 0 ) \ Convert measurements to slider data
    dup border > if         \ Slider touched?           cnt1 cnt2 diff f
        >r  drop            \ Yes,                      cnt1
        pad1 ref @ swap -   \ Calc difference-1         diff1
        dm 115 r> */        \ Yes, scale output         n
        7 -  0 max          \ Result positive           0 to +n
        dm 100 min 1+ exit  \ and keep in range         1 to 100
    then                    \ No, untouched!            cnt1 cnt2 diff
    drop  pad2 ADAPT        \ Drift correction 2        cnt1
    pad1 ADAPT  0 ;         \ Drift correction 1        0

\ One measurement for the slider takes 2 milliseconds
\ This is due to the separate measurements for each pad
\ Zero means that the slider was not touched! The slider
\ result goes from 1 to 101 increased by 1!
: SLIDER    ( -- 1-101 | 0 )
    pad1 measure            \ Read pad-1                cnt1
    pad2 measure            \ Read pad-2                cnt1 cnt2
    2dup +  negate          \ Add measurements & negate cnt1 cnt2 -cnt1+2
    pad1 ref @  pad2 ref @ + + \ Calc. difference       cnt1 cnt2 diff
    >data ;                 \ Convert to 0 to 101       +n 


\ Capacitive touch slider demos
hex
: >PWM      ( 0 to #CYCLUS -- )
    63 umin  196 ! ;        \ TA1CCR2   Set pulselength

\ PWM at P2.4 using timer-A1
: INIT-DIMMER ( p1 p0 -- )  \ Set 40 KHz PWM to output P2.4
    init-slide  init-pwm    \ Set P2.4 as PWM output
\ Init. timer-A1 for PWM
    0 180 !  63 192 !       \ TA1CTL   Stop timer-A1 & set period time
    40 186 !                \ TA1CCTL2 Set output mode to positive pulse
    234 180 ! ;             \ TA1CTL   Activate timer-A1

: DIMMER    ( -- )          \ Slider PWM demo
    4 5 init-dimmer         \ Use P1.4 & P1.5
    begin
        slider ?dup if      \ Slider activated?
            cr 1- dup .dec  >pwm \ Yes, show finger position
        then  80 ms
    key? until  0 >pwm ;


: .SLIDER   ( -- 1-101 | 0 )
    cr
    pad1 measure  dup .dec  \ Read pad-1                cnt1
    pad2 measure  dup .dec  \ Read pad-2                cnt1 cnt2
    2dup +                  \ Resulted count            cnt1 cnt2 cnt1+2
    space border .dec       \ Show border               cnt1 cnt2 cnt1+2
    negate                  \ Make result negative      cnt1 cnt2 -cnt1+2
    pad1 ref @ pad2 ref @ + \ Added reference value     cnt1 cnt2 -cnt1+2 ref1+2
    +  dup .dec             \ Show difference           cnt1 cnt2 diff
    >data ;                 \ Convert to 0 to 101       +n

: .SLIDE    ( -- )          \ Slider inner workings demo
    4 5 init-slide          \ Use P1.4 & P1.5
    begin
        .slider ?dup if     \ Slider activated?
            1- .dec         \ No, show finger position
        then
        80 ms
    key? until ;

' touchtwo  to app
shield TOUCH\  freeze

\ end ;;;
