(* e19d - For noForth c&v on G2553 c&v 200202ff: bit output & capacitive touch using timer-A0
  on MSP430G2553 using port-1. More info, see page 369ff of SLAU144J.PDF
  Selecting the pin function see SLAS735J page 42ff.
  CapTouch switch controlling LEDS. Use the timer count up function with INCLK input.

  Basic process: reset counter of TA0, wait a short while, read count register.
  The count gives an indication of whether the switch is touched.
  The watchdog interval timer interrupt is used to sample Timer-A0

  Forth words are: TOUCH?  TOUCH-ON  SHOW  TOUCH  TOUCH2  
                   TOUCHTWO  DIMMER  .SLIDE  MULTI

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
: GREEN       ( -- )    40 21 *bis  1 21 *bic ; \ P1OUT G2553 Launchpad LEDs on P1.0 & P1.6
: RED         ( -- )    1 21 *bis  40 21 *bic ; \ P1OUT
: LEDS-OFF    ( -- )    41 21 *bic ;            \ P1OUT
: INIT-LEDS   ( -- )    41 22 *bis ;            \ P1DIR
: INIT-PWM    ( -- )    10 2E *bis 10 2A *bis ; \ P2SEL, P2DIR  Set PWM to output pin P2.4

value P0  value P1          \ Hold two input-bit numbers
create REFS 4 cells allot   \ Remember the base of 4 untouched pads
create PADS 4 cells allot   \ Hold measurement values for all pads 
value BORDER                \ Slider border

\ MS and captouch interrupt sampler
code INT-ON   403B ,  pads ,  403C ,  10 ,  D232 ,  next  end-code
\ code INT-ON       ( -- )
\   pads # xx mov               \ Load start of table
\   10 # yy mov                 \ Load first input to sample
\   #8 sr bis  next             \ Interrupts on
\ end-code

value MS)   \ Decreases 976 times each second
\ Clock = 8000000/8192 longest interval 67,10 sec. usable as MS
: READY       ( -- )    5A11 120 ! ;         \ WDTCTL
: >MS         ( u -- )  5A19 120 !  to ms) ; \ WDTCTL

\ Decrease (ms) until it's zero and sample TA0 for touch sensor
routine TOUCH-MS  ( -- a )
    429B ,  170 ,  0 ,  
    CCC2 ,  41 ,  5C0C ,  532B ,
    903B ,  pads 8 + ,  2003 ,
    823B ,  403C ,  10 ,
    DCC2 ,  41 ,  40B2 ,  324 ,  160 ,
    9382 ,  adr ms) ,  2402 ,  53B2 ,
    adr ms) ,  1300 ,   
end-code
(* Original assembly code
routine TOUCH-MS ( -- a )
    170 & xx ) mov              \ TA0R    Read & store sample in table
    yy 41 & .b bic              \ P1SEL2  Erase current input
    yy yy add                   \         Select next input
    #2 xx add                   \         To next table entry
    pads 8 + # xx cmp  =? if,   \         Pointer out of range!
        #8 xx sub               \         Yes, restore pointer &
        10 # yy mov             \         restore input selector too
    then,
    yy 41 & .b bis              \ P1SEL2  Select next pin oscillator
    324 # 160 & mov             \ TA0CTL  Restart timer-A0 from zero
    #0 adr ms) & cmp            \         Perform MS
    <>? if,  #-1 adr ms) & add  then,
    reti
end-code
*)

\ A MS routine using the Watchdog interval mode
: MS        ( u -- )        >ms  begin  ms) 0= until  ready ;
TOUCH-MS    FFF4 vec!   \ Install watchdog interrupt vector

: REF       ( nr -- a )     3 and cells  refs + ; \ Calculate reference addres of current input-bit
: PAD@      ( bit -- cnt )  3 and cells  pads + @ ; \ Read Capacitive Touch measurement of input-bit

: ADAPT     ( cnt bit -- )  \ Drift correction on 'bit'
    >r  r@ ref @ - dup if   \ Count <> reference?
        0< -2 and 1+        \ Convert flag to -1 or 1
    then  r> ref +! ;       \ Correct reference with 0, 1 or -1

\ Touch switch primitives
: PAD?      ( bit -- cnt f )    \ Read input 'bit' using drift correction
    >r  r@ pad@                 \ Get count of bitnr            cnt
    r@ ref @  over -            \ REF - cnt = diff              cnt diff
    10 > if                     \ Difference greater then 10?   cnt
        rdrop  true  exit       \ Yes, ready                    cnt true
    then
    dup r> ADAPT  false ;       \ Do drift correction           cnt false

: TOUCH?    ( bitnr -- f )      pad? nip ;

: TOUCH-ON   ( -- )             \ Initialise hardware and value
    F0 26 *bic  F0 41 *bic      \ P1SELx  P1.4 to P1.7 as cap. touch
    ready  1 0 *bis  int-on     \ IE1     Activate interval interrupt
    324 160 !                   \ TA0CTL  (Re)start timer-A0
    init-leds   leds-off        \         Init. led I/O
    10 ms  pads refs 8 move ;   \ Save PADS reference data

\ Capacitive switch touch demos
: ?LED      ( f -- )    if green else red then ;    \ Switches red on when true, otherwise green
: .DEC      ( n -- )    decimal  4 .r  space  hex ; \ Print small decimals in fixed format

