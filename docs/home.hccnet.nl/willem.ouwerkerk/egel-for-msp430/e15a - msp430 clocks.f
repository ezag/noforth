(* For noForth C&V 200202: Routines for different (S)MCLK frequencies.
  This code does work with Launchpad, Egel kit & Micro Launchpad.
  Data comes for the DCO comes from info-flash segment A at 10C0
  Start of data for DCO from 10F6
  Flash clock must be in the range from from 257KHz to 476KHz!
  The default selected baudrate is here always 9600 baud!
  With the 12kHz mo baudrate, in 32kHz mode 9600 baud is the maximum.
  Note also that the flash clock is not valid when using 32kHz!

  Details about the setting of DCO clock from page 277, etc.
  of SLAU144J.PDF The settings for de baudrate from page 424, etc.
  of the same document. More on DCO setup data at page 15 of SLAS735J.PDF
  Information about the built-in capacitators for the 32kHz xtal,
  see SLAU144J.PDF page 274 and beyond.
 *)

hex
code INT-OFF   C232 ,  4F00 ,  end-code

\ Activate VLOCLK as system clock for the MSP430 Current AM~0,030mA
\ Note: No baudrate is selected here!
: 12KHZ     ( -- )
    int-off
    00 57 c!        \ BCSCTL1   Switch low freq. mode on
    20 53 c!        \ BCSCTL3   12kHz VLOCLK on
    C8 58 c!        \ BCSCTL2   SMCLK & MCLK are VLOCLK
    1 TO MS# ;      \ MS timing

\ Do not use flash programming or erasing its not valid on this frequency!
\ Set system clock to 32 KHz, current use of CPU without leds AM~0,040mA
\ Note that 9600B is the maximal stable baudrate!
: 32KHZ     ( -- )
    int-off  2 ms
    00 57 c!        \ BCSCTL1   Switch low freq. mode on
    0C 53 c!        \ BCSCTL3   32kHz with 12pF
    begin           \ LFXT osc. running?
        2 2 *bic    \ IFG1      Clear bit 2
        noop  noop  \ Wait, Bit 2 remains clear
    2 2 bit* 0= until \ when osc. runs fine!
    C8 58 c!        \ BCSCTL2   LFXT1CLK on SMCLK
    41 61 c!        \ UCA0CTL1  Uart use ACLK
    03 62 c!        \ UCA0BR0   32 KHz, baudrate 9600
    00 63 c!        \ UCA0BR1
    06 64 c!        \ UCA0CTL0  modulation ucbrsx = 3
    01 61 *bic      \ UCA0CTL1  enable USCI
    A500 12A !      \ FCTL2     mclk/1=32KHz
    4 TO MS# ;      \ MS timing

\ Set DCO to 1 MHz, current use of CPU without leds AM~0,4mA
: 1MHZ      ( -- )  \ Baudrate 9600b
    int-off  2 ms
    10FF c@ 57 c!   \ BCSCTL1   Set DCO = 1MHz
    10FE c@ 56 c!   \ DCOCTL
    00 58 c!        \ UCA0CTL2  DCO on
    81 61 *bis      \ UCA0CTL1  Uart use SMCLK
    68 62 c!        \ UCA0BR0   1 mhz, baudrate 9600
    00 63 c!        \ UCA0BR1   idem
    02 64 c!        \ UCA0CTL0  modulation ucbrsx = 1
    01 61 *bic      \ UCA0CTL   enable USCI
    A542 12A !      \ FCTL2     mclk/3=333KHz
    F9 TO MS# ;     \ MS timing

\ Set DCO to 8 MHz, current use of CPU without leds AM~3,000mA
: 8MHZ      ( -- )  \ Baudrate 9600B
    int-off  2 ms
    10FD c@ 57 c!   \ BCSCTL1   set dco = 8 mhz
    10FC c@ 56 c!   \ DCOCTL
    00 58 c!        \ UCA0CTL2  DCO on
    81 61 *bis      \ UCA0CTL1  Uart use SMCLK
    41 62 c!        \ UCA0BR0   8 mhz, baudrate 9600
    03 63 c!        \ UCA0BR1   idem
    04 64 c!        \ UCAMCTL   modulation ucbrsx = 2
    01 61 *bic      \ UCA0CTL   enable USCI
    A550 12A !      \ FCTL2     mclk/17=470KHz flash timing
    7CF TO MS# ;    \ MS timing

\ Set DCO to 16 MHz, current use of CPU without leds AM~6,000mA
: 16MHZ     ( -- )  \ Baudrate 9600B
    int-off  2 ms
    10F9 c@ 57 c!   \ BCSCTL1   Set DCO = 16MHz
    10F8 c@ 56 c!   \ DCOCTL
    00 58 c!        \ DCO on
    81 61 *bis      \ UCA0CTL   Uart use smclk
    82 62 c!        \ UCA0BR0   16 mhz, baudrate 9600
    06 63 c!        \ UCA0BR1
    0C 64 c!        \ UCAMCTL   modulation ucbrsx = 6
    01 61 *bic      \ UCA0CTL   enable USCI
    A562 12A !      \ FCTL2     mclk/34=470KHz
    F9F TO MS# ;    \ MS timing

: BLINKLEDS ( -- )    41 21 *bis  64 ms  41 21 *bic ;

\ Use BLINK 12KHZ or BLINK 16MHZ to test different frequency's
\ Always return to 8 MHz so the system keeps on communicating!
: BLINK     ( ccc -- )
    41 22 *bis              \ P1DIR  P1.0 & P1.6 are outputs with leds
    10 ms  ' execute        \ Wait and set new system frequency
    dm 10 0 do              \ Loop 10 times
        blinkleds  1770 ms  \ Blink leds and wait 6 seconds
    loop  8mhz ;            \ Return to 8 MHz

shield CLOCKS\  freeze
