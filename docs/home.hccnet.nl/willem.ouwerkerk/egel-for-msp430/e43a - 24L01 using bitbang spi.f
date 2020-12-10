(* E43 - For noForth C&V 200202: hardware SPI on MSP430G2553 using port-1 & port-2.
   SPI i/o interfacing the nRF24L01 with two Launchpad boards and/or Egel kits

  Connect the SPI lines of USCIB P1.5=CLOCKPULSE, P1.6=DATA-IN, P1.7=DATA-OUT
  P1.4=CSN,  P2.3=CE of the nRF24L01. On the Egel kit it's just putting the
  module in the connector marked nRF24L01!!
  Do the same with the other board. The program is really simple, the sender
  sens a number, the receiver gets it and increases it by one. The data is 
  then sent back. Both the transmitter and receiver display the lost packets 
  too.The receiver also toggle the red led with each action.

  Note that decoupling very important right near the nRF24l01 module. The
  Egel kit vsn-2 has an extra 22uF near the power connections. The Launchpad
  and the Egel kit vsn-1 need an extra 10uF decoupling!!!

  More info on page 445 of SLAU144J.PDF  Configuration of the pins on 
  page 49 of SLAS735J.PDF

  The user words are: CHECK  |  CONTROL  LAMP     |  NRF-SEND  NRF-REC  |
                             |  REMOTE  RECEIVER  |

  SPI bitbang master & slave

                     MSP430G2xx3
                  -----------------
              /|\|              XIN|-
               | |                 |
               --|RST          XOUT|-
                 |                 |
           IRQ ->|P2.5         P1.7|-> Data Out (UCB0SIMO)
                 |                 |
            CE <-|P2.3         P1.6|<- Data In (UCB0SOMI)
                 |                 |
           CSN <-|P1.4         P1.5|-> Serial Clock Out (UCB0CLK)
 
  Authors: Willem Ouwerkerk and Jan van Kleef october 2014

  Launchpad documentation for software SPI
  
P1 & P2 are used for interfacing the nRF24L01+
P2.3  - CE              08      \ Device enable high  x1=Enable
P2.5  - IRQ                     \ Active low output   x0=Interrupt
P1.4  - CSN             10      \ SPI enable low      x1=Select
P1.5  - CLOCKPULSE      20      \ Clock               x1=Clock
P1.6  - DATA-IN         40      \ Data bitstream in   x0=Miso
P1.7  - DATA-OUT        80      \ Data bitstream out  x1=Mosi

P1.0  - Led red
P1.6  - Led green
P1.3  - Switch S2

Used register adresses:
020 = P1IN      - Input register
021 = P1OUT     - Output register
022 = P1DIR     - Direction register
027 = P1REN     - Resistance on/off
029 = P2OUT     - Output register
02A = P2DIR     - Direction register
02E = P2SEL     - Configuration register 1
02F = P2REN     - Resistance on/off
 *)

hex
: RED-ON    01 21 *bis ;    : RED-OFF   01 21 *bic ;

                    ( Bitbang SPI interface to nRF24L01 )

: SPI-SETUP         ( -- )
    08 2A *bis      \ P2DIR  P2.3  CE for nRF24L01
    20 2A *bic      \ P2DIR  P2.5  IRQ for nRF24L01
    B0 22 c!        \ P1DIR  P1.4 to P1.7 for SPI
    40 27 *bis      \ P1REN  P1.6 with pullup resistor
    40 21 *bis      \ P1OUT
    08 29 *bic      \ P2OUT  P2.3   CE = 0
    10 21 *bis      \ P1OUT  P1.4  CSN = 1
    20 21 *bic ;    \ P1OUT  P1.5  CLK = 0

: IO-SETUP          ( -- )
    01 22 *bis      \ P1DIR  P1.1 & P1.6 output
    01 21 *bic      \ P1OUT  Outputs P1.0 off
    08 22 *bic      \ P1DIR  P1.3 input
    08 27 *bis      \ P1REN  Resistor on
    08 21 *bis ;    \ P1OUT  With pullup

