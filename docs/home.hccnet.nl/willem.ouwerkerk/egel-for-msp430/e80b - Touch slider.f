(* e80b - For noForth c&v 59xx v 200202ff, capacitive touch example
  SLIDER with two capacitive touch sensors, a most complex example...
  using P3.5 and P3.6 on a MSP430FR5994 Launchpad
  30may2020 - Jeroen Hoekstra in cooperation with Willem Ouwerkerk
  userwords: SLIDER%, SHOW-SLIDER, DIMMER
*)

hex
\ : 5994: ; immediate   : 59x9: postpone \ ; immediate  \ Select this line for the MSP430FR5994
  : 59x9: ; immediate   : 5994: postpone \ ; immediate  \ Select this line for the MSP430FR59x9

value REF0  value REF1  value BORDER    \ base-value of CapSen0 & CapSen1 & level to register a touch
: ESC?          ( -- fl )   key? if  key 1B = exit  then  false ; \ This also works if terminal uses CR-LF

5994: : GREEN       ( -- )      2 202 *bis  1 202 *bic ; \ P1OUT 5994 Launchpad LEDs on P1.0 & P1.1
5994: : RED         ( -- )      1 202 *bis  2 202 *bic ; \ P1OUT
5994: : LEDS-OFF    ( -- )      3 202 *bic ;             \ P1OUT
5994: : INIT-LEDS   ( -- )      3 204 *bis  1 20A *bic ; \ P1DIR

59x9: : GREEN       ( -- )      1 202 *bis 40 223 *bic ; \ P1OUT P4OUT 5969 Launchpad Leds on P1.0 & P4.6
59x9: : RED         ( -- )      40 223 *bis 1 202 *bic ; \ P4OUT P1OUT
59x9: : LEDS-OFF    ( -- )      1 202 *bic 40 223 *bic ; \ P1OUT P4OUT
59x9: : INIT-LEDS   ( -- )      1 204 *bis 40 225 *bis ; \ P1DIR P4DIR

: INIT-PWM      ( -- )      1 20A *bis  1 20C *bic ; \ P1SELx P1.0 LED as PWM output
: SETBORDER     ( -- )      ref0 ref1 +  60 / to border ;
: ADAPT0        ( cnt0 -- )         \ ditto for ref0
\   ref0 - 0< if  -1  else  1  then  +to ref0 ;
    ref0 - 0< -2 and 1+ +to ref0 ;  \ YOU_RE A TRUE 'FORTHER' IF YOU UNDERSTAND THIS... 
: ADAPT1        ( cnt1 -- )         \ drift_comp for ref1
\   ref1 - 0< if  -1  else  1  then  +to ref1 ;
    ref1 - 0< -2 and 1+ +to ref1 ;  \ ditto

: ADAPT         ( cnt0 cnt1 -- )    \ autotuning and drift_compensation
    2dup +  ref0 ref1 +  swap -     \ both refs minus both reads
    border < if  adapt1  adapt0     \ only if diff < border handle drift_comp
    else  2drop  then ;             \ else do nothing

\ TA3 counter setup
\ 3 = Inclk stays clock source
\ 2 = mode stays continious up
\ 4 = Clear timer <- this is the wanted action
: READ-SLIDER ( -- cnt0 cnt1 )  \ Does 1 cycle of Capacitive Touch counting - cap0&1
    324 400 !  324 440 !  \ Set both timers to 0x0 ( TA2CTL & TA3CTL )
    1 ms  410 @  450 @    \ Read both TA2R & TA3R regs after a 1 ms wait
    2dup adapt ;

: TOUCHED?  ( cnt0 cnt1 -- f )  \ returns true on touch of slider
    +  ref0 ref1 +  swap -  border > ;

: CALC%     ( cnt0 cnt1 -- % )  \ calculates % between 0-99%
    ref1 swap -
    dup 1 < if  2drop  0  exit  then    \ on diff1 < 1 return 0%
    swap ref0 swap -
    dup 1 < if  2drop  63 exit  then    \ on diff0 < 1 return 99%
    over +  64 swap */ ;                \ diff1*100d / total_cnts  => %

: SLIDER%   ( -- 0-99/-1 )  \ returns -1 on no-touch or 0-99d% to indicate position of finger
    read-slider  2dup touched? if  calc%  else  2drop true  then ;


(*  *******  Start of demo-routine  **********

  Timer A0 setup for PWM for two leds - base address 0x340
  offsets: TA0CTL=0x0, TA0CCR0=0x12, TA0CCR1=0x14, TA0CCR2=0x16, TACCTL0=0x2, TACCTL1=0x4, TACCTL2=0x6
  TA0CTL=   10 = SMCLK ( should be OK )
            00 = div by 1
            01 = up mode count to CCR0 -> CCR0 is the period
            0  = reserved
            0  = reset TA0 ( should not be needed )
            00 = no interrupt or int flag
            -> 10 0001 0000 = 0x210
  TACCR0=0x64  = period = 100d
  TACCR2=0x0-0x63  green LED off to full on
  TACCTL0=0x0 -> no action
  TACCTL1=  111 = reset-set ( 011 = set-reset )
            0   = no interrupt
            0   = irrelevant
            0   = irrelevant
            0   = capt overflow -> irrelevant
            0   = interrupt-flag -> irrelevant
            -> 1110 0000 = 0xE0 ( or 1110 000 = 0xE0 )

*)

: INIT-SLIDER   ( -- )  \ Set I/O, timer-A0 for PWM & touch interface
     init-leds  init-pwm    \ Set   red & green LED as outputs
\ Init. timer-A0 for PWM
     0 340 !                \ TA0CTL   - Stop timer A0
    63 352 !                \ TA0CCR0  - period = 99 -> 100 cycli
    E0 344 !                \ TA0CCTL1 - set-reset mode
     0 354 !                \ TA0CCR1  - Green led off
    210 340 !               \ TA0CTL   - SMCLK, count continuously up to CCR0, no ints
\ 1 = Capacitive touch enabled,  3 = P3 enabled, C = P3.6, A = P3.5
\   440 = Timer_A3, 400 = Timer_A2, 3C0 = Timer_B0
    13A 43E !   13C 47E !   \ CAPTIO0CTL & CAPTIO1CTL  CapTouch activate P3.5 (=**A) & P3.6 (=**C)
    320 400 !   320 440 !   \ TA2CTL & TA3CTL - Timer A2&A3 internal clock, cont. count, no interrupts
    read-slider  to ref1  to ref0 \ Initialise slider references 
    setborder ;

: >PWM          ( 0-63 -- )     354 ! ; \ TA0CCR1  Set LED brightness

: DIMMER        ( -- )  \ Green LED on on touch - swiping shifts the brightness
    init-slider
    begin
        slider%  dup cr .
        dup 0< if  drop  0  then  >pwm  100 ms
    esc? until ;

\ This routine shows the very special inner workings of the SLIDER
: SHOW-SLIDER   ( -- )  \ Shows ref0, cnt0, ref1, cnt1, slider% until 'esc' is pressed
    init-slider
    begin
        cr read-slider 2dup swap
        ." ref0: " ref0 . ." cnt0:" .
        ." ref1: " ref1 . ." cnt1:" .
        2dup touched? if
            calc% ." slider-position:" decimal . hex ." %"
        else
            2drop ." no touch"
        then  100 ms
    esc? until ;

shield SLIDER\  freeze

\ End ;;;