\ : .PADS     ( -- )      pads 8 bounds do  i @ .dec  2 +loop ; \ Trace routines
\ : .REFS     ( -- )      refs 8 bounds do  i @ .dec  2 +loop ;

\ This routine shows the inner working of the touch switch routine
\ Shows REF, capture counter and drift adjusting for a while
: .TOUCH    ( bit -- )
    to p0  touch-on
    begin
        cr p0 ref @ dup .dec        \ Show reference,
        p0 pad? >r  dup .dec        \ Show measurement, save flag
        space -  .dec               \ Show difference
        r@ ?led  space              \ Toggle leds too
        r> if  ." On "  then  40 ms \ Show switch function too
    key? until  leds-off ;

: TOUCH     ( bit -- )  \ Control both leds by capacitive touch input 'bitnr'
    touch-on  begin  dup touch? ?led  40 ms  key? until  drop  leds-off ;

: TOUCH2    ( bit0 bit1 -- )    \ Toggle both leds separately using P1.x & P1.y
    to p1  to p0  touch-on
    begin
        p0 touch? if  red    then
        p1 touch? if  green  then
        begin  p0 touch?  p1 touch?
        or 0= until  40 ms      \ Touch released? 
    key? until
    leds-off ;

: TOUCHTWO  ( -- )      4 5 touch2 ; \ Toggle both leds separately using P1.4 & P1.5


\ Slider implementation with one timer only!
: SETBORDER ( -- )          \ Set slider activation at .75 % of reference
    p0 ref @  p1 ref @ +    \ Add reference values
    3 dm 400 */ to border ; \ Put .75 % of reference as border

: INIT-SLIDE ( bit0 bit1 -- )   \ Activate slider
    to p1  to p0  touch-on  setborder ;

: >DATA     ( cnt1 cnt2 diff -- +n | 0 ) \ Convert measurements to slider data
    dup border > if         \ Slider touched?           cnt1 cnt2 diff f
        >r  drop            \ Yes,                      cnt1
        p0 ref @ swap -     \ Calc difference-1         diff1
        dm 115 r> */        \ Yes, scale output         n
        7 -  0 max          \ Result positive           0 to +n
        dm 100 min 1+ exit  \ and keep in range         1 to 100
    then                    \ No, untouched!            cnt1 cnt2 diff
    drop  p1 ADAPT          \ Drift correction 2        cnt1
    p0 ADAPT  0 ;           \ Drift correction 1        0

\ One measurement for the slider takes 2 milliseconds
\ This is due to the separate measurements for each pad
\ Zero means that the slider was not touched! The slider
\ result goes from 1 to 101 increased by 1!
: SLIDER    ( -- 1-100 | 0 )
    p0 pad@                 \ Read pad-1                cnt1
    p1 pad@                 \ Read pad-2                cnt1 cnt2
    2dup +  negate          \ Add measurements & negate cnt1 cnt2 -cnt1+2
    p0 ref @  p1 ref @ +  + \ Calc. difference          cnt1 cnt2 diff
    >data ;                 \ Convert to 0 to 101       +n 


\ Capacitive touch slider demos with PWM output at P2.4

: >PWM      ( +n -- )
    63 umin  196 ! ;        \ TA1CCR2   Set pulselength

\ PWM at P2.4 using timer-A1
: INIT-DIMMER ( p1 p0 -- )  \ Set 40 KHz PWM to output P2.4
    init-slide  init-pwm    \ Set P2.4 as PWM output
\ Init. timer-A1 for PWM
    0 180 !  0 >pwm         \ TA1CTL   Stop timer-A1 & set period time
    40 186 !                \ TA1CCTL2 Set output mode to positive pulse
    234 180 ! ;             \ TA1CTL   Activate timer

: DIMMER    ( -- )          \ Slider PWM demo
    4 5 init-dimmer         \ Use P1.4 & P1.5
    begin
        slider ?dup if      \ Slider activated?
            cr 1- dup .dec  >pwm \ Yes, show finger position
        then  80 ms
    key? until  0 >pwm ;


: .SLIDER   ( -- 1-101 | 0 )
    cr
    p0 pad@  dup .dec   \ Read pad-1                cnt1
    p1 pad@  dup .dec   \ Read pad-2                cnt1 cnt2
    2dup +              \ Resulted count            cnt1 cnt2 cnt1+2
    space border .dec   \ Show border               cnt1 cnt2 cnt1+2
    negate              \ Make result negative      cnt1 cnt2 -cnt1+2
    p0 ref @  p1 ref @ + \ Added reference value     cnt1 cnt2 -cnt1+2 ref1+2
    +  dup .dec         \ Show difference           cnt1 cnt2 diff
    >data ;             \ Convert to 0 to 101       +n

: .SLIDE    ( -- )      \ Slider inner workings demo
    4 5 init-slide      \ Use P1.4 & P1.5
    begin
        .slider ?dup if \ Slider activated?
            1- .dec     \ Yes, show finger position
        then
        80 ms
    key? until ;

\ Multi I/O example
: MULTI     ( -- )
    4 5 init-slide              \ Pin P1.4 & P1.5 for the sider
    begin
        cr ." Switch: "  7 pad? \ Switch pad on P1.7
        2 .r space  .dec        \ Show switch data
        ."  Slider:" slider .dec  40 ms \ Show slider data
    key? until ;

' multi  to app
shield TOUCH\  freeze

\ end ;;;