: CLOCK        ( -- )      20 21 *bis  20 21 *bic ;       \ P1OUT  SPI clock
: ACTIVATE     ( -- )      10 21 *bic ;                   \ P1OUT  SPI on, CSN=low
: DEACTIVATE   ( -- )      10 21 *bis ;                   \ P1OUT  SPI off, CSN=high
: TRANSMIT     ( -- )      08 29 *bis  noop  08 29 *bic ; \ P2OUT  Transmit pulse on CE

\ Write a bit to the SPI-bus, read abit from the SPI-bus
: WRITE-BIT    ( b -- )    80 and if 80 21 *bis else 80 21 *bic then ; \ P1OUT
: READ-BIT     ( -- 0|1 )  40 20 bit* 0<> 1 and  clock ;  \ P1IN
 
: SPI-OUT           ( b -- )            \ Write b to SPI-bus
    8 0 do   dup write-bit  clock  2*  loop  drop ;

: SPI-IN            ( -- b )            \ Read b from SPI-bus
    0  8 0 do  2*  read-bit or  loop ;

: SPI-I/O           ( b1 -- b2 )        \ Read and write at SPI-bus
    0  8 0 do
        >r  dup write-bit  2*  
        r> 2*  read-bit or
    loop
    nip ;

                ( Read and write to and from nRF24L01 )

: RMASK    ( b1 -- b2 )    1F and ;
: WMASK    ( b1 -- b2 )    1F and  20 or ;

\ The first written byte returns internal status always
\ It is saved in the value STATUS using SPI-COMMAND
VALUE STATUS
: GET-STATUS    ( -- s )    activate  FF spi-i/o  deactivate ;
: SPI-COMMAND   ( c -- )    activate  spi-i/o to status ;

\ Reading and writing to registers in the 24L01
: READ-REG      ( r -- d )  rmask spi-command  spi-in  deactivate ;
: WRITE-REG     ( d r -- )  wmask spi-command  spi-out deactivate ;
: .REG          ( r -- )    read-reg . ;

\ Read and write the communication addresses, of pipe-0 default: E7E7E7E7E7
: READ-ADDR     ( trxa -- ) rmask spi-command  5 0 do spi-in  loop  deactivate ;
: WRITE-ADDR    ( trxa -- ) wmask spi-command  5 0 do spi-out loop  deactivate ;
: .PIPE-ADDR    ( r -- )    read-addr 5 0 do  u.  loop ; ( o.a. 0A, 0B, 10 )

                ( nRF24L01 control commands and setup )

\ Empty RX or TX data pipe
: FLUSH-RX      ( -- )      E2 spi-command deactivate ;
: FLUSH-TX      ( -- )      E1 spi-command deactivate ;
: RESET         ( -- )      70 07 write-reg ;
: >CHANNEL      ( +n -- )   05 write-reg ;      \ Change/restore RF-channel
: >SPEED        ( flag -- ) 06 write-reg ;      \ 26 = 250kbps, full power

: SETUP24L01    ( -- )
    spi-setup  -1 to status  io-setup
    64 ms
    3F 01 write-reg       \ Auto Ack all pipes
    03 02 write-reg       \ Pipe-0 & Pipe 1 on
    03 03 write-reg       \ Five byte address
    5F 04 write-reg       \ 15 retry's 1500 us
    70 >channel           \ channel #112
    07 >speed             \ 1 Mbps, max. power
    01 11 write-reg       \ 1 bytes payload in P0
    01 12 write-reg       \ 1 bytes payload in P1
    flush-tx
    flush-rx
    0C 00 write-reg       \ Enable CRC, 2 bytes, power down?
    reset  red-off ;      \ Reset flags

