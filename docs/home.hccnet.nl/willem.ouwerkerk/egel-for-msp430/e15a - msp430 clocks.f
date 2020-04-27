(* For noForth C&V2553 lp.0 routines for different (S)MCLK frequencies.
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

\ Redefinition of MS to keep it working with this example
\ Due to all the different used frequencies
value MS)
: MS        ( u -- )
    0 ?do  ms) 0 ?do loop  loop ;

\ Activate VLOCLK as system clock for the MSP430 Current AM~0,030mA
\ Note: No baudrate is selected here!
: 12KHZ     ( -- )
    int-off
    0000 0057 c!    \ BCSCTL1   Switch low freq. mode on
    0020 0053 c!    \ BCSCTL3   12kHz VLOCLK on
    00C8 0058 c!    \ BCSCTL2   SMCLK & MCLK are VLOCLK
    0000 TO MS) ;

\ Do not use flash programming or erasing its not valid on this frequency!
\ Set system clock to 32 KHz, current use of CPU without leds AM~0,040mA
\ Note that 9600B is the maximal stable baudrate!
: 32KHZ     ( -- )
    int-off  2 ms
    0000 0057 c!    \ BCSCTL1   Switch low freq. mode on
    000C 0053 c!    \ BCSCTL3   32kHz with 12pF
    begin           \ LFXT osc. running?
        02 002 *bic \ IFG1      Clear bit 2
        noop  noop  \ Wait, Bit 2 remains clear
    02 002 bit* 0= until \ when osc. runs fine!
    00C8 0058 c!    \ BCSCTL2   LFXT1CLK on SMCLK
    0041 0061 c!    \ UCA0CTL1  Uart use ACLK
    0003 0062 c!    \ UCA0BR0   32 KHz, baudrate 9600
    0000 0063 c!    \ UCA0BR1
    0006 0064 c!    \ UCA0CTL0  modulation ucbrsx = 3
    0001 0061 *bic  \ UCA0CTL1  enable USCI
    A500 012A !     \ FCTL2     mclk/1=32KHz
    0000 TO MS) ;

\ Set DCO to 1 MHz, current use of CPU without leds AM~0,4mA
: 1MHZ      ( -- )  \ Baudrate 9600b
    int-off  2 ms
    10FF c@ 0057 c! \ BCSCTL1   Set DCO = 1MHz
    10FE c@ 0056 c! \ DCOCTL
    0000 0058 c!    \ UCA0CTL2  DCO on
    0081 0061 *bis  \ UCA0CTL1  Uart use SMCLK
    0068 0062 c!    \ UCA0BR0   1 mhz, baudrate 9600
    0000 0063 c!    \ UCA0BR1   idem
    0002 0064 c!    \ UCA0CTL0  modulation ucbrsx = 1
    0001 0061 *bic  \ UCA0CTL   enable USCI
    A542 012A !     \ FCTL2     mclk/3=333KHz
    0038 TO MS) ;   \ MS timing

\ Set DCO to 8 MHz, current use of CPU without leds AM~3,000mA
: 8MHZ      ( -- )  \ Baudrate 9600B
    int-off  2 ms
    10FD c@ 0057 c! \ BCSCTL1   set dco = 8 mhz
    10FC c@ 0056 c! \ DCOCTL
    0000 0058 c!    \ UCA0CTL2  DCO on
    0081 0061 *bis  \ UCA0CTL1  Uart use SMCLK
    0041 0062 c!    \ UCA0BR0   8 mhz, baudrate 9600
    0003 0063 c!    \ UCA0BR1   idem
    0004 0064 c!    \ UCAMCTL   modulation ucbrsx = 2
    0001 0061 *bic  \ UCA0CTL   enable USCI
    A550 012A !     \ FCTL2     mclk/17=470KHz flash timing
    01C0 TO MS) ;   \ MS timing

\ Set DCO to 16 MHz, current use of CPU without leds AM~6,000mA
: 16MHZ     ( -- )  \ Baudrate 9600B
    int-off  2 ms
    10F9 c@ 0057 c! \ BCSCTL1   Set DCO = 16MHz
    10F8 c@ 0056 c! \ DCOCTL
    0000 0058 c!    \ DCO on
    0081 0061 *bis  \ UCA0CTL   Uart use smclk
    0082 0062 c!    \ UCA0BR0   16 mhz, baudrate 9600
    0006 0063 c!    \ UCA0BR1
    000C 0064 c!    \ UCAMCTL   modulation ucbrsx = 6
    0001 0061 *bic  \ UCA0CTL   enable USCI
    A562 012A !     \ FCTL2     mclk/34=470KHz
    0380 TO MS) ;   \ MS timing

: FLASHLEDS ( -- )    41 21 *bis  64 ms  41 21 *bic ;

\ Use FLASH 12KHZ or FLASH 16MHZ to test different frequency's
\ Always return to 8 MHz so the system keeps on communicating!
: FLASH     ( ccc -- )
    10 ms  ' execute        \ Wait and set new system frequency
    dm 10 0 do              \ Loop 10 times
        flashleds  1800 ms  \ Flash leds and wait 6 seconds
    loop  8mhz ;            \ Return to 8 MHz

shield CLOCKS\  freeze
