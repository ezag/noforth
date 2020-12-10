(* E01 - For noForth C&V 200202 or later: Port output with MSP430G2553 at port-2. 

  The two most important documents for the MSP430G2553 chips are,
  MSP430x2xx Family User's Guide: SLAU144J.PDF and MSP430G2x53
  micro controller documentation SLAS735J.PDF

  Port-2 must be wired to 8 leds, placed on the launchpad experimenters kit.
  Wire P2.0 to P2.7 to the anode of eight 3mm leds placed on the breadboard
  the pinlayout can be found in the hardwaredoc of the launchpad.
  Note: XIN is also P2.6 and XOUT is P2.7!! Connect all cathodes to each
  other, and connect them to ground using a 100 Ohm resistor. 

  The most hard to find data are those for the selection registers.
  To find the data for the selection register of Port-2 here 02E you have to
  go to the "Port Schematics". This starts on page 42 of SLAS735J.PDF, for
  P2 the tables are found from page 50 and beyond. These tables say which
  function will be on each I/O-bit at a specific setting of the registers.
  On page 328 and beyond of SLAU144J.PDF is data about all port-registers.

  Address 029 - P2OUT, port-2 output with 6 to 8 leds
  Address 02A - P2DIR, port-2 direction register
  Address 02E - P2SEL, port-2 selection register
 *)

hex

\ Store pattern b on 8 leds
: >LEDS         ( b -- )    29 c! ; \ P2OUT

: FLASH         ( -- )  \ Visualise startup
    FF >leds  64 ms    \ All leds on
    00 >leds  64 ms ;  \ All leds off

: SETUP-PORTS   ( -- )
    00 2E c!            \ P2SEL  Port-2 all bits I/O
    FF 2A c! ;          \ P2DIR  All bits of P2 are outputs

: COUNTER       ( -- )  \ Binary counter
    setup-ports  flash
    0                   \ Counter on stack
    begin
        1+              \ Increase counter
        dup >leds
        20 ms           \ Wait
    key? until
    drop ;

: RUNNER        ( -- )  \ A running light
    setup-ports  flash
    begin
        8 0 do          \ Loop eight times
            1 i lshift  >leds   \ Make bitpattern
            64 ms       \ Wait
        loop
    key? until          \ Until a key is pressed
    ;

freeze

\ End ;;;