\ Elementary command set for the nRF24L01
: READ-RX       ( -- )      61 spi-command  spi-in deactivate ; \ Receive
: WRITE-TXA     ( c -- )    A0 spi-command spi-out deactivate ; \ Send with Ack check
: PLOST     ( -- b ) 08 read-reg F0 and 10 / ;
: .LOST     ( -- )   ch L emit 08 read-reg 0F and 1 .r 2 spaces ;   \ Show resent packages
: .PLOST    ( -- )   ch P emit  plost 1 .r space ;      \ Show lost packets

\ A variaty of tests for the status of the receiver and transmitter
: RX?           ( -- f )    07 read-reg 40 and 0<> ;    \ Data received
: TX?           ( -- f )    07 read-reg 20 and 0<> ;    \ Ack received
: FIFO-EMPTY?   ( -- f )    17 read-reg 01 and 0<> ;    \ Pipeline empty
: FIFO-FULL?    ( -- f )    17 read-reg 01 and 0= ;     \ Pipeline full
: MAXRETRY?     ( -- f )    07 read-reg 10 and 0<> ;    \ Transmit failed

                    ( Send and receive commands for nRF24L01 )

: WRITE-MODE    ( -- )      
    08 29 *bic                          \ P2OUT  CE low, receive mode off
    0E 00 write-reg                     \ Power up module as transmitter
    reset ;

: READ-MODE     ( -- )      
    0F 00 write-reg                     \ Power up module as receiver
    08 29 *bis ;                        \ P2OUT  Enable receive mode

: .ACK          ( -- )                  \ Print Ack delay time
    0 <# # # ch A hold #> type space ;

: ACK?          ( -- )                  \ Wait for Ack
    100 0 do 
        tx? if                          \ Ack received?
            i .ack  unloop exit         \ Yes, show when
        then 
    loop  FF .ack ;

: XEMIT)        ( c -- )                \ Send onebyte payload
    write-txa  1 ms  transmit  ack? ;   \ Send char

: XEMIT         ( c -- )
    begin
        dup xemit)                      \ Send payload
    tx? 0= while                        \ No Ack?
        reset  ch - emit                \ Reset & show failure
        flush-tx   70 >channel          \ Empty pipeline, clear packet loss
    repeat
    drop  reset ;

: XKEY          ( -- c )
    begin  rx? until                    \ Wait for char
    read-rx                             \ Read char
    reset ( 1 ms ) flush-rx ;           \ Empty pipeline


                            ( nRF24L01 demos )

: PRIVATE1      ( -- ) 
    setup24L01
    F0 F0 F0 F0 E1 0A write-addr        \ Receive address P0
    F0 F0 F0 F0 D2 0B write-addr        \ Receive address P1
    F0 F0 F0 F0 E1 10 write-addr        \ Transmit address
    get-status .  100 ms ;              \ Print status & wait

: PRIVATE2      ( -- )
    setup24L01
    F0 F0 F0 F0 D2 0A write-addr        \ Receive address P0
    F0 F0 F0 F0 E1 0B write-addr        \ Receive address P1
    F0 F0 F0 F0 D2 10 write-addr        \ Transmit address
    get-status .  100 ms ;              \ Print status & wait


\ Test if other 2.4GHz transmitters are active on selected frequency
\ The program prints a one if a carrier is detected, a zero otherwise.
: CHECK         ( -- )
    private1
    begin 
        read-mode  1 ms                 \ Receive on, wait
        09 read-reg 1 .R  write-mode    \ Test for carrier on used frequency
    key? until ;


\ Example-1  One way transmitter and receiver

\ Send the character T when S2 is pressed and flash the red led.
: CONTROL       ( -- )
    private1  
    begin
        s? 0= if
            red-on  write-mode  ch T xemit
            50 ms  red-off  50 ms
        then
    key? until ;

\ Toggle both the power output and the red led
: LAMP          ( -- )
    private2  10 2A *bis  10 29 *bic    \ P2DIR, P2OUT
    begin
        read-mode  xkey ch T = if
           10 29 *bix  01 21 *bix       \ P2OUT, P1OUT  
        then
    key? until ;


