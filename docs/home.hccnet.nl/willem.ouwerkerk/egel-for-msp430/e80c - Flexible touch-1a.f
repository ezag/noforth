(* e80c - For noForth c&v 59xx v 200202ff, Capacitive touch example,
   3 juni 2020 - Jeroen Hoekstra en Willem Ouwerkerk
   A slightly more complex example (~1050 bytes code)

    Needs Timer A3 & Input P3.0 to P3.7
    User words: INIT-TOUCH  TOUCH?  INIT-SLIDER  SLIDER
    Examples  : .TOUCH  TOUCH  TOUCHTWO  .SLIDE  SLIDE

CAPTIO0CTL:
    Bit 0       = 0 - NC
    Bit 1 to 3  = 000 to 111 = Px.0 to Px.7
    Bit 4 to 7  = 0000 = PJ, 0001 = P1, etc.
    Bit 8       = Capacitive touch on/off. 1 = on

https://youtu.be/KZN928Fd7Dc 

*)

hex
\ : 5994: ; immediate   : 59x9: postpone \ ; immediate  \ Select this line for the MSP430FR5994
  : 59x9: ; immediate   : 5994: postpone \ ; immediate  \ Select this line for the MSP430FR59x9

5994: : GREEN       ( -- )      2 202 *bis  1 202 *bic ; \ P1OUT 5994 Launchpad LEDs on P1.0 & P1.1
5994: : RED         ( -- )      1 202 *bis  2 202 *bic ; \ P1OUT
5994: : LEDS-OFF    ( -- )      3 202 *bic ;             \ P1OUT
5994: : INIT-LEDS   ( -- )      3 204 *bis  1 20A *bic ; \ P1DIR

59x9: : GREEN       ( -- )      1 202 *bis 40 223 *bic ; \ P1OUT P4OUT 5969 Launchpad Leds on P1.0 & P4.6
59x9: : RED         ( -- )      40 223 *bis 1 202 *bic ; \ P4OUT P1OUT
59x9: : LEDS-OFF    ( -- )      1 202 *bic 40 223 *bic ; \ P1OUT P4OUT
59x9: : INIT-LEDS   ( -- )      1 204 *bis 40 225 *bis  1 20A *bic ; \ P1DIR P4DIR P1SEL0

: INIT-PWM  ( -- )      4 204 *bis  4 20A *bis  4 20C *bic ; \ P1SELx P1.2 is PWM output

value PAD1  value PAD2      \ Hold two input-bit numbers
create REFS 8 cells allot   \ Remember the base of 8 untouched pads
value BORDER                \ Slider border

\ Calculate reference addres of current input-bit
: REF       ( nr -- a )     2*  refs + ;

: SELECT-INPUT ( bit -- ) \ Select 'bit' as active captive touch input
    2*  0E and      \             Convert bitnr to bit-mask
    47E @  1F0 and  \ CAPTIO1CTL  Read & mask out port-bits
    or  47E ! ;     \ CAPTIO1CTL  Select capacitive touch input bit

\ TA3 counter setup
\ 3 = Inclk is clock source, 2 = Continuous up mode, 4 = Clear timer
: MEASURE   ( bit -- cnt )  \ Do Capacitive Touch measurement
    select-input  324 440 ! ( TA3CTL )  1 ms  450 ( TA3R ) @ ;

: ADAPT     ( cnt bit -- )  \ Drift correction on 'bit'
    >r  r@ ref @ - dup if   \ Count <> reference?
        0< -2 and 1+        \ Convert flag to -1 or 1
    then  r> ref +! ;       \ Correct reference with 0, 1 or -1

\ 1 = Capacitive touch enabled, 3 = P3 enabled, C = P3.6
\ 3 = Inclk is clock source, 2 = Continuous up mode, 0 = Stop timer
: INIT-TOUCH ( -- )         \ Initialise hardware and value
    init-leds   leds-off    \             Init. led I/O
    13C 47E !               \ CAPTIO1CTL  CapTouch activate P3.6
    320 440 !               \ TA3CTL      Timer A3 stopped
    8 for  i measure        \ Do 8 reference measurements on P3
           i ref !  next ;

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

: TOUCH2    ( bit0 bit1 -- )    \ Toggle both leds separately using P3.x & P3.y
    to pad2  to pad1  init-touch
    begin
        pad1 touch? if  red    then
        pad2 touch? if  green  then
        begin  pad1 touch?  pad2 touch?  or 0= until  40 ms \ Touch released? 
    key? until
    leds-off ;

: TOUCHTWO  ( -- )      5 6 touch2 ; \ Toggle both leds separately using P3.5 & P3.6


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

: INIT-DIMMER ( -- )        \ Set 40 KHz PWM to output P1.2
    init-slide  init-pwm    \ Set P1.2 as PWM output
\ Init. timer-A0 for PWM
     0 380 !                \ TA1CTL   - Stop timer A1
    63 392 !                \ TA1CCR0  - period = 99 -> 100 cycli
    E0 384 !                \ TA1CCTL1 - set-reset mode
     0 394 !                \ TA1CCR1  - P1.2 off
    290 380 ! ;             \ TA1CTL   - SMCLK/4, count continuously up to CCR0, no ints

: >PWM      ( +n -- )       64 umin  394 ! ; \ TA1CCR1  Set LED brightness

: DIMMER    ( -- )          \ Slider PWM demo
    5 6 init-dimmer         \ Use P3.5 & P3.6
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
    5 6 init-slide          \ Use P3.5 & P3.6
    begin
        .slider ?dup if     \ Slider activated?
            1- .dec         \ No, show finger position
        then
        80 ms
    key? until ;

' touchtwo  to app
shield TOUCH\  freeze

\ end ;;;
