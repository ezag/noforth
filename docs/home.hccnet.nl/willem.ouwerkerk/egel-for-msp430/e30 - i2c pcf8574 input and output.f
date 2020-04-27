(* E30 - For noForth C&V2553 lp.0, bitbang I2C on MSP430G2553 using port-1.
  I2C input & output with a PCF8574 using external pull-ups

  Connect the I2C-print from the Forth users group or any other module
  with a PCF8574 and 8 leds and connect the power lines, P1.7 to SDA and
  P1.6 to SCL, note that two pullup resistors has te be mounted, that's it 
  For RUNNER2 and SHOW we need a second PCF8574 with eight switches. 
 *)

hex
\ Output routine for PCF8574(a) chips
\ 042 Is address 1 of output chip, 040 is address 0 of input chip
\ When using the PCF8574A these are, output: 072 and input: 070
: !BYTE     ( b a -- )  i2write  i2out  i2stop ;
: >LEDS     ( b -- )    dup 029 c!  invert 042 !byte ;
: FLASH     ( -- )      FF >leds 100 ms  00 >leds 100 ms ;

: RUNNER1    ( -- )             \ Show a running light on the leds
    setup-i2c  flash
    begin
        8 0 do  1 i lshift >leds  50 ms  loop  
    key? until 
    0 >leds ;

: @BYTE     ( a -- b )  i2read  i2in  i2nack  i2stop ;

( The second I2C application is a running light with variable speed )
: 10MS      ( u -- )        0 ?do  0A ms  loop ;
: INPUT     ( -- +n )       040 @byte 0FF xor ;

: RUNNER2   ( -- )              \ Show a running light on leds
    setup-i2c  flash
    begin
        8 0 do
            1 i lshift >leds  input 10ms
        loop  
    key? until  0 >leds ;

: SHOW      ( -- )              \ Show keypresses on leds
    setup-i2c  flash
    begin  input >leds  key? until  0 >leds ;
  
shield 8574\  freeze

( End )