\ Example-2  A counter on the receiver is displayed on both sides

 ( Send n1 the receiver, response from the receiver is n2 )
: SEND          ( n1 -- n2 ) 
    write-mode                          \ Power up module as transmitter
    cr  xemit   .plost  .lost           \ Send data, show lost packages
    read-mode                           \ Power up as receiver, reset flags
    xkey  ch : emit  dup .              \ Read and show response
    08 29 *bic                          \ CE low, receive mode off
    red-off                             \ Led off 
    80 ms ;                             \ Wait

 ( Receive data from transmitter, add 1 to it and send back ) 
: RECEIVE         ( -- )       
    cr read-mode                        \ Power up module as receiver
    xkey                                \ Read
    red-on                              \ Led on      
    write-mode                          \ Power up module as transmitter
    1+  dup xemit)                      \ Increase, make copy and send as responce
    .plost .lost  ch : emit  .          \ Show lost packages and data
    red-off ;                           \ Led off 

: XWAIT         ( -- )                  \ Wait for RF data, printing dots
    read-mode  begin  10 ms ch . emit  rx? until ;

\ First nRF24L01 demo, two module communicating on both directions
: NRF-SEND      ( -- )  private1  0  begin  send  key? until  drop ;
: NRF-REC       ( -- )  private2  begin  xwait  receive  key? until ;


\ Example-3  A remote control of a lamp with lamp status feedback

\ ADC on and sample time at 64 clocks
: ADC-SETUP ( -- )
    02 1B0 **bic                \ ADC10CTL0  Clear ENC
    08 04A c!                   \ ADC10AE0   P1.3 = ADC in
    1810 1B0 ! ;                \ ADC10CTL0  Sampletime 64 clocks, ADC on

\ We need to clear the ENC bit before setting a new input channel
: ADC       ( +n -- u )
    02 1B0 **bic                \ ADC10CTL0  Clear ENC
    F000 and 80 or 1B2 !        \ ADC10CTL1  Select input, MCLK/5
    03 1B0 **bis                \ ADC10CTL0  Set ENC & ADC10SC
    begin 1 1B2 bit** 0= until  \ ADC10CTL1  ADC10 busy?
    1B4 @ ;                     \ ADC10MEM   Read result

: LDR           3000 adc 2 rshift ; \ Level at P1.3 as 8-bit value
: FEEDBACK      E4 > if  1 29 *bis  else  1 29 *bic  then ; \ P2OUT
: FEEDBACK?     FF 0 do rx? ?dup if unloop exit then 1 ms loop false ;

: REMOTE    ( -- )
    private1  cr ." Transmitter " 
    01 02A *bis  01 029 *bic        \ P2DIR, P2OUT  Green led off
    begin
        flush-rx
        s? 0= if                    \ MSP S2-button pressed?
            cr  red-on  write-mode  \ Led on, go write
            ch T xemit .plost .lost \ Send T char, show trace info
            read-mode               \ Power up as receiver, reset flags
            feedback? if            \ Data received?
               xkey  dup . feedback \ Read and show light status
            then
            08 029 *bic             \ P2OUT  CE low, receive mode off
            A0 ms  red-off          \ Wait, led off
            begin  s? until         \ Wait until key released
        then
    key? until ;

: RECEIVER  ( -- )
    private2  adc-setup  cr ." Receiver "
    10 02A *bis  10 029 *bis        \ P2DIR, P2OUT  Power on
    100 ms  10 029 *bic             \ P2OUT  Power output off after 256 ms
    begin
        read-mode
        cr xkey  ch T = 10 and 29 *bix  \ P2OUT  Toggle power output
        red-on  30 ms  write-mode 
        ldr dup xemit) .plost .lost     \ Send light status back
        ch : emit  .  10 ms  red-off
    s? 0= until ;

shield 24L01\   freeze

\ End
