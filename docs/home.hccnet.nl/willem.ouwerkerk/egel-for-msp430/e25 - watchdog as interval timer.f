(* E25 - For noForth C&V2553 lp.0, Watchdog as interval timer.
  The lowest two bits of the WDTCL register set the clock divider
  here it is set to 01 = SMCLK/8192
  The watchdog interrupt lowers a value MS) to zero
  The user word is: INTERVAL  ( u -- )

  The settings for the watchdog can be found from page 344
  and and beyond in SLAU144J.PDF

  Used hardware registers:
  0041 0021 - P1OUT   P1 output bits
  0041 0022 - P1DIR   P1 direction bits
  0001 0000 - IE1     Watchdog interrupt on flag
  A5xx 0120 - WDTCTL Watchdog control register

  FFF4      - Watchdog interrupt vector
 *)

hex
: GREEN       ( -- )    40 21 *bis  01 21 *bic ; \ P1OUT
: RED         ( -- )    01 21 *bis  40 21 *bic ; \ P1OUT
: LEDS-OFF    ( -- )    41 21 *bic ; \ P1OUT
code INT-ON   ( -- )    D232 ,  4F00 ,  end-code
code INT-OFF  ( -- )    C232 ,  4F00 ,  end-code
\ CODE INT-ON       #8 SR BIS  NEXT  END-CODE
\ CODE INT-OFF      #8 SR BIC  NEXT  END-CODE

value MS)   \ Decreases 976 times each second
\ Clock = 8000000/8192 longest interval 67,10 sec. usable as MS
: READY       ( -- )    5A91 120 ! ;   \ WDTCTL
: (MS)        ( u -- )  5A19 120 !  to ms) ;   \ WDTCTL

\ Decrease (ms) until it's zero
create MSTIMER  9382 ,  adr ms) ,  2402 ,  53B2 ,  adr ms) ,  1300 ,
\ routine MSTIMER  ( -- )
\    #0 adr ms) & cmp
\    <>? if,  #-1 adr ms) & add  then,
\    reti
\ end-code

\ An MS routine using the Watchdog interval mode
: MS          ( u -- )  (ms)  begin  ms) 0= until  ready ;

\ Set red LED on, set green LED on when the delay time is done
: INTERVAL    ( u -- )
    red  cr ." Delay: " dup u.  \ Red led on, show delay period
    ms  green  ." ms done " ;   \ Green led on, ready

\ Watchdog timer interrupt activated, leds off
: PREPARE     ( -- )
    ready  1 0 *bis  int-on  41 22 *bis  leds-off ; \ IE1, P1DIR

prepare
mstimer     FFF4 vec!   \ Install watchdog interrupt vector
' prepare to app        \ Initialise watchdog interval mode
shield INTERVAL\   freeze

\ End
