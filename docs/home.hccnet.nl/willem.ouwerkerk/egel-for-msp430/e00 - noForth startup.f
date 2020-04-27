(* E00 - For noForth C&V2553, Bit output with MSP430G2553 at port-1. 

  The two most important documents for the MSP430G2553 chips are,
  MSP430x2xx Family User's Guide: SLAU144J.PDF and MSP430G2x53
  micro controller documentation SLAS735J.PDF

  On Port-1 two leds are wired to P1.0 & P1.6, placed on the 
  launchpad board or egel-kit.

  The most hard to find data are those for the selection registers.
  To find the data for the selection register of Port-1 here 02E you have to
  go to the "Port Schematics". This starts on page 42 of SLAS735J.PDF, for
  P1 the tables are found from page 43 and beyond. These tables say which
  function will be on each I/O-bit at a specific setting of the registers.
  On page 328 and beyond of SLAU144J.PDF is data about all port-registers.

  Address 021 - P1OUT, port-1 output with 2 leds
  Address 022 - P1DIR, port-1 direction register
  Address 026 - P1SEL, port-1 selection register
 *)

hex

\ Store pattern b at leds
: ON            ( bit port -- )     *bis ; \ Set bit on
: OFF           ( bit port -- )     *bic ; \ Set bit off
: RED           ( -- )   01 21 ; \ P1OUT  red led address
: GREEN         ( -- )   40 21 ; \ P1OUT  green led address

: DELAY         ( -- )  \ Delay is shorter when S2 is pressed
    100  s? 0= if  80 -  then  ms ;

: FLASH         ( -- )      \ Visualise startup
    4 0 ?do  red on   64 ms \ Red led on
             red off  64 ms \ Red led off
    loop ;

: SETUP-PORT    ( -- )
    41 022 c!  green off ;  \ P1DIR  P1.0 & P1.6 are outputs, Green led off

: FLASH         ( -- )      \ A led flasher
    setup-port  flash       \ Init. port
    begin
        red on   green off  delay
        red off  green on   delay
    key? until ;            \ Until a key is pressed

freeze

\ End ;;;
