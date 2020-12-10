(* E51 - For noForth C&V 200202: Watchdog as interval timer using LPM0. 
   Without use of LPM0 the CPU uses about 2,56mA with LPM0 it is 0,36mA
   The lowest two bits of the WDTCL register set the clock divider
   here it is set to 01 = SMCLK/8192
   The watchdog interrupt lowers a value MS# to zero
   User words are: MS  INTERVAL ( u -- )

  The settings for the watchdog can be found from page 344 
  and and beyond in SLAU144J.PDF  

  Used hardware registers:
  0041 0021 - P1OUT   P1 output bits
  0041 0022 - P1DIR   P1 direction bits
  0001 0000 - IE1     Watchdog interrupt on flag
  A5xx 0120 - WDTCTL  Watchdog control register

  FFF4      - Watchdog interrupt vector
 *)

hex
: GREEN       ( -- )    40 21 *bis  01 21 *bic ; \ P1OUT
: RED         ( -- )    01 21 *bis  40 21 *bic ;  \ P1OUT
: LEDS-OFF    ( -- )    41 21 *bic ; \ P1OUT
code LPM0     ( -- )    18 # sr bis  next  end-code \ To LPM0 & intrpt on

\ value MS#  \ Decreases 976 times each second
\ Clock = 8000000/8192 longest interval 67,10 sec. usable as MS
: READY       ( -- )    5A91 120 ! ;   \ WDTCTL 
: (MS)        ( u -- )  5A19 120 !  1 0 *bis  to ms# ; \ WDTCTL, IE1

\ Decrease ms# until it's zero
routine MSTIMER  ( -- )
    #0 adr ms# & cmp
    =? if,  
        #1 0 & .b bic   \ IE1  Watchdog int. off
        F8 # rp ) bic   \ LPM off, intrpt off
        reti
    then,
    #1 adr ms# & sub
    reti   
end-code

\ An MS routine using the Watchdog interval mode in LPM0
: MS          ( u -- )  (ms)  lpm0  ready ;

\ Set red LED on, set green LED on when the delay time is done
: INTERVAL    ( u -- ) 
    red  cr ." Delay: " dup u.  \ Red led on, show delay period
    leds-off  ms  green  ." ms done " ;   \ Green led on, ready

\ Watchdog timer interrupt activated, leds off
: PREPARE     ( -- )    ready  1 0 *bis  41 22 *bis  leds-off ; \ IE1, P1DIR

prepare
mstimer     FFF4 vec!   \ Install Watchdog interrupt vector
' prepare to app        \ Initialise watchdog interval mode
shield INTERVAL\   freeze 

\ End
