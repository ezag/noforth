(* E102A - For noForth C&V2553 lp.0, bit input and output, timer interrupt and
   hardware interrupt with machine code, on MSP430G2553 using port-1 and port-2.

  RC5 remote control decoder and power control for MSP430 Launchpad.
  Example of two cooperating interrupt routines. This code is for 16 MHz DCO!!

  Connect an 36 KHz infrared receiver to the RC5 connector,
  it must be a 3 Volt version like TSOP34536. As output a
  string of WS2812 power leds must be connected.

  The settings for P2.0 will be found from page 42 and beyond of SLAS735J.PDF,
  settings for timer A0 can be found on page 378 and beyond of SLAU144I.PDF

  P2.0 is used as RC5 input.
  01 028 = P2IN   - P2 RC5 receiver input           \ P2.0
  FE 029 = P2OUT  - P2 output bits
  FE 02A = P2DIR  - P2 direction register
  01 02B = P2IFG  - P2 Interrupt flag
  01 02C = P2IES  - P2 Interrupt edge
  01 02D = P2IE   - P2 Interrupt enable
  01 02E = P2SEL  - P2 configuration bits 0
  01 02F = P2REN  - P2 resistance on/off
  01 042 = P2SEL2 - P2 configuration bits 1
  FFE6   - P2 Interrupt vector

  Adresses of Timer-A0
  160 = TA0CTL   - Timer A0 control
  162 = TA0CCTL0 - Timer A0 Comp/Capt. control 0
  172 = TA0CCR0  - Timer A0 Comp/Capt. 0
  170 = TA0R     - Timer A0 register
  0000 0010 1101 0100 = 02D4 - TA = zero, count up mode, SMCLK, presc. /8
  FFF2   - Timer A0 Interrupt vector

  LED1  - P1.0 Red
  S2    - P1.3 Switch
  LED2  - P1.6 Green
  Trace - P2.2 Testpoint
  Out   - P2.0 RC5 input
  LED2  - P2.1 Uitput
 *)

hex
\ Bit 6 t/m 10 are the system-bits they contain the device address
\ TV = 00 -> 0000, CD = 20 -> 0500 en VCR = 05 -> 0140
dm 00  6 lshift  constant RCTYPE        \ RC5 transmitter type
value RCDATA                            \ Command databyte (14 bits)
value RC#                               \ Number of received bits

\ Give true when there is a valid RC5 command is for this device.
value RCKEY?        ( -- flag )

code INTERRUPT-ON       #8 sr bis  next  end-code
code INTERRUPT-OFF      #8 sr bic  next  end-code

routine RCBIT-IN    ( -- )              \ Read, decode and collect RC-bits
    dm 1760 #  172 & mov                \ TA0CCR0  Next half period in 880 us
    #1  adr rc# & add                   \ Increase half-bit counter
    #1  adr rc# & bit  cc? if,          \ Test even bits
        day push                        \ Save help register
        adr rcdata &  day mov           \ Copy of low bit in day
        #1  28 & .b bit                 \ P2IN  Read input P2.0 to carry
        #0  day addc                    \ Add carry to previous half-bit
        #1  day bit  cs? if,            \ Bit pattern valid (uneven) 1/0 or 0/1?
            1C #  adr rc# & cmp  =? if, \ All 14 (28 half)bits collected?
                adr rcdata &  day mov   \ Copy data
                07C0 #  day and>        \ Only valid address bits needed
                rctype # day cmp  =? if, \ My address?
                    #-1  adr rckey? & mov \ Yes, command valid!
                    #1  2B & .b bic     \ P2IFG  Reset HW interrupt flag
                    #1  2D & .b bis     \ P2IE   HW interrupt on
                    #0  160 & mov       \ Stop timer
                then,
            then,
        else,                           \ Invalid pattern, restart!
            #1  2B & .b bic             \ P2IFG  Reset HW interrupt flag
            #1  2D & .b bis             \ P2IE   HW interrupt on
            #0  160 & mov               \ TA0CTL Stop timer
        then,
        rp )+ day mov                   \ Restore original day
    else,
        #1  28 & .b bit                 \ P2IN  Read input P2.0
        adr rcdata & adr rcdata & addc  \ Save first half-bit
    then,
    reti
end-code

routine RCSTART     ( -- )          \ Edge noticed, start decoder!
    #0  adr rckey? & cmp  =? if,
        #1 2D & .b bic              \ P2IE  Stop hardware interrupt
        dm 860 #  172 & mov         \ TA0CCR0  Set time to first sample, 430 us (~0,43 ms)
        02D4 #  160 & mov           \ TA0CTL  Start timer
        #1  adr rc# & mov           \ Fake half received bit,
        #1  adr rcdata & mov        \ Fake bit is high!
    then,
    #1  2b & .b bic                 \ Reset HW interrupt flag
    reti
end-code

: RC-ON             ( -- )          \ Install decoder hardware
    0000 160 !  0010 162 !          \ TA0CTL, TA0CCTL0  Timer A0 off and compare 0 interrupt on
\ Set hardware interrupt at P2.0 ready, all other bits of P2 are outputs
    00 02E c!                       \ P2SEL  Port-2 use all bits as normal I/O
    01 2F *bis                      \ P2REN  Bit-0 resistor on
    FE 2A c!                        \ P2DIR  Bit-0 is input, 1 t/m 7 are output
    01 29 *bis                      \ P2OUT  Bit-0 pullup resistance
    01 2C *bis                      \ P2IES  Bit-0 falling edge
    01 2B *bic                      \ P2IFG  Bit-0 reset HW interrupt flag
    01 2D *bis                      \ P2IE   Bit-0 interrupt on
    0 to rckey?                     \ Allow new key input
    interrupt-on ;                  \ Activate decoder

: RC-OFF            ( -- )
    interrupt-off                   \ Deactivate decoder
    0000 160 !  0000 162 !          \ TA0CTL, TA0CCTL0  Stop timer-A0
    01 2D *bic ;                    \ P2IE   HW interrupts off

\ Receive a RC5 databyte, RC is a code from the definined RC5-code
\ command set. More info search for RC5 device documentation
\ here: https://en.wikipedia.org/wiki/RC-5
: RCKEY             ( -- rc )       \ Wait for an RC5 command
    begin  rckey? until             \ Wait for valid key
    rcdata 3F and                   \ Low 6-bits are key-code
    0 to rckey? ;                   \ Allow next key

: RC5KEY        ( -- rc )
    rckey  E0 ms  rckey? if  rckey drop  then ;

rcbit-in  FFF2 vec!         \ Set timer-A0 interrupt vector
rcstart   FFE6 vec!         \ Set P2 interrupt vector
shield rc5\  freeze

\ End
