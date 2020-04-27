(* E31 - For noForth C&V2553 lp.0, bitbang I2C on MSP430G2553 using port-1.
  I2C input, output and EEPROM with a PCF8574 using external pull-ups.

  Connect the I2C-print from the Forth users group or any other module
  with an EEPROM, a PCF8574 and 8 leds and a PCF8574 with 8 switches.
  Connect the power lines, P1.7 to SDA and P1.6 to SCL.
  Note that two 10k pullup resistors has te be mounted, that's it 
 *)

hex
\ In- and output routine for PCF8574(a) chips
: !BYTE     ( b a -- )      i2write  i2out  i2stop ;
: @BYTE     ( a -- b )      i2read   i2in  i2nack  i2stop ;

( The third I2C application, filling and displaying EEPROM contents )
: INPUT     ( -- +n )       40 @byte invert FF and ;
: >LEDS     ( byte -- )     invert  42 !byte ;
: FLASH     ( -- )          FF >leds 100 ms  00 >leds 100 ms ;


\ Reading and writing to EEPROM type 24C02

\ Read data 'x' from EEPROM address 'a'.
: EC@       ( a -- x )
    A4 i2write  i2out           \ Adress dev. 'a' & send read address
    i2read)  i2in  i2nack  i2stop ; \ Give repeated start & read data

\ Write 'x' to EEPROM address 'a'
: EC!       ( x a -- )
    A4 i2write  i2out  i2out  i2stop ; \ Send address- and databyte


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

: EEPROM-DEMO   ( -- )          \ Example of I2C EEPROM use
    setup-i2c  
    flash  fill-eeprom  flash   \ Show startup & fill EEPROM
    begin  show-eeprom  key? until ; \ Display data until keypress

shield EEPROM\  freeze

\ End
