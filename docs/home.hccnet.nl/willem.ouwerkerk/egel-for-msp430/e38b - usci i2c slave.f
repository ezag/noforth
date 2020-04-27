(* E38B - For noForth C&V2553 lp.0, USCI slave I2C on MSP430G2553 using port-1.
  I2C input and output with two MSP430G2553's using external pull-ups. Vsn 1.02
  The bitrate values are for an 8 MHz DCO, for 16 MHz they should be doubled.

  Connect the another Launchpad or Egel kit from the Forth users group
  with 6 or 8 leds and connect the power lines, P1.7 to SDA and
  P1.6 to SCL, note that two pullup resistors of 10 kOhm has te be
  mounted. Each slave has a resistor of 220 Ohm in series with both
  SCL and SDA, that's it.

 The examples has te be used in pairs, one MPU executes the top word, 
 the other has to execute the lower word. The word SLAVE-IO works with
 all masters. I2C-DEMO keeps working with invalid formats too.

  Master:  MASTER-OUT   MASTER-IN    MASTER-IO   MASTER-TRIO   (All masters)
  Slave1:  SLAVE-IN1    SLAVE-OUT    SLAVE-IO    SLAVE-IO      I2C-DEMO
  Slave2:                                        SLAVE-IN2

  The slave must be started before one starts the master, otherwise the
  master issues an error message due to a slave that is not present!
  The slave controller always waits for the master to claim the slave.

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
 0118    - UCB0I2C0A    - My own address
 011A    - UCB0I2CSA    - I2C device address
 0001    - IE2          - 000
 0003    - IFG2         - 008 = TX ready, 004 = RX ready
 *)

hex
code INT-OFF  C232 ,  4F00 ,  end-code

\ Initialise USCI as I2C-slave, a = always his own I2C bus-address
: SLAVE-I2C     ( a -- )
    int-off
    01 069 *bis     \ UCB0CTL1  reset USCI
    C0 026 *bis     \ P1SEL     I2C to pins
    C0 041 *bis     \ P1SEL2
    07 068 c!       \ UCB0CTL0  Select I2C slave
    81 069 c!       \ UCB0CTL1  Use SMclk
    dm 80 06A c!    \ UCB0BR0   Bitrate 100 KHz with 8 MHz DCO
    00 06B c!       \ UCB0BR1
    2/ 118 c!       \ UCB0I2CSA Set own address
    01 069 *bic     \ UCB0CTL1  Resume USCI
    08 003 *bis ;   \ IFG2      Start with TX buffer empty

\ USCI I2C primitives:
: I2C   ( fl -- )   ?abort ;        \ I2C error message

\ 04 = wait for data received to RX; 08 = wait for TX to be sent
\ : I2READY   ( bit -- )
\    80  begin
\        over 003 bit* if  2drop exit  then  
\    1- dup 0= until  true ?abort ;
code I2READY   ( bit -- )
    #-1 day .b mov      \ 255 to counter (day)
    begin,
        tos 003 & .b bit  cs? if,  sp )+ tos mov  next  then,
        #1 day sub
    0=? until,
chere >r  \ Reuse of code
    ip push
    ' i2c >body # ip mov
    next
end-code

\ 02 = wait for startcond. to finish; 04 = wait for stopcond. to finish
\ : I2DONE    ( bit -- )  \ wait until startcond. or stopcond. is done
\    80  begin
\        over 069 bit* 0= if  2drop exit  then  
\    1- dup 0= until  true ?abort ;
code I2DONE     ( bit -- )
    #-1 day .b mov
    begin,
        tos 069 & .b bit  cc? if,  sp )+ tos mov  next  then,
        #1 day sub
    0=? until,
    r> jmp
end-code

\ : I2START   ( -- )      02 069 *bis ;       \ UCB0CTL1  Give start condition
\ : I2STOP    ( -- )      04 069 *bis ;       \ UCB0CTL1  Give stop condition
\ : I2STOP?   ( -- fl )   04 06D bit* ;       \ UCB0STAT  Test stop finished
\ : I2NACK    ( -- )      08 069 *bis ;       \ UCB0CTL1  Give ack condition
\ : I2ACK?    ( -- fl )   08 06D bit* 0= ;    \ UCB0STAT  Test ack finished
: I2OUT     ( b -- )    06F c!  08 i2ready  noop ; \ UCB0TXBUF Write data
: I2IN      ( -- b )    04 i2ready  06E c@ ; \ UCB0RXBUF Read data

\ : I2FINISH} ( -- )      begin  i2stop? until ;
code I2FINISH} ( -- )
    begin,  #4 06D & .b bit  cs? until,  next
end-code

\ code I2ME   ( -- )      \ Wait for I2C address match
\    begin,  #2 06D & .b bit  cs? until,  next
\ end-code
\ 
\ : {I2ME?    ( -- fl ) \ Am I addressed as I2C device?
\   02 06D *bic         \ Reset address match
\   i2me                \ Address match? Wait! 
\   10 069 bit* ;       \ UCB0CTL1  True = read, False = write
code {I2ME?  ( -- fl )  \ Am I addressed as I2C device?
    #2 06D & .b bic     \ Reset address match
    begin,  #2 06D & .b bit  cs? until, \ Address match?
    tos sp -) mov       \ Push R/W request
    10 # 069 & .b bit   \ Read R/W
    tos tos subc        \ Build flag
    #-1 tos bix  next   \ Invert flag, ready
end-code


\ I2C user words, slave basic routines

\ Slave routines that emulate a PCF8574 like device, first a slave receiver
\ Accept receive commands only!
: MASTER>    ( -- b )
    begin  {i2me? 0= until  i2in  i2finish} ;   \ Me? receive RX, ready

\ Slave transmitter, accept transmit requests only!
: >MASTER    ( b -- )
    begin  {i2me? until  i2out  i2finish} ;     \ Me? Sent TX, wait for stop

\ More complex device that simulates a PCF8574 input and output device in one
\ Slave receiver and transmitter not mixed!! One at a time...
: >MASTER>  ( b1 -- b2 flag )   \ Flag is true if b2 is valid otherwise false
    {i2me? if                   \ For me? read request?
        i2out  i2finish}        \ Yes, sent data, wait for stop condition
        0  false  exit          \ Dummy result
    then
    drop  i2in  i2finish}  true ; \ RX received, ready


\ Demo I2C USCI slave device
: >LEDS     ( b -- )    029 c! ;

: FLASH     ( -- )          \ Toggles leds on master & slave
    FF >leds 100 ms  00 >leds 100 ms ;


\ The first slave application accepts data from master, slave address 50
: SLAVE-IN1 ( -- )
    50 slave-i2c  flash
    begin  master> >leds  key? until  0 >leds ;


\ The second slave application sends data to master, slave address 50
: SLAVE-OUT ( -- )
    50 slave-i2c  flash
    begin  s? dup 0= >leds  >master  key? until  0 >leds ;


\ Third slave app sends data to & receives data from master, slave address 50
: SLAVE-IO  ( -- )
    50 slave-i2c  flash
    begin
        s? >master> if  dup >leds  then  drop
    key? until  0 >leds ;


\ The fourth slave application accepts data from master, slave address 54
: SLAVE-IN2 ( -- )
    54 slave-i2c  flash
    begin  master> >leds  key? until  0 >leds ;


\ I2C application with error recovery from invalid bus formats
: I2C-DEMO  ( -- )
    begin
        ['] slave-io  catch if  cr ." I2C fault "  then
    key? until ;

50 slave-i2c  shield SLAVE-I2C\   freeze

\ End
