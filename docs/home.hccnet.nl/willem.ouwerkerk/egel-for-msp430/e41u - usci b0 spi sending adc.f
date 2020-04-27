(* E41U - For noForth C&V2553 lp.0, hardware SPI on MSP430G2553 using port-1 & port-2.
   SPI i/o with two Launchpad boards and/or Egel kits

  Connect the SPI lines of USCIB P1.5, P1.6 & P1.7 to same pins on the
  other board. Connect 6 leds to P2 and start the slave on the unit with 
  the led board. More info on page 445 of SLAU144J.PDF Configuration of 
  the pins in page 49 of SLAS735J.PDF

  SPI master & slave
 
                     MSP430G2xx3
                  -----------------
              /|\|              XIN|-
               | |                 |
               --|RST          XOUT|-
                 |                 |
           ADC ->|P1.3         P1.7|-> Data Out (UCB0SIMO)
                 |                 |
           LED <-|P1.0         P1.6|<- Data In (UCB0SOMI)
                 |                 |
           Out <-|P1.4         P1.5|-> Serial Clock Out (UCB0CLK)

  * Port-2 must be wired to 8 leds, placed on the launchpad experimenters kit.
  Wire P2.0 to P2.7 to the anode of eight 3mm leds placed on the breadboard 
  the pinlayout can be found in the hardwaredoc of the launchpad. Connect
  all kathodes to each other, and connect them to ground using a 100 Ohm 
  resistor. Only the MASTER gets a 4k7 potmeter connected to P1.3.

  0020 = P1IN      - Input register
  0021 = P1OUT     - Output register
  0022 = P1DIR     - Direction register
  0026 = P1SEL     - 0C0
  0027 = P1REN     - Resistance on/off
  0041 = P1SEL2    - 0C0
  0029 = P2OUT     - port-2 output with 8 leds
  002A = P2DIR     - port-2 direction register
  002E = P2SEL     - port-2 selection register 
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
  004A = ADC10AE0  - ADC analog enable 0
  01B0 = ADC10CTL0 - ADC controle register 0
  01B2 = ADC10CTL1 - ADC controle register 1
  01B4 = ADC10MEM  - ADC memory
 *)

hex
: MASTER-SETUP  ( -- )
    01 069 *bis     \ UCB0CTL1  Reset USCI
    00 021 c!       \ P1OUT     P1out is all low
    21 022 c!       \ P1DIR     P1dir is P1.0 and P1.6 output
    E0 026 *bis     \ P1SEL     P1.5 P1.6 P1.7 is SPI
    E0 041 *bis     \ P1SEL2
    69 068 *bis     \ UCB0CTL0  Clk=high, MSB first, Master, Synchroon
    80 069 *bis     \ UCB0CTL1  USCI clock = SMClk
    08 06A c!       \ UCB0BR0   Clock is 16Mhz/8 = 2 MHz
    00 06B c!       \ UCB0BR1
    00 06C c!       \ UCB0MCTL  Not used must be zero!
    01 069 *bic     \ UCB0CTL1  Free USCI
    E1 021 *bis     \ P1OUT     Set P1.0, P1.5, P1.6 and P1.7
  ( 10 021 *bis ) ; \ P1OUT     Clear P1.4

: SLAVE-SETUP   ( -- )
    01 069 *bis     \ UCB0CTL1  Reset USCI
    E0 026 *bis     \ P1SEL     P1.5 P1.6 P1.7 is SPI
    E0 041 *bis     \ P1SEL2
    61 068 C!       \ UCBCTL0   Clock mode, MSB first, synchronous 
    01 069 *bic     \ UCB0CTL1  Free USCI
    20 022 *bic     \ P1DIR     P1.5 = ingang
    begin  20 020 bit* until ; \ P1IN  Master  in SPI mode (clock high)?

\ Master SPI routine
: SPI      ( u1 -- u2 )
    begin  08 003 bit* until  06F c!    \ IFG2, UCB0TXBUF  TX?
    begin  04 003 bit* until  06E c@ ;  \ IFG2, UCB0RXBUF  RX?

: >SPI      ( u -- )    spi drop ;
: SPI>      ( -- u )    0 spi ;


\ Slave module
: >LEDS		( b -- )	029 c! ;    \ P2OUT
: FLASH     ( -- )  	-1 >leds 64 ms  0 >leds 64 ms ;

\ ADC on and sample time at 64 clocks
: ADC-SETUP ( -- )
    02 1B0 *bic               \ ADC10CTL0  Clear ENC
    08 04A c!                 \ ADC10AE0   P1.3 = ADC in
    1810 1B0 ! ;              \ ADC10CTL0  Sampletime 64 clocks, ADC on

\ We need to clear the ENC bit before setting a new input channel
: ADC       ( +n -- u )
    02 1B0 *bic               \ ADC10CTL0  Clear ENC
    F000 and 80 or 1B2 !      \ ADC10CTL1  Select input, MCLK/5
    03 1B0 *bis               \ ADC10CTL0  Set ENC & ADC10SC
    begin 1 1B2 bit* 0= until \ ADC10CTL1  ADC10 busy?
    1B4 @ ;                   \ Read result

: POTMETER      3000 adc ;	  \ Read level at P1.3
: SCALE         4 rshift ;    \ Scale down to 6 bits

\ The spi slave receives ADC data from the master and puts it on the leds
\ and sends a counter back.
: SLAVE      ( -- )
    -1 02A c!  0 02E c!  flash  \ P2DIR, P2SEL
    slave-setup  0 06F c!  0    \ UCB0TXBUF
    begin
        dup spi >leds  1+
    key? until  drop ;

\ The spi master sends the P1.3 analog value and 
\ receives a counter from the spi slave
: MASTER 	( -- )
    adc-setup  master-setup
    begin
        cr ." Adc: "  potmeter dup .  scale spi 
           ."  Count: "  dup .  >leds  50 ms
    stop? until ;

shield SPI\  freeze
 