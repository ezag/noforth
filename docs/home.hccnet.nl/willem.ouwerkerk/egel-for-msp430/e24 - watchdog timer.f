(* E24 - For noForth C&V2553 lp.0, Watchdog initialisation and use.

   The primary function of a watchdog timer, is to perform a controlled 
   system restart after a software problem occurs.

   Used hardware registers:
   0001 0002 - IFG1   Interrupt flag register 1
   xxxx 0120 - WDTCTL Watchdog control register

   The lowest two bits of the WDTCL register set the clock divider.
   In this example it is set to 00 = SMCLK/32768. The activating time 
   of the watchdog may be changed. This may be done with an other clock 
  (ACLK or SMCLK) and/or an other clock divider.
   
   When the value 'U > 0780' the watchdog restarts noForth.
   The user word is: WATCHDOG  ( u -- )

   The settings for the watchdog can be found from page 346
   and and beyond in SLAU144J.PDF 
 *)

hex
\ Show watchdog reset from IFG1 register
\ IFG1, Bit 0 = Watchdog interrupt flag
: .(RE)START    ( -- )
    cr ." (Re)start noForth " 
    01 002 bit* if  ." by watchdog timer "  then \ IFG1 
    01 002 *bic ;       \ IFG1  Reset watchdog interrupt flag

: WD-ON         ( -- )    5A08 120 ! ; \ WDTCTL - (Re)activate watchdog timer
: WD-OFF        ( -- )    5A80 120 ! ; \ WDTCTL - Watchdog deactivated

\ This program prints after how much empty DO LOOP's 
\ the watchdog timer interval expires! 
\ The word in the APP vector then shows how noForth was reset.
: WATCHDOG      ( u -- )
    0 ?do
        cr ." Delay: " 
        i dup u.        \ Show delay period
        wd-on           \ (Re)start watchdog
        0 ?do  loop     \ Delay
        wd-off
    0A0 +loop           \ Next delay count
    ." Ready " ; 

' .(re)start  to app
shield WATCHDOG\   freeze

\ End
