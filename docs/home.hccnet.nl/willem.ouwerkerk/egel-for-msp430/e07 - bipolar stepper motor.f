(* E07 - For noForth C&V 200202: Bipolar stepper motor control 
  Port input at P1 & output at P2 with MSP430G2553 

  Port-2 must be wired to a bidirectional driver module like:
    40053 L9110S module driver controller board or a L293 like 
    driver placed on the launchpad experimenters kit.
    Using the L9110S module the wiring is:
      P2.0 to A-1A - Coil 1
      P2.1 to A-1B
      P2.2 to B-1A - Coil 2
      P2.3 to B-1B
    Using an L293 the wiring is:
      Wire P2.0 to P2.3 to the basis of four driver inputs placed on the
      breadboard the pinlayout can be found in the hardware documentation
      of the launchpad. Connect a stepper motor to the four outputs.

  Port-1 bit 3 holds a switch on the Launchpad board.
 
  Address 020 = P1IN,  port-1 input register
  Address 021 = P1OUT, port-1 input register
  Address 022 = P1DIR, port-1 direction register
  Address 029 = P2OUT, port-2 output with 8 leds
  Address 02A = P2DIR, port-2 direction register
  Address 02E = P2SEL, port-2 selection register

  029 - motor      Stepper motor output P2.0 - P2.3
  020 - input      Switch input P1.3
 *)

hex
: DIR?      8 20 bit* ;             \ P1IN  Forward/backward selection P1.3

value WAIT                          \ Delay step time
value STEP                          \ Next output word
value STEP#                         \ Table mask

create 1PHASE  DD c, BB c, EE c, 77 c,                         \ Single phase
create 2PHASE  99 c, AA c, 66 c, 55 c,                         \ Double phase
create HALF    DD c, 99 c, BB c, AA c, EE c, 66 c, 77 c, 55 c, \ Halfstep

: ONE-PHASE   step 1phase + c@  29 c!  3 to step# ;  \ P2OUT
: TWO-PHASE   step 2phase + c@  29 c!  3 to step# ;  \ P2OUT
: HALF-STEP   step half   + c@  29 c!  7 to step# ;  \ P2OUT
: ONE-STEP      ( -- )      one-phase  ( two-phase ) ( half-step ) ;

: FORWARD       ( -- )              \ Motor one step forward
    step 1+  step# and  to step  one-step  wait ms ;

: BACKWARD      ( -- )              \ Motor one step backward
    step 1-  step# and  to step  one-step  wait ms ;

: SETUP-STEP    ( -- )
    0F 2A *bis  18 22 *bic          \ P2DIR, P1DIR  P2 low 4-bits are output
    18 21 *bis  18 27 *bis          \ P1OUT, P1REN  Bit 3+4 of P1 are input with pullup
    20 to wait                      \ Set delay time
    3 to step#                      \ Set default table mask
    0 to step ;                     \ Start with first step

: TURN          ( -- )              \ Choose motion direction of motor
    dir? if  forward exit  then  backward ;

: STEPPER       ( -- )              \ Control a biphase stepper motor
    setup-step  begin  turn  key? until ;

' setup-step  to app  freeze

                            ( End )
