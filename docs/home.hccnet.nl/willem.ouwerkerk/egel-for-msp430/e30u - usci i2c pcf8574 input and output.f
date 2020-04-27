(* E30U - For noForth C&V2553 lp.0, USCI I2C on MSP430G2553 using port-1.
  I2C output with a PCF8574 using external pull-ups
  The bitrate values are for an 8 MHz DCO, for 16 MHz they should be doubled.
  This is a better version, the routines work more solid, !BYTE stayes alive 
  always, @BYTE does not hang when using a not exsisting device address.

  The most hard to find data are those for the selection registers.
  To find the data for the selection register of Port-1 here 026 and
  041 you have to go to the "Port Schematics". For P1.6 and P1.7 these
  are page 48 and 49 of SLAS735J.PDF These tables say which function 
  will be on each I/O-bit at a specific setting of the registers.

  Address 026 - P1SEL, port-1 selection register
  Address 041 - P1SEL2, port-1 selection register 2

  A description of USCI as I2C can be found in SLAU144J.PDF from page
  449 to page 473, the register description starts at page 468. The
  UCB0CTL0 register selects the SPI- or I2C-mode we are in.

  Connect the I2C-print from the Forth users group or any other module
  with a PCF8574 and 8 leds and connect the power lines, P1.7 to SDA and
  P1.6 to SCL, note that two 10k pullup resistors has te be mounted and 
  jumper P1.6 to the green led has to be removed, that's it. 
  For RUNNER2 and SHOW we need a second PCF8574 with eight switches. 

 Addresses, Lables and Bit patterns  
 0120    - WDTCL        - Off already
 0026    - P1SEL        - 0C0
 0041    - P1SEL2       - 0C0
 0068    - UCB0CTL0     - 00F
 0069    - UCB0CTL1     - 081
 006A    - UCB0BR0      - 0A0
 006B    - UCB0BR1      - 000
 006C    - UCB0CIE      - USCI interrupt enable
 006D    - UCB0STAT     - USCI status
 006E    - UCB0RXBUF    - RX Data
 006F    - UCB0TXBUF    - TX Data
 0118    - UCB0I2C0A    - NC
 011A    - UCB0I2CSA    - 042
 0001    - IE2          - 000
 0003    - IFG2         - 008 = TX ready, 004 = RX ready
 *)

hex
code INT-OFF  C232 ,  4F00 ,  end-code

: SETUP-I2C ( -- )
    int-off
    C0 026 *bis     \ P1SEL     I2C to pins
    C0 041 *bis     \ P1SEL2
    01 069 *bis     \ UCB0CTL1  reset USCI
    0F 068 c!       \ UCB0CTL0  I2C master
    81 069 c!       \ UCB0CTL1  Use SMclk
    dm 80 06A c!    \ UCB0BR0   Bitrate 100 KHz with 8 MHz DCO
    00 06B c!       \ UCB0BR1
    01 069 *bic     \ UCB0CTL1  Resume USCI
    08 003 *bis ;   \ IFG2      Start with TX buffer empty

\ 04 = wait for data received to RX; 08 = wait for TX to be sent
: i2ready   ( bit -- )
    80  begin
        over 003 bit* if  2drop exit  then  
    1- dup 0= until  true ?abort ;

\ 02 = wait for startcond. to finish; 04 = wait for stopcond. to finish
: I2DONE    ( bit -- )  \ wait until startcond. or stopcond. is done
    80  begin
        over 069 bit* 0= if  2drop exit  then  
    1- dup 0= until  true ?abort ;

: I2START   ( -- )      02 069 *bis ;   \ UCB0CTL1
: I2STOP    ( -- )      04 069 *bis ;   \ UCB0CTL1
: I2OUT1    ( b -- )    06F c!  02 i2done  noop ; \ Send first data to TX
: I2OUT     ( b -- )    06F c!  08 i2ready  noop ; \ TX to shiftreg.
: I2IN      ( -- b )    04 i2ready  06E c@ ;    \ UCB0RXBUF Read databyte
: I2IN}     ( -- b )    i2stop  i2in  04 i2done ; \ Read last I2C databyte!
: I2STOP}   ( -- )      i2stop  04 i2done ; \ Stop condition & check


: {I2WRITE  ( a -- )        \ Send I2C device address for writing
    2/ 11A c!               \ UCB0I2CSA Set slave address
    12 069 *bis             \ UCB0CTL1  Send start condition
    08 i2ready ;            \ Start cond. sent

: {I2READ   ( a -- )        \ Set and send I2C device address for reading
    2/ 11A c!               \ UCB0I2CSA  Set slave address
    10 069 *bic  i2start    \ UCB0CTL1   Setup read & start
    08 i2ready  02 i2done ; \ Start condition sent & ack received?


\ Send data 'b' to a PCF8574 with dev. address 'a'. 
\ The base adress of a PCF8574 is 040, for PCF8574A it is 070
\ When using the PCF8574A these are, output: 072 and input: 070
: !BYTE     ( b a -- )
    {i2write  i2out1  i2stop} ; \ Address device, sent byte, ready

\ Read data 'b' from a PCF8574 with dev. address 'a' 
\ The base adress of a PCF8574 is 040, for PCF8574A it is 070
: @BYTE     ( a -- b )      {i2read  i2in} ;


\ Demo programs
: >LEDS     ( b -- )     invert  042 !byte ;
: FLASH     ( -- )       FF >leds 100 ms  00 >leds 100 ms ;

: RUNNER1    ( -- )             \ Show a running light on the leds
    setup-i2c  flash
    begin
        8 0 do  1 i lshift >leds  50 ms  loop
    key? until  0 >leds ;

( The second I2C application is a running light with variable speed )
: 10MS      ( u -- )        0 ?do  0A ms  loop ;
: INPUT     ( -- +n )       40 @byte invert FF and ;

: RUNNER2   ( -- )              \ Show a running light on leds
    setup-i2c  flash
    begin
        8 0 do  1 i lshift >leds  input 10ms  loop
    key? until  0 >leds ;

( The third application a copy of a keypress on the leds )
: SHOW      ( -- )              \ Show keypresses on leds
    setup-i2c  flash  begin  input >leds  key? until  0 >leds ;

setup-i2c   shield HWI2C\   freeze

\ End
