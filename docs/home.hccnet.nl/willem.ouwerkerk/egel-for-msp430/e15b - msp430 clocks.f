\ For noForth C&V 200202: Routines for different MCLK frequencies.
\ This code does not work with Launchpad!!
\ It only works on the Egel kit and Micro Launchpad!
\ Data comes for the DCO comes from info-flash segment A at 10C0
\ Start of data for DCO from 10F6
\ Flash clock must be in the range from from 257KHz to 476KHz!
\ The default selected baudrate is 38400 baud!
\ With the 12kHz and 32kHz mode no baudrate is set!
\ For 38K4 the assembler loads in five seconds, linedelay = 40 ms

( Details about the setting of DCO clock from page 277, etc.
  of SLAU144J.PDF The settings for de baudrate from page 424, etc.
  of the same document. More on DCO setup data at page 15 of SLAS735J.PDF )

hex
code INT-OFF   C232 ,  next  end-code

\ Activate VLOCLK as system clock for the MSP430 Current AM~0,030mA
\ Note: No baudrate is selected here!
: 12KHZ     ( -- )
    int-off
    00 57 c!        \ BCSCTL1   Switch low freq. mode on
    20 53 c!        \ BCSCTL3   12kHz VLOCLK on
    C8 58 c!        \ BCSCTL2   SMCLK & MCLK are VLOCLK
    1 TO MS# ;      \ MS timing

\ Set clock to 32 kHz, current use of CPU without leds = 0,04mA
\ Note: No baudrate is selected here!
: 32KHZ     ( -- )
    int-off
    00 57 c!        \ BCSCTL1   Switch low freq. mode on
    0C 53 c!        \ BCSCTL3   32kHz with 12pF
    begin           \ LFXT osc. running?
        2 2 *bic    \ IFG1      Clear bit 2
        noop  noop  \ Wait, Bit 2 remains clear
    2 2 bit* 0= until \ when osc. runs fine!
    4 TO MS# ;      \ MS timing

\ Set DCO to 1 MHz, current use of CPU without leds = 0,35mA
: 1MHZ      ( -- )  \ Baudrate 38K4
    int-off
    10FF c@ 57 c!   \ BCSCTL1   Set DCO = 1MHz
    10FE c@ 56 c!   \ DCOCTL
    00 58 c!        \ UCA0CTL2  DCO on
    81 61 *bis      \ UCA0CTL1  Uart use SMCLK
    1A 62 c!        \ UCA0BR0   1 mhz, baudrate 38400
    00 63 c!        \ UCA0BR1   idem
    00 60 c!        \ UCA0CTL0  modulation ucbrsx = 0
    01 61 *bic      \ UCA0CTL   enable USCI
    A542 12A !      \ FCTL2     mclk/3=333KHz
    F9 TO MS# ;     \ MS timing

\ Set DCO to 8 MHz, current use of CPU without leds = 2,56mA
: 8MHZ      ( -- )  \ Baudrate 38K4
    int-off
    10FD c@ 57 c!   \ BCSCTL1   Set dco = 8 mhz
    10FC c@ 56 c!   \ DCOCTL
    00 58 c!        \ UCA0CTL2  DCO on
    81 61 *bis      \ UCA0CTL1  Uart use SMCLK
    D0 62 c!        \ UCA0BR0   8 mhz, baudrate 38400
    00 63 c!        \ UCA0BR1   idem
    06 64 c!        \ UCAMCTL   modulation ucbrsx = 3
    01 61 *bic      \ UCA0CTL   enable USCI
    A550 12A !      \ FCTL2     mclk/17=470KHz flash timing
    7CF TO MS# ;    \ MS timing

\ Set DCO to 16 MHz, current use of CPU without leds = 5,01mA
: 16MHZ     ( -- )  \ Baudrate 38K4
    int-off
    10F9 c@ 57 c!   \ BCSCTL1   Set DCO = 16MHz
    10F8 c@ 56 c!   \ DCOCTL
    0000 58 c!      \ DCO on
    0081 61 *bis    \ UCA0CTL   Uart use smclk
    00A0 62 c!      \ UCA0BR0   16 mhz, baudrate 38400
    0001 63 c!      \ UCA0BR1
    000C 64 c!      \ UCAMCTL   modulation ucbrsx = 6
    0001 61 *bic    \ UCA0CTL   enable USCI
    A562 12A !      \ FCTL2     mclk/34=470KHz
    F9F TO MS# ;    \ MS timing

: BLINKLEDS ( -- )    41 21 *bis  64 ms  41 21 *bic ;

\ Use BLINK 12KHZ or BLINK 8MHZ to test different frequency's
\ Always return to 16 MHz so the system keeps on communicating!
: BLINK     ( ccc -- )
    41 22 *bis              \ P1DIR  P1.0 & P1.6 are outputs with leds
    10 ms  ' execute        \ Wait and set new system frequency
    dm 10 0 do              \ Loop 10 times
        blinkleds  1770 ms  \ Blink leds and wait 6 seconds
    loop  16mhz ;           \ Return to 16 MHz

shield CLOCKS\  freeze
