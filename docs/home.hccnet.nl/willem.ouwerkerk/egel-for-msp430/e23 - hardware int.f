(* E23 - For noForth C&V2553 lp.0, bit input-, output and a hardware interrupt
  with machine code, using port-1 and port-2.
  One LED at hw-interrupt toggle, one LED with a toggle by sw-polling.
  SW1 does the interrupt, S2 uses sw-polling in the word LED.
  There is only simple debouncing in this example!

  Connect one toggle switch to P1.4 & ground. Wire 6 to 8 leds or a 
  led-print to P2.0 to P2.5/P2.7 & ground

 The settings for P1.4 can be found from page 337 and beyond in SLAU144J.PDF  

  10 20 - P1IN   Input bits
  10 21 - P1OUT  Output bits
  10 22 - P1DIR  Direction bits
  10 23 - P1IFG  Interrupt flag bits
  10 24 - P1IES  Interrupt edge select bits
  10 25 - P1IE   Interrupt enable bits
  10 26 - P1SEL  Function select bits
  10 27 - P1REN  Resistor enable bits
  10 41 - P1SEL2 Function select-2 bits

  FFE4  - P1 Interrupt vector
 *)

hex
: GREEN     ( -- )      40 21 *bix ; \ P1OUT
: RED       ( -- )      01 21 *bix ; \ P1OUT
: >LEDS	    ( b -- )    029 c! ; \ P2OUT
: FLASH     ( -- )      -1 >leds A0 ms  0 >leds A0 ms ;

code INT-ON     10 # 23 & .b bic  #8 sr bis  next  end-code \ P1IFG
code INT-OFF    #8 sr bic  next  end-code

routine HARDWARE-INTERRUPT
    40 # 21 & .b xor>   \ P1OUT  Toggle green led
    10 # 23 & .b bic    \ P1IFG  Interrupt flag off
    #8 sr bic           \ Interrupt off simple debouncing
    reti
end-code

: PORT1-ON  ( -- )
    E7 22 c!        \ 3+4 P1DIR  input others output
    18 27 *bis      \ 3+4 P1REN  resistor on
    18 21 *bis      \ 3+4 P1OUT  pullup active
    10 24 *bis      \ 3   P1IES  falling edge
    10 25 *bis      \ 3   P1IE   interrupt on
    10 23 *bic      \ 3   P1IFG  reset interrupt flag
    3F 2A *bis      \     P1IFG  six outputs
    int-on ;

\ The main loop sets up port-1 & port-2 flashes the leds at P2
\ Then goes in a loop testing the switch at P1.3 and flashes
\ the red led if it is pressed. It's second function is debouncing
\ of the switch S2 which generates the interrupts.
: LED       ( -- )
    port1-on  flash
    begin
        s? 0= if  red  then  90 ms  \ Toggle led on keypress & wait
        10 20 bit* if  int-on  then \ P1IN  Debounce toggle switch SW1
    key? until
    flash ;

hardware-interrupt  FFE4 vec!   \ Set P1 vector
shield int\  freeze

\ End
