(* E37 G2 - For noForth C&V 200202: Bit-bang I2C routines for MSP430G2 code variant
   This implementation is without clockbit stretching!!! Basic building blocks

  Connect the I2C-print from the Forth users group or any other module
  with I2C compatible chip{s} and connect the power lines. P1.7 to SDA and
  P1.6 to SCL, note that two 10k pullup resistors has te be mounted, that's it.
  User words:  >DEV  {I2WRITE)  {I2WRITE  {I2READ)  {I2READ
               I2STOP}  I2IN  I2IN}  I2OUT  I2OUT}  I2C?
               SETUP-I2C  {I2ACK?}  {POLL}

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

hex  v: inside also definitions
value DEV
: SETUP-I2C     ( -- )
    C0 27 *bic  C0 22 *bis  C0 21 *bis  \ P1REN, P1DIR, P1OUT
    C0 26 *bic  C0 42 *bic ;            \ P1SEL, P1SEL2

\ Minimal period is 5 us, is about 100 kHz clock
routine WAIT     ( -- adr )
    4039 ,  12 ,  8319 ,  23FE ,  4130 ,  end-code

\ Give I2C start condition
code I2START    ( -- )
    D0F2 ,  40 ,  21 ,  C0F2 ,  40 ,  22 ,  12B0 ,  wait ,
    D0F2 ,  80 ,  22 ,  C0F2 ,  80 ,  21 ,  12B0 ,  wait ,
    next  end-code

\ Give I2C stop condition
code I2STOP}    ( -- )
    C0F2 ,  40 ,  21 ,  D0F2 ,  40 ,  22 ,
    C0F2 ,  80 ,  21 ,  D0F2 ,  80 ,  22 ,  12B0 ,  wait ,
    D0F2 ,  40 ,  21 ,  C0F2 ,  40 ,  22 ,  12B0 ,  wait ,
    D0F2 ,  80 ,  21 ,  C0F2 ,  80 ,  22 ,  12B0 ,  wait ,
    next  end-code

\ Generate I2C ACK
code I2ACK      ( -- )
    C0F2 ,  40 ,  21 ,  D0F2 ,  40 ,  22 ,
    C0F2 ,  80 ,  21 ,  D0F2 ,  80 ,  22 ,  12B0 ,  wait ,
    D0F2 ,  40 ,  21 ,  C0F2 ,  40 ,  22 ,  12B0 ,  wait ,
    C0F2 ,  40 ,  21 ,  D0F2 ,  40 ,  22 ,  12B0 ,  wait ,
    next  end-code

\ Generate I2C noACK
code I2NACK     ( -- )
    C0F2 ,  40 ,  21 ,  D0F2 ,  40 ,  22 ,
    D0F2 ,  80 ,  21 ,  C0F2 ,  80 ,  22 ,  12B0 ,  wait ,
    D0F2 ,  40 ,  21 ,  C0F2 ,  40 ,  22 ,  12B0 ,  wait ,
    C0F2 ,  40 ,  21 ,  D0F2 ,  40 ,  22 ,  12B0 ,  wait ,
    next  end-code

\ Flag 'f' is true if an I2C ACK is received otherwise false
code I2ACK?     ( -- f )
    C0F2 ,  40 ,  21 ,  D0F2 ,  40 ,  22 ,
    D0F2 ,  80 ,  21 ,  C0F2 ,  80 ,  22 ,  12B0 ,  wait ,
    D0F2 ,  40 ,  21 ,  C0F2 ,  40 ,  22 ,  12B0 ,  wait ,
    8324 ,  4784 ,  0 ,  B0F2 ,  80 ,  20 ,  7707 ,  C0F2 ,
    40 ,  21 ,  D0F2 ,  40 ,  22 ,  12B0 ,  wait ,  next  end-code

\ Send the byte b out on the I2C bus
code (I2OUT     ( b -- )
    4706 ,  4437 ,  4238 ,  C0F2 ,  40 ,  21 ,  D0F2 ,
    40 ,  22 ,  5646 ,  2807 ,  D0F2 ,  80 ,  21 ,  C0F2 ,
    80 ,  22 ,  3C06 ,  C0F2 ,  80 ,  21 ,  D0F2 ,  80 ,
    22 ,  12B0 ,  wait ,  D0F2 ,  40 ,  21 ,  C0F2 ,  40 ,
    22 ,  12B0 ,  wait ,  8318 ,  23DF ,  next  end-code

\ Receive de byte b from the I2C bus
code (I2IN      ( -- b )
    8324 ,  4784 ,  0 ,  4307 ,  4238 ,  C0F2 ,  40 ,  21 ,
    D0F2 ,  40 ,  22 ,  D0F2 ,  80 ,  21 ,  C0F2 ,  80 ,
    22 ,  12B0 ,  wait ,  D0F2 ,  40 ,  21 ,  C0F2 ,  40 ,
    22 ,  12B0 ,  wait ,  B0F2 ,  80 ,  20 ,  6707 ,  8318 ,
    23E4 ,  next  end-code

v: extra definitions
: I2OUT     ( b -- )    (i2out  i2ack? drop ; \ Write byte & drop Ack
: I2IN      ( -- b )    (i2in  i2ack ;        \ Read byte & give Ack


\ : >DEV      ( a -- )    FE and  to dev ;        \ Set device address
code >DEV   ( a -- )
    F037 ,  FE ,  4782 ,  248 ,  4437 ,  next  end-code

: I2OUT}        ( b -- )    i2out  i2stop} ;
: I2IN}         ( -- b )    (i2in  i2nack  i2stop} ;
: {I2WRITE)     ( -- )      i2start  dev (i2out ;   \ Start I2C write
: {I2READ)      ( -- )      i2start  dev 1+ i2out ; \ Start read to device

: {I2WRITE     ( b a -- )
    >dev  {i2write)  i2ack? 0= ?abort  i2out ;      \ Start write to dev 'a'

: {I2READ      ( a -- )    >dev  {i2read) ;         \ Start read to dev. 'a'

: {I2ACK?}  ( -- fl )           \ Flag 'fl' is true when an ACK is received
    {i2write)  i2ack?  i2stop} ;

\ This routine may be used when writing to EEPROM memory devices.
\ The waiting for the write to succeed is named acknowledge polling.
: {POLL}        ( -- )      begin  {i2ack?} until ; \ Wait until ACK received

\ Prints -1 if device with address 'a' is present on I2C-bus otherwise 0.
: I2C?          ( a -- )
    setup-i2c >dev {i2ack?} . ;

v: fresh definitions
shield BB-I2C\  freeze

\ End
