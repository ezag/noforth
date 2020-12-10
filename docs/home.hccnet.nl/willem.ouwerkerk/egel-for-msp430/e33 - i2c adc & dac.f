(* E33 - For noForth C&V 200202: bitbang I2C on MSP430G2553 using port-1.
  I2C analog input and output using external pull-ups.

  Connect the I2C-print from the Forth users group or any other module
  with a PCF8574 and PCF8591, P1.7 to SDA and P1.6 to SCL, note that 
  two 10k pullup resistors has te be mounted and jumper P1.6 to
  the green led has to be removed, that's it.
  Default PCF8591 address = 94  - I2C-bus identification address 2

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
\ This flag is set when DAC was used. Set to zero 
\ when DAC has to be off during ADC conversions!
value DAC?  ( -- vlag )         \ Keep DAC active if true

\ Read ADC input '+n', 'u' is the result of the conversion.
: ADC       ( +n -- u )
    3 and dac? 40 and or  94 {i2write \ Send dev. write address
    {i2read)   i2in drop  i2in} ;   \ repeated start, read fresh ADC value

\ Set DAC-output the a value that matches 'u'.
: DAC       ( u -- )
    true to dac?                \ DAC active
    40 94 {i2write  i2out} ;    \ send dev. write address & control byte

hex
\ LED output routine for PCF8574(a) chips 042 = device address 1 of a PCF8574
: >LEDS     ( b -- )     invert  42 {i2write  i2stop} ;
: FLASH     ( -- )       FF >leds 100 ms  00 >leds 100 ms ;

: ANALOG    ( -- )                      \ show the use off ADC/DAC
    setup-i2c  flash                    \ Initialise I2C
    true to dac?                        \ DAC is used
    begin
        0 adc                           \ read ADC input 0
        dup invert dac  >leds           \ inverted to DAC normal to leds
    key? until ;

shield PCF8591\  freeze

\ End
