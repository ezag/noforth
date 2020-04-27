(* E50 - For noForth C&V2553 lp.0, Low Power Modes examples. Bit input, output,
   hardware interrupt with machine code, using port-1 and port-2.
   Switch S2 triggers hardware-interrupt, which activates a running light.

  Wire 6 leds & resistor{s} or a led-print to P2.0 to P2.5 & ground.

  The settings for P1.3 can be found from page 337 and beyond in SLAU144J.PDF 

  The users words are: SLEEP0  SLEEP2  SLEEP3  SLEEP4

  08 20 - P1IN   Input bits
  08 21 - P1OUT  Output bits
  08 22 - P1DIR  Direction bits
  08 23 - P1IFG  Interrupt flag bits
  08 24 - P1IES  Interrupt edge select bits
  08 25 - P1IE   Interrupt enable bits
  08 26 - P1SEL  Function select bits
  08 27 - P1REN  Resistor enable bits
  08 41 - P1SEL2 Function select-2 bits
 
  FFE4  - P1 Interrupt vector

  MSP430 power modes name shortcuts & short explanation:
  AM   = Active Mode      - CPU & clocks active
  LPM0 = Low Power Mode 0 - CPU & MCLK disabled, DCO, SMCLK & ACLK active
  LPM1 = Low Power Mode 1 - Same as mode 0 except when DCO is not used
  LPM2 = Low Power Mode 2 - Only DC generator & ACLK active
  LPM3 = Low Power Mode 3 - Only ACLK active
  LPM4 = Low Power Mode 4 - CPU & clocks disabled
  More info at pages 28, etc. and page 45 of SLAU144J.PDF
 *)

hex
: >LEDS		( b -- )	029 c! ;    \ P2OUT
: FLASH     ( -- )  	-1 >leds A0 ms  0 >leds A0 ms ;

code INT-ON  	08 # 23 & .b bic  #8 sr bis  next  end-code  \ P1IFG
code INT-OFF    #8 sr bic  next  end-code
code LPM0       18 # sr bis  next  end-code \ Go from AM to LPM0
code LPM2       98 # sr bis  next  end-code \ Go from AM to LPM2
code LPM3       D8 # sr bis  next  end-code \ Go from AM to LPM3
code LPM4       F8 # sr bis  next  end-code \ Go from AM to LPM4

routine HARDWARE-INTERRUPT
    08 # 23 & .b bic    \ P1IFG  Interrupt flag off
    F8 # rp ) bic       \ Interrupt off & CPU active again!
    reti
end-code

: PORT1-ON  ( -- )
    F7 22 c!            \ P1DIR  P1.3 input others output
    08 27 *bis          \ P1REN  P1.3 resistor on
    08 21 *bis          \ P1OUT  P1.3 pullup active
    08 24 *bis          \ P1IES  P1.3 falling edge
    08 25 *bis          \ P1IE   P1.3 interrupt on
    08 23 *bic          \ P1IFG  P1.3 reset interrupt flag
    3F 2A *bis          \ P2DIR  P2.0 to P2.5 outputs
    41 21 *bic ;        \ P1OUT  P1.0 & P1.6 low, leds off

\ Running light
: RUNNER  	( -- )		1  8 0 do  dup >leds  2*  50 ms  loop  drop ;

\ The main loop sets up port-1 & port-2 flashes the leds at P2
\ Then activates a running light. After one run de CPU goes to sleep
\ mode LPM0 after activating a hardware interrupt.
\ Switch S2 generates the HW-interrupt with one run of the lights.
\ Power use at 8MHz, 3V3: AM+leds~10mA; AM-leds~3,5mA; LPM0~450uA
: SLEEP0    ( -- )
    port1-on  flash
    begin  runner  int-on  LPM0  key? until
    flash  int-off ;

\ The main loop sets up port-1 & port-2 flashes the leds at P2
\ Then activates a running light. After one run de CPU goes to sleep
\ mode LPM2 after activating a hardware interrupt.
\ Switch S2 generates the HW-interrupt with one run of the lights.
\ Power use at 8MHz, 3V3: AM+leds~10mA; AM-leds~3,5mA; LPM2~40uA
: SLEEP2    ( -- )
    port1-on  flash
    begin  runner  int-on  LPM2  key? until
    flash  int-off ;

\ The main loop sets up port-1 & port-2 flashes the leds at P2
\ Then activates a running light. After one run de CPU goes to sleep
\ mode LPM3 after activating a hardware interrupt.
\ Switch S2 generates the HW-interrupt with one run of the lights.
\ Power use at 8MHz, 3V3: AM+leds~10mA; AM-leds~3,5mA; LPM3~8uA
: SLEEP3    ( -- )
    port1-on  flash
    begin  runner  int-on  LPM3  key? until
    flash  int-off ;

\ The main loop sets up port-1 & port-2 flashes the leds at P2
\ Then activates a running light. After one run de CPU goes to sleep
\ mode LPM4 after activating a hardware interrupt.
\ Switch S2 generates the HW-interrupt with one run of the lights.
\ Power use at 8MHz, 3V3: AM+leds~10mA; AM-leds~3,5mA; LPM4~1uA
: SLEEP4    ( -- )
    port1-on  flash
    begin  runner  int-on  LPM4  key? until
    flash  int-off ;

hardware-interrupt  FFE4 vec!   \ Set P1 interrupt vector
shield LPM\  freeze

\ End
