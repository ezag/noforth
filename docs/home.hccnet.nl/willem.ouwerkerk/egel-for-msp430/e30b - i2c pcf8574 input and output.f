(* E30b - For noForth C&V 200202: bitbang I2C on MSP430G2553 using port-1.
  I2C input & output with a PCF8574 using external pull-ups

  Connect the I2C-print from the Forth users group or any other module
  with a PCF8574 and 8 leds and connect the power lines, P1.7 to SDA and
  P1.6 to SCL, note that two pullup resistors has te be mounted, that's it 
  For RUNNER2 and SHOW we need a second PCF8574 with eight switches. 
 *)

\ I2C bit-bang primitives
hex  v: inside also definitions
value DEV
: SETUP-I2C     ( -- )
    C0 27 *bic  C0 22 *bis  C0 21 *bis  \ P1REN, P1DIR, P1OUT
    C0 26 *bic  C0 42 *bic  FF 2A c!    \ P1SEL, P1SEL2, P2DIR
    00 2E c! ;                          \ P2SEL     P2 all bits I/O

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

code >DEV   ( a -- )
    F037 ,  FE ,  4782 ,  248 ,  4437 ,  next  end-code

\ : I2OUT}        ( b -- )    i2out  i2stop} ;
: I2IN}         ( -- b )    (i2in  i2nack  i2stop} ;
: {I2WRITE)     ( -- )      i2start  dev (i2out ;   \ Start I2C write
: {I2READ)      ( -- )      i2start  dev 1+ i2out ; \ Start read to device

: {I2WRITE     ( b a -- )
    >dev  {i2write)  i2ack? 0= ?abort  i2out ;      \ Start write to dev 'a'

: {I2READ      ( a -- )    >dev  {i2read) ;         \ Start read to dev. 'a'

hex  v: inside also
\ Output routine for PCF8574(a) chips
\ 042 Is address 1 of output chip, 040 is address 0 of input chip
\ When using the PCF8574A these are, output: 072 and input: 070
: >LEDS     ( b -- )    dup 029 c!  invert 042 {i2write  i2stop} ;
: BLINK     ( -- )      FF >leds 100 ms  00 >leds 100 ms ;

: RUNNER1   ( -- )              \ Show a running light on the leds
    setup-i2c  blink
    begin
        8 for  1 i lshift >leds  50 ms  next  
    key? until 
    0 >leds ;

\ The second I2C application is a running light with variable speed
: INPUT     ( -- +n )       40 {i2read i2in}  FF xor ;

: RUNNER2   ( -- )              \ Show a running light on leds
    setup-i2c  blink
    begin
        8 0 do
            1 i lshift >leds  input 0A * ms
        loop  
    key? until  0 >leds ;

: SHOW      ( -- )              \ Show keypresses on leds
    setup-i2c  blink
    begin  input >leds  key? until  0 >leds ;

v: fresh
' runner1   to app
shield 8574\  freeze

\ End ;;;
