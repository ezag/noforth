(* Bitbang I2C routines for MSP430 code variant, without assembler!!
   This implementation is without clockbit stretching!!!
   Basic building blocks, the complete documented code in 
   the file: e37 - i2c bitbang basics at p1 (asm).f

  THIS FILE IS FOR DIRECT USE ONLY, AND CONTAINS ONLY MINIMAL DOCUMENTATION!

  Connect the I2C-print from the Forth users group or any other module
  with I2C compatible chip{s} and connect the power lines. P1.7 to SDA and
  P1.6 to SCL, note that two 10k pullup resistors has te be mounted, that's it.
  User words: START-BIT  STOP-BIT  ACK-BIT  NACK-BIT  ACK?  BYTE-IN
              (BYTE-OUT  BYTE-OUT  I2C?  SETUP-I2C  >DEV
              I2WRITE?)  I2WRITE  I2READ)  I2READ  POLL

  10 20 - P1IN   Input bits
  10 21 - P1OUT  Output bits
  10 22 - P1DIR  Direction bits
  10 23 - P1IFG  Interrupt flag bits
  10 24 - P1IES  Interrupt edge select bits
  10 25 - P1IE   Interrupt enable bits
  10 26 - P1SEL  Function select bits
  10 27 - P1REN  Resistor enable bits
  10 41 - P1SEL2 Function select-2 bits
 *)

hex
: SETUP-I2C     C0 27 *bic  C0 22 *bis  C0 21 *bis ; \ P1REN, P1DIR, P1OUT

\ Minimal period is 5 us, is about 100 kHz clock
\ 12 is about 5 us at 16MHz
create WAIT  4039 ,  12 ,  8319 , 23FE ,  4130 ,

\ Give I2C start condition
code I2START    ( -- )
    D0B2 ,  40 ,  21 ,  C0B2 ,  40 ,
    22 ,  12B0 ,  wait ,  D0B2 ,
    80 ,  22 ,  C0B2 ,  80 ,
    21 ,  12B0 ,  wait ,  4F00 ,  end-code

\ Give I2C stop condition
code I2STOP     ( -- )
    C0B2 ,  40 ,  21 ,  D0B2 ,  40 ,
    22 ,  C0B2 ,  80 ,  21 ,
    D0B2 ,  80 ,  22 ,  12B0 ,
    wait ,  D0B2 ,  40 ,  21 ,
    C0B2 ,  40 ,  22 ,  12B0 ,
    wait ,  D0B2 ,  80 ,  21 ,
    C0B2 ,  80 ,  22 ,  12B0 ,
    wait ,  4F00 ,  end-code

\ Generate I2C ACK
code I2ACK      ( -- )
    C0B2 ,  40 ,  21 ,
    D0B2 ,  40 ,  22 ,  C0B2 ,
    80 ,  21 ,  D0B2 ,  80 ,
    22 ,  12B0 ,  wait ,  D0B2 ,
    40 ,  21 ,  C0B2 ,  40 ,
    22 ,  12B0 ,  wait ,  C0B2 ,
    40 ,  21 ,  D0B2 ,  40 ,
    22 ,  12B0 ,  wait ,  4F00 ,  end-code

\ Generate I2C noACK
code I2NACK     ( -- )
    C0B2 ,  40 ,  21 ,  D0B2 ,  40 ,  22 ,
    D0B2 ,  80 ,  21 ,  C0B2 ,
    80 ,  22 ,  12B0 ,  wait ,
    D0B2 ,  40 ,  21 ,  C0B2 ,
    40 ,  22 ,  12B0 ,  wait ,
    C0B2 ,  40 ,  21 ,  D0B2 ,
    40 ,  22 ,  12B0 ,  wait ,  4F00 ,  end-code

\ Flag 'f' is true if an I2C ACK is received otherwise false
code I2ACK?     ( -- f )
    C0B2 ,  40 ,  21 ,
    D0B2 ,  40 ,  22 ,  D0B2 ,
    80 ,  21 ,  C0B2 ,  80 ,
    22 ,  12B0 ,  wait ,  D0B2 ,
    40 ,  21 ,  C0B2 ,  40 ,
    22 ,  12B0 ,  wait ,  8324 ,
    4784 ,  0 ,  4307 ,  B0B2 ,
    80 ,  20 ,  2C01 ,  4337 ,
    C0B2 ,  40 ,  21 ,  D0B2 ,
    40 ,  22 ,  12B0 ,  wait ,  4F00 ,  end-code

\ Send the byte b out on the I2C bus
code (I2OUT     ( b -- )
    4706 ,  4437 ,  4238 ,
    C0B2 ,  40 ,  21 ,  D0B2 ,
    40 ,  22 ,  5646 ,  2807 ,
    D0B2 ,  80 ,  21 ,  C0B2 ,
    80 ,  22 ,  3C06 ,  C0B2 ,
    80 ,  21 ,  D0B2 ,  80 ,
    22 ,  12B0 ,  wait ,  D0B2 ,
    40 ,  21 ,  C0B2 ,  40 ,
    22 ,  12B0 ,  wait ,  8318 ,
    23DF ,  4F00 ,  end-code

\ Receive de byte b from the I2C bus
code I2IN       ( -- b )
    8324 ,  4784 ,  0 ,  4307 ,
    4238 ,  D0B2 ,  40 ,  22 ,
    C0B2 ,  40 ,  21 ,  D0B2 ,
    80 ,  21 ,  C0B2 ,  80 ,
    22 ,  12B0 ,  wait ,  C0B2 ,
    40 ,  22 ,  D0B2 ,  40 ,
    21 ,  12B0 ,  wait ,  5707 ,
    B0B2 ,  80 ,  20 ,  2801 ,
    D317 ,  8318 ,  23E2 ,  4F00 ,  end-code

: I2OUT         ( b -- )    (i2out  i2ack? drop ;

value DEV
: >DEV          ( a -- )    FE and  to dev ;
: I2WRITE?)     ( -- )      i2start  dev (i2out  i2ack? ;
: I2WRITE       ( a -- )    >dev  i2write?) drop ;
: I2READ)       ( -- )      i2start  dev 1+ i2out ; \ Repeated start condition
: I2READ        ( a -- )    >dev  i2read) ;
: POLL          ( -- )      begin  i2write?)  i2stop  until ;

\ Prints -1 if device with address 'a' is present on I2C-bus otherwise 0.
: I2C?          ( a -- )
    >dev  setup-i2c  i2write?)  i2stop  . ;

shield I2C\  freeze

\ End
