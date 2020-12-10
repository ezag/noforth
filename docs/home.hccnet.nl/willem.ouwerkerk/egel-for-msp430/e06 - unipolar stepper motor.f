(* E06 - For noForth C&V 200202: Unipolar four phase stepper motor
  control. Port input at P1 & output at P2 with MSP430G2553.

  Port-2 must be wired to a stepper motor module like this:
  4-phase Stepper Motor + Driver Board ULN2003 from AliExpress
  or 4 transistors, placed on the launchpad experimenters kit. 
  Wire P2.0 to P2.3 to the basis of four transistors placed on the 
  breadboard the pinlayout can be found in the hardwaredoc of the launchpad. 
  Connect a stepper motor to the four collectors of the transistors.
  Port-1 bit 3 holds a switch on the Launchpad board.

  Address 020 = P1IN,  port-1 input register
  Address 021 = P1OUT, port-1 input register
  Address 022 = P1DIR, port-1 direction register
  Address 027 = P1REN, port-1 resistor enable
  Address 029 = P2OUT, port-2 output with 8 leds
  Address 02A = P2DIR, port-2 direction register
  Address 02E = P2SEL, port-2 selection register

  029 - motor      Stepper motor output P2.0 - P2.3
  020 - input      Switch input P1.3
 *)

hex
: DIR?      8 20 bit* ;             \ P1IN  Forward/backward selection P1.3

value WAIT                          \ Step delay
value STEP                          \ Next output word
value STEP#                         \ Table mask

create 1PHASE  8 c, 4 c, 2 c, 1 c,                     \ Single phase
create 2PHASE  9 c, C c, 6 c, 3 c,                     \ Double phase
create HALF    9 c, 8 c, C c, 4 c, 6 c, 2 c, 3 c, 1 c, \ Halfstep

\ Select one of three stepper methods in the word ONE-STEP
: ONE-PHASE     ( -- )      step 1phase + c@  29 c!  3 to step# ; \ P2OUT
: TWO-PHASE     ( -- )      step 2phase + c@  29 c!  3 to step# ; \ P2OUT
: HALF-STEP     ( -- )      step half  + c@   29 c!  7 to step# ; \ P2OUT
: ONE-STEP      ( -- )      one-phase  ( two-phase ) ( half-step ) ;

: FORWARD       ( -- )              \ Motor one step forward
    step 1+  step# and  to step  one-step  wait ms ;

: BACKWARD      ( -- )              \ Motor one step backward
    step 1-  step# and  to step  one-step  wait ms ;

: SETUP-STEP    ( -- )
    F 2A *bis  8 22 *bic    \ P2DIR, P1DIR  P2 low 4-bits are output
    8 21 *bis  8 27 *bis    \ P1OUT, P1REN  Bit 3 of P1 is input with pullup
    20 to wait              \ Step delay of 32 ms
    3 to step#              \ Set default table mask
    0 to step ;             \ Start with first step

: TURN          ( -- )      \ Choose motion direction of motor
    dir? if  forward exit  then  backward ;

: STEPPER       ( -- )      \ Control a 4 phase stepper motor
    setup-step  begin  turn  key? until ;

' setup-step  to app  freeze

                            ( End )
