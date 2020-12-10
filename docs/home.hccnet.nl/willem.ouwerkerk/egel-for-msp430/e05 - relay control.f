(* E05 - For noForth C&V 200202: Port input at P1.3 and output at P2.4 with MSP430G2553

  For the Egel kit a relay wired to the PWR output is sufficient. 
  For the Launchpad P2.4 must be wired to a transistor, placed on the shield.
  Wire P2.4 to the base of a BC549C or small mosfet using a 1K resistor. 
  The emitter to ground and the collector to a relay and the anode of a 
  suppression diode (1N4148/1N4001). 
  Connect the other side of the relay and diode to each other and VCC. 
  Take care that the relay does not pull to much current. An USB power supply
  usually gives up at about 500 mA. The used dongle however at 150mA.
  Port-1 bit 3 holds a switch on the Launchpad board. This is a delayed on, 
  off and on/off example!!

  To try an other sort delay just change the lines with the backslashes.
  But note: to select no more then one of the lines!!

  Address 020 = P1IN,  Port-1 input register
  Address 022 = P1DIR, Port-1 direction register
  Address 027 = P1REN, Port-1 resistor enable
  Address 029 = P2OUT, Port-2 output with 8 leds
  Address 02A = P2DIR, Port-2 direction register
  Address 02E = P2SEL, Port-2 selection register 
 *)

hex
: RELAY         10 29 ;             \ P2OUT  Relay output P2.4
: SWITCH        08 20 ;             \ P1IN   Switch input P1.3

: RELAY-ON      relay *bis ;
: RELAY-OFF     relay *bic ;
: SETUP-RELAY   10 2A *bis relay-off ; \ P2DIR  Start with relay off
    
\ Relay control demonstration, debounced input by securing
\ that the switch is on for at least 100 ms
: READ-INPUT        ( -- flag )     \ Sample switch
    0                               \ Begin value
    14 for                          \ Take 20 samples
        5 ms  switch bit* 0=  -     \ Wait, then count sample to value
    next
    14 = ;                          \ All 20 samples true?

: RELAY-OFF-DELAY   ( -- )          \ Relay quick on, and slow off 
    read-input if                   \ Switch pressed?
        relay-on                    \ Yes, ...
        begin  read-input 0= until  \ Switch released?
        dm 4000 ms  relay-off       \ Yes, after 4 sec. relay off
    then ;

: RELAY-ON-DELAY    ( -- )          \ Relay slow on, and quick off 
    read-input if                   \ Switch pressed?
        dm 1000 ms  relay-on        \ Yes, wait 1 sec. then switch on
        begin  read-input 0= until  \ Switch released?
        relay-off                   \ Yes, relay off
    then ;

: RELAY-ON/OFF-DELAY  ( -- )        \ Relay slow on, and off 
    read-input if                   \ Switch pressed?
        dm 1000 ms  relay-on        \ Yes, wait 1 sec. then switch on
        begin  read-input 0= until  \ Switch released?
        dm 4000 ms  relay-off       \ Yes, after 4 sec. relay off
    then ;

\ Choose one of three relay examples
: RELAY-CONTROL     ( -- )          \ Control relay using switch S2
    setup-relay                     \ Set relay off
    8 22 *bic  8 27 *bis            \ P1DIR, P1REN Input P1.3 with pullup
    dm 500 ms  relay-on             \ Show startup by switching 
    dm 1000 ms  relay-off           \ relay on and off
    begin  relay-off-delay  key? until ;
\   begin  relay-on-delay  key? until ;
\   begin  relay-on/off-delay  key? until ;

setup-relay  freeze

                    ( End )
