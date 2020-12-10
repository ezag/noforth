(* E02 - For noForth C&V 200202 or later: Port input at P1 & output at P2 with MSP430G2553

  Port-2 must be wired to 8 leds, placed on the launchpad experimenters kit.
  Wire P2.0 to P2.7 to the anode of eight 3mm leds placed on the breadboard 
  the pinlayout can be found in the hardwaredoc of the launchpad.
  Note: XIN is also P2.6 and XOUT is P2.7!! Connect all cathodes to each 
  other, and connect them to ground using a 100 Ohm resistor.
  Port-1 bit 3 holds a switch on the Launchpad board. 
  
  The most hard to find data are those for the selection registers. 
  To find the data for the selection register of Port-2 here 02E you have to
  go to the "Port Schematics". This starts on page 42 of SLAS735J.PDF, for 
  P2 the tables are found from page 50 and beyond. These tables say which 
  function will be on each I/O-bit at a specific setting of the registers. 

  Address 020 = P1IN, port-1 input register
  Address 022 = P1DIR, port-1 direction register
  Address 029 = P2OUT, port-2 output with 8 leds
  Address 02A = P2DIR, port-2 direction register
  Address 02E = P2SEL, port-2 selection register
 *)

hex
\ Use bit 3 to make a delay value (S?)
: WAIT          ( -- )      8 20 bit* 5 + 0A * ms ; \ P1IN bit-3
: >LEDS         ( b -- )    29 c! ; \ P2OUT  Store pattern b at leds

: FLASH         ( -- )  \ Visualise startup
    -1 >leds  64 ms     \ All leds on
    00 >leds  64 ms ;   \ All leds off

: SETUP-PORTS   ( -- )
    8 22 *bic           \ P1DIR  Port-1 bit 3 is input (S?)
    0 2E c!             \ P2SEL  Port-2 all bits I/O
    -1 2A c! ;          \ P2DIR  All bits of P2 are outputs

: COUNTER       ( -- )  \ Binary counter
    setup-ports  flash
    0                   \ Counter on stack
    begin
        1+              \ Increase counter
        dup >leds  wait
    key? until          \ Until key pressed
    drop ;

: RUNNER        ( -- )  \ A running light
    setup-ports  flash
    begin
        8 0 do          \ Loop eight times
            1 i lshift  \ Make bitpattern
            >leds  wait
        loop
    key? until          \ Until a key is pressed
    ;

freeze

\ End ;;;

