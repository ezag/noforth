(* E31 - For noForth C&V 200202: I2C on MSP430G2553 using port-1.
  I2C input, output and EEPROM with a PCF8574 using external pull-ups.

  Connect the I2C-print from the Forth users group or any other module
  with an EEPROM, a PCF8574 and 8 leds and a PCF8574 with 8 switches.
  Connect the power lines, P1.7 to SDA and P1.6 to SCL.
  Note that two 10k pullup resistors has te be mounted and jumper P1.6
  to the green led has to be removed, that's it.

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

hex  v: inside also
\ In- and output routine for PCF8574(a) chips
: !BYTE     ( b a -- )  {i2write  i2stop} ;
: @BYTE     ( a -- b )  {i2read  i2in} ;

( The third I2C application, filling and displaying EEPROM contents )
: INPUT     ( -- +n )       40 @byte FF xor ;
: >LEDS     ( byte -- )     invert  42 !byte ;
: FLASH     ( -- )          FF >leds 100 ms  00 >leds 100 ms ;


( Reading and writing to EEPROM type 24C02 )
\ A4 = EEPROM I2C bus address

\ Read data 'x' from EEPROM address 'a'.
: EC@       ( a -- x )
    A4 {i2write {i2read) i2in} ; \ Address EE & rep. start & read data

\ Write 'x' to EEPROM address 'a'
: EC!       ( x a -- )
    A4 {i2write  i2out} ;       \ Address EE & write data


\ EEPROM demo
: FILL-EEPROM    ( -- )         \ Fill EEPROM with sample from input
    1                           \ First used databyte is address 1
    64 0 do                     \ Take 100 samples ( ~10 sec. )
        input over ec!          \ Set switch position in eeprom
        input  >leds  1+  80 ms \ Increase address counter & wait
    loop
    0 ec! ;                     \ Save data-length on address 0

: SHOW-EEPROM   ( -- )          \ Show data samples from EEPROM
    0 ec@  1 do                 \ Get length
        i ec@ >leds  50 ms      \ Print data, one by one & wait
    loop ;

: EEPROM-DEMO   ( -- )              \ Example of I2C EEPROM use
    setup-i2c  flash fill-eeprom flash \ Show startup & fill EEPROM
    begin  show-eeprom  key? until ;   \ Display data until keypress

v: fresh
shield EEPROM\  freeze

\ End
