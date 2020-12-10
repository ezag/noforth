(* E04 - For noForth C&V 200202: Port output with MSP430G2553 at port-2.

  RS232 via USB or Bluetooth in- and output met, with a copy at the LEDS.
  Use Bluetooth instead of USB serial connection... for MSP430G2553 version-A.
  Change KEY to show characters from Bluetooth or USB at the LEDS, the
  Launchpad has only uart0, so no fancy tricks here. Use the HC06 bluetooth
  module here only four wires need to be connected to the module.

  For Bluetooth two jumpers need to be removed, the TX and RX jumpers at J3
  Connect the power for the HC06 {pin12+13} with Launchpad J6 {VCC+GND},
  TX & RX from HC06 {pin1+2} with Launchpad J1 {pin3+4}

  Address 029 - P2OUT, port-2 output with 8 leds
  Address 02A - P2DIR, port-2 direction register
  Address 02E - P2SEL, port-2 selction register
  *)

hex
\ This key shows also the binary character pattern on the leds
: >LEDS         ( u -- )    29 c! ; \ P2OUT  Store pattern u at leds
: KEY*          ( c -- )    key)  dup >leds ;

: FLASH         ( -- )          \ Visualise startup
    FF >leds  64 ms             \ All leds on
    00 >leds  64 ms ;           \ All leds off

: SETUP         ( -- )
    0 2E c!                     \ P2SEL  Port-2 all bits I/O
    -1 2A c! ;                  \ P2DIR  All bits of P2 are outputs

: STARTUP       ( -- )
    setup  flash                \ Show new boot sequence
    ['] key* to 'key ;          \ Install new KEY

' startup to app  freeze

\ End ;;;
