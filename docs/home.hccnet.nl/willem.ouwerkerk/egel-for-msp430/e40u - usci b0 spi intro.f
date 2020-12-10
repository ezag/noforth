(* E40U - For noForth C&V 200202: hardware SPI on MSP430G2553 using port-1 & port-2.
   SPI i/o with two Launchpad boards and/or Egel kits

  Connect the SPI lines of USCI-B0 P1.5, P1.6 & P1.7 to same pins on the
  other board. Connect 6 leds to P2 and start the slave on the unit with 
  the led board. More info on page 445 of SLAU144J.PDF Configuration of 
  the pins in page 49 of SLAS735J.PDF
  User words are: SPI-MASTER  SPI-SLAVE1  SPI-SLAVE2

  SPI master & slave

                     MSP430G2xx3
                  -----------------
              /|\|              XIN|-
               | |                 |
               --|RST          XOUT|-
                 |                 |
                 |             P1.7|-> Data Out (UCB0SIMO)
                 |                 |
           LED <-|P1.0         P1.6|<- Data In (UCB0SOMI)
                 |                 |
           Out <-|P1.4         P1.5|-> Serial Clock Out (UCB0CLK)

Used register adresses:
 0020 = P1IN      - Input register
 0021 = P1OUT     - Output register
 0022 = P1DIR     - Direction register
 0026 = P1SEL     - 0C0
 0027 = P1REN     - Resistance on/off
 0041 = P1SEL2    - 0C0
 0029 = P2OUT     - Output register
 002A = P2DIR     - Direction register
 002E = P2SEL     - Configuration register 1
 002F = P2REN     - Resistance on/off
 0120 = WDTCL     - Off already
 0068 = UCB0CTL0  - 00F
 0069 = UCB0CTL1  - 081
 006A = UCB0BR0   - 0A0
 006B = UCB0BR1   - 000
 006C = UCB0CIE   - USCI interrupt enable
 006D = UCB0STAT  - USCI status
 006E = UCB0RXBUF - RX Data
 006F = UCB0TXBUF - TX Data
 0118 = UCB0I2C0A - NC
 011A = UCB0I2CSA - 042
 0001 = IE2       - 000
 0003 = IFG2      - 008 = TX ready, 004 = RX ready
  *)

hex
: MASTER-SETUP  ( -- )
    01 69 *bis      \ UCB0CTL1  Reset USCI
    00 21 c!        \ P1OUT     P1out is all low
    21 22 c!        \ P1DIR     P1dir is P1.0 and P1.6 output
    E0 26 *bis      \ P1SEL     P1.5 P1.6 P1.7 is SPI
    E0 41 *bis      \ P1SEL2
    69 68 *bis      \ UCB0CTL0  Clk=high, MSB first, Master, Synchroon
    80 69 *bis      \ UCB0CTL1  USCI clock = SMClk
    08 6A c!        \ UCB0BR0   Clock is 16Mhz/8 = 2 MHz
    00 6B c!        \ UCB0BR1
    00 6C c!        \ UCB0MCTL  Not used must be zero!
    01 69 *bic      \ UCB0CTL1  Free USCI
    E1 21 *bis      \ P1OUT     Set P1.0, P1.5, P1.6 and P1.7
  ( 10 21 *bis ) ;  \ P1OUT     Clear P1.4

: SLAVE-SETUP   ( -- )
    01 69 *bis      \ UCB0CTL1  Reset USCI
    E0 26 *bis      \ P1SEL     P1.5 P1.6 P1.7 is SPI
    E0 41 *bis      \ P1SEL2
    61 68 C!        \ UCBCTL0   Clock mode, MSB first, synchronous 
    01 69 *bic      \ UCB0CTL1  Free USCI
    20 22 *bic      \ P1DIR     P1.5 = ingang
    begin  20 20 bit* until ; \ P1IN  Master  in SPI mode (clock high)?

\ Master SPI routine
: SPI      ( u1 -- u2 )
    begin  8 3 bit* until  6F c!    \ IFG2  TX?
    begin  4 3 bit* until  6E c@ ;  \ IFG2  RX?

: >SPI      ( u -- )    spi drop ;
: SPI>      ( -- u )    0 spi ;


\ The SPI master send  the loop-index and receives & displays the answer
: SPI-MASTER    ( -- )
    master-setup
    begin
        100 0 do
            cr i u.  i spi u. 50 ms
            stop? if leave  then
        loop
    stop? until ;

: FLASH         ( -- )  -1 029 c! 64 ms  0 029 c! 64 ms ;   \ P2OUT

\ The SPI slave receives data from the master puts it on the leds
\ and sends the same data back, this first example can be made
\ to do something usefull!!
: SPI-SLAVE1     ( -- )
    -1 2A c!  0 2E c!  flash    \ P2DIR, P2SEL
    slave-setup  0 6F c!  0     \ UCB0TXBUF 
    begin
        spi  dup 29 c!          \ P2OUT
    stop? until drop ;

: DEMO-SPI  ( u1 -- u2 )
    begin  4 3 bit* until  6E c@        \ IFG2  RX?
    begin  8 3 bit* until  dup 6F c! ;  \ IFG2  TX?

\ This is the SPI slave demo from TI, it does nothing usefull however
: SPI-SLAVE2     ( -- )
    -1 2A c!  0 2E c!  flash    \ P2DIR, P2SEL
    slave-setup  0 6F c!  0     \ UCB0TXBUF 
    begin
        demo-spi  dup 29 c!     \ P2OUT
    stop? until drop ;

shield SPI\  freeze
 