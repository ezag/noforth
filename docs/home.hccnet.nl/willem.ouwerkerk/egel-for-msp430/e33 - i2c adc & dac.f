(* E33 - For noForth C&V2553 lp.0, bitbang I2C on MSP430G2553 using port-1.
   I2C analog input and output using external pull-ups.

  Connect the I2C-print from the Forth users group or any other module
  with a PCF8574 and PCF8591, P1.7 to SDA and P1.6 to SCL, note that 
  two 10k pullup resistors has te be mounted, that's it
  094 = PCF8591 I2C-bus identification address 2
 *)

hex
\ This flag is set when DAC was used. Set to zero 
\ when DAC has to be off during ADC conversions!
value DAC?  ( -- vlag )                 \ Keep DAC active if true

\ Read ADC input '+n', 'u' is the result of the conversion.
: ADC       ( +n -- u )
    94 i2write                      \ send dev. write address
    03 and  dac? 40 and  or i2out   \ select wanted input
    i2read)                         \ send chip read address
    i2in  i2ack  drop               \ throw old ADC value away
    i2in  i2nack  i2stop ;          \ get fresh conversion, ready

\ Set DAC-output the a value that matches 'u'.
: DAC       ( u -- )
    true to dac?                    \ DAC active
    94 i2write                      \ send dev. write address
    40 i2out                        \ send control byte and
    i2out  i2stop ;                 \ then databyte, ready

hex
\ Output routine for PCF8574(a) chips 042 = device address 1 of a PCF8574
: !BYTE     ( b a -- )   i2write  i2out  i2stop ;
: >LEDS     ( b -- )     invert  042 !byte ;
: FLASH     ( -- )       FF >leds 100 ms  00 >leds 100 ms ;

: ANALOG    ( -- )                  \ show the use off ADC/DAC
    setup-i2c  flash                \ Initialise I2C
    true to dac?                    \ DAC is used
    begin
        0 adc                       \ read ADC input 0
        dup invert dac  >leds       \ inverted to DAC normal to leds
    key? until ;

shield PCF8591\  freeze

\ End
