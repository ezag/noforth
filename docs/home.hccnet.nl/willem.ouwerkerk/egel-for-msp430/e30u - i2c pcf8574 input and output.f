(* E30u - For noForth C&V 200202: USCI I2C on MSP430G2553 using port-1.
  I2C input & output with a PCF8574 using external pull-ups

  Connect the I2C-print from the Forth users group or any other module
  with a PCF8574 and 8 leds and connect the power lines, P1.7 to SDA and
  P1.6 to SCL, note that two pullup resistors has te be mounted, that's it 
  For RUNNER2 and SHOW we need a second PCF8574 with eight switches. 
 *)

\ I2C USCI primitives
hex
code INT-OFF  C232 ,  4F00 ,  end-code

: SETUP-I2C ( -- )
    int-off
    00 2E c!     \ P2SEL     P2 all bits I/O
    FF 2A C!     \ P2DIR     All bits outputs
    C0 26 *bis   \ P1SEL     I2C to pins
    C0 41 *bis   \ P1SEL2
    1 69 *bis    \ UCB0CTL1  reset USCI
    F 68 c!      \ UCB0CTL0  I2C master
    81 69 c!     \ UCB0CTL1  Use SMclk
    dm 80 6A c!  \ UCB0BR0   Bitrate 100 KHz with 8 MHz DCO
\   dm 160 6A c! \ UCB0BR0   Bitrate 100 KHz with 16 MHz DCO
    0 6B c!      \ UCB0BR1
    1 69 *bic    \ UCB0CTL1  Resume USCI
    8 3 *bis ;   \ IFG2      Start with TX buffer empty

: I2C   ( fl -- )   ?abort ;        \ I2C error message

\ 04 = wait for data received to RX; 08 = wait for TX to be sent
\ : I2READY   ( bit -- )
\    80  begin
\        over 3 bit* if  2drop exit  then  
\    1- dup 0= until  true ?abort ;
code I2READY   ( bit -- )
    800 # day mov       \ 2048 to counter (day)
    begin,
        tos 3 & .b bit  cs? if,  sp )+ tos mov  next  then,
        #1 day sub
    0=? until,
chere >r  \ Reuse of code
    ip push
    ' i2c >body # ip mov
    next
end-code

\ 02 = wait for startcond. to finish; 04 = wait for stopcond. to finish
\ : I2DONE    ( bit -- )  \ wait until startcond. or stopcond. is done
\    200  begin
\        over 69 bit* 0= if  2drop exit  then  
\    1- dup 0= until  true ?abort ;
code I2DONE     ( bit -- )
    2000 # day mov      \ 8192 to counter (day)
    begin,
        tos 69 & .b bit  cc? if,  sp )+ tos mov  next  then,
        #1 day sub
    0=? until,
    r> jmp
end-code

: I2START   ( -- )      2 69 *bis ;         \ UCB0CTL1
: I2STOP    ( -- )      4 69 *bis ;         \ UCB0CTL1
\ : I2NACK    ( -- )      8 69 *bis ;         \ UCB0CTL1
\ : I2ACK?    ( -- fl )   8 6D bit* 0= ;      \ UCB0STAT
: I2OUT     ( b -- )    6F c!  8 i2ready ;  \ TX to shiftreg.
: I2IN      ( -- b )    4 i2ready  6E c@ ;  \ UCB0RXBUF Read databyte
: >DEV      ( a -- )    2/ 11A c! ;         \ UCB0I2CSA Set I2C device address
: I2STOP}   ( -- )      i2stop  4 i2done ;  \ Stop condition & check
\ : I2OUT}    ( b -- )    i2out  i2stop} ;    \ Write last I2C databyte!
: I2IN}     ( -- b )    i2stop  i2in  4 i2done ; \ Read last I2C databyte!
: {I2WRITE) ( -- )      12 69 *bis  8 i2ready ; \ UCB0CTL1  Send start condition

: {I2READ)  ( -- )          \ Send I2C device address for reading
    10 69 *bic  2 69 *bis   \ UCB0CTL1  Setup read & start
    8 i2ready  2 i2done ;   \ Wait for start condition & ack

: {I2WRITE  ( b a -- )      \ Send I2C device address for writing
    >dev  {i2write)  6F c!  \ Set dev. addr, send start condition & store 1st databyte
    2 i2done  8 i2ready ;   \ Wait for start cond. & send first data to TX

: {I2READ   ( a -- )        \ Set and send I2C device address for reading
    >dev   {i2read) ;       \ UCB0I2CSA Set slave address

hex v: inside also
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