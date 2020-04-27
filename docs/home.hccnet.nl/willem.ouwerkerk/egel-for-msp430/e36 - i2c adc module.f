(* E36 - For noForth C&V2553 lp.0, bitbang I2C on MSP430G2553 using port-1.
   I2C analog input using a PCF8591 module YL-40 from AliExpress.

  Connect the I2C-module with PCF8591, P1.7 to SDA and P1.6 to SCL, note
  that 090 = PCF8591 I2C-bus identification address 0.
  0 ADC - AIN0 = LDR
  1 ADC - AIN1 = Thermistor
  2 ADC - AIN2 = Free
  3 ADC - AIN3 = Potmeter
  DAC is connected to an output and a green led
  User words are: ADC ( +n -- u ),  DAC  ( u -- ),  ANALOG  ( +n -- ) 
 *)

hex
\ This flag is set when DAC was used. Set to zero 
\ when DAC has to be off during ADC conversions!
value DAC?  ( -- vlag )                 \ Keep DAC active if true

\ Read ADC input '+n', 'u' is the result of the conversion.
: ADC       ( +n -- u )
    90 i2write                      \ send dev. write address
    03 and  dac? 40 and  or i2out   \ select wanted input
    i2read)                         \ send chip read address
    i2in  i2ack  drop               \ throw old ADC value away
    i2in  i2nack  i2stop ;          \ get fresh conversion, ready

\ Set DAC-output the a value that matches 'u'.
: DAC       ( u -- )
    true to dac?                    \ DAC active
    90 i2write                      \ send dev. write address
    40 i2out                        \ send control byte and
    i2out  i2stop ;                 \ then databyte, ready

: ANALOG    ( +n -- )               \ show the use off ADC/DAC
    setup-i2c  >r                   \ Initialise I2C
    true to dac?                    \ DAC is used
    begin
        r@ adc  dup .               \ read ADC input +n
        invert dac                  \ inverted to DAC
    key? until  r> drop ;

shield PCF8591\  freeze

\ End
