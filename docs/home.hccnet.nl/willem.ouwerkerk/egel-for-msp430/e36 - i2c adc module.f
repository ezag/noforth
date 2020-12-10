(* E36 - For noForth C&V 200202: I2C on MSP430G2553 using port-1.
   I2C analog input using a PCF8591 module YL-40 from AliExpress.

  Connect the I2C-module with PCF8591, P1.7 to SDA and P1.6 to SCL and 
  jumper P1.6 to the green led has to be removed, that's it., note
  that 090 = PCF8591 I2C-bus identification address 0 .

  0 ADC - AIN0 = LDR
  1 ADC - AIN1 = Thermistor
  2 ADC - AIN2 = Free
  3 ADC - AIN3 = Potmeter
  DAC is connected to an output and a green led
 *)

hex
\ This flag is set when DAC was used. Set to zero 
\ when DAC has to be off during ADC conversions!
value DAC?  ( -- vlag )     \ Keep DAC active if true

\ Read ADC input '+n', 'u' is the result of the conversion.
: ADC       ( +n -- u )
    3 and dac? 40 and or  90 {i2write \ send dev. write address
    {i2read)  i2in drop  i2in} ;    \ repeated start, get fresh ADC reading 

\ Set DAC-output the a value that matches 'u'.
: DAC       ( u -- )
    true to dac?            \ DAC active
    40 90 {i2write i2out} ; \ send dev. write address & control byte

: ANALOG    ( +n -- )       \ show the use off ADC/DAC
    setup-i2c  >r           \ Initialise I2C
    true to dac?            \ DAC is used
    begin
        r@ adc  dup .       \ read ADC input +n
        invert dac          \ inverted to DAC
    key? until  r> drop ;

shield YL-40\  freeze

\ End
