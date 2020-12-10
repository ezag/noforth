(* E18 - For nnoForth C&V 200202: Bit input & output with MSP430G2553
  Routines for reading and writing I/O-bits to and from a sensor module.

  P1.3  - PIR and switch S2 input
  P1.4  - Feeler left input
  P1.5  - Feeler right input
  P1.6  - Led light output

  The most hard to find data are those for the selection registers.
  To find the data for the selection register of Port-2 here 02E you have to
  go to the "Port Schematics". This starts on page 42 of SLAS735J.PDF, for
  P2 the tables are found from page 50 and beyond. These tables say which
  function will be on each I/O-bit at a specific setting of the registers.
  On page 328 and beyond of SLAU144J.PDF is data about all port-registers.

  Address 20 = P1IN, port-1 input register
  Address 21 = P1OUT, port-1 output register
  Address 22 = P1DIR, port-1 direction register
  Address 27 = P1REN, port-1 resistor enable register

  Address 29 - P2OUT, port-2 output with 8 leds
  Address 2A - P2DIR, port-2 direction register
  Address 2E - P2SEL, port-2 selection register

  *)

hex
: SETUP-SENSORS ( -- )  \ Initialise the simple sensor module
    38 22 *bic          \ P1DIR  P1.3, 4 & 5 inputs
    40 22 *bis          \ P1DIR  P1.6 output
    78 27 *bis          \ P1REN  Resistors on P1.3 to P1.5 on
    78 21 *bis ;        \ P1OUT  and pullups, also leds on


: MOTION?       ( -- flag )     08 20 bit* 0= ; \ Flag is true when motion is detected
: TOUCH-LEFT?   ( -- flag )     10 20 bit* 0= ; \ Flag is true when feeler is bend
: TOUCH-RIGHT?  ( -- flag )     20 20 bit* 0= ;
: ?LED          ( flag -- )     if  40 21 *bis  else  40 21 *bic  then ;

: SENSORS)      ( -- )
    motion? if  dup 0= ?led  exit  then \ Toggle led when motion is detected
    touch-left? touch-right? or  ?led ; \ Led is on when when a feeler is bend

\ Demo for testing the robotic sensor unit, the led flashes when the PIR is
\ activated. The leds are activated when a feeler (whisker) is bend.
: SENSORS       ( -- )
    setup-sensors  false        \ Setup I/O & flag
    begin
        sensors)  dm 100 ms     \ Test sensors & wait a moment
    key? until                  \ End it when a key was pressed
    drop  false ?led ;          \ Leds off, discard flag

shield SENSORS\  freeze

\ End
