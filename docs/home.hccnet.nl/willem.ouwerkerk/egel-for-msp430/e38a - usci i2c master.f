(* E38A - For noForth C&V 200202: USCI master I2C on MSP430G2553 using port-1.
  I2C input and output with two MSP430G2553's using external pull-ups. Vsn 1.02
  The bitrate values are for an 8 MHz DCO, for 16 MHz they should be doubled.
  This code is improved, the routines work very solid, >SLAVE & SLAVE>
  give an error mesage when the addressed device does not respond.

  Connect the another Launchpad or Egel kit from the Forth users group
  with 6 or 8 leds and connect the power lines, P1.7 to SDA and
  P1.6 to SCL, note that two pullup resistors of 10 kOhm has te be
  mounted. Each slave has a resistor of 220 Ohm in series with both
  SCL and SDA, that's it.

 The examples has te be used in pairs, one MPU executes the top word, 
 the other has to execute the lower word:

  Master:  MASTER-OUT   MASTER-IN    MASTER-IO   MASTER-TRIO
  Slave1:  SLAVE-IN1    SLAVE-OUT    SLAVE-IO    SLAVE-IO
  Slave2:                                        SLAVE-IN2

  The slave must be started before one starts the master, otherwise the
  master issues an error message due to a slave that is not present!
  The slave controller always waits for the master to claim the slave.

 Addresses, Lables and Bit patterns  
 120    - WDTCL        - Off already
 026    - P1SEL        - 0C0
 041    - P1SEL2       - 0C0
 068    - UCB0CTL0     - 00F
 069    - UCB0CTL1     - 081
 06A    - UCB0BR0      - 0A0
 06B    - UCB0BR1      - 000
 06C    - UCB0CIE      - USCI interrupt enable
 06D    - UCB0STAT     - USCI status
 06E    - UCB0RXBUF    - RX Data
 06F    - UCB0TXBUF    - TX Data
 118    - UCB0I2C0A    - My own address
 11A    - UCB0I2CSA    - I2C device address
 001    - IE2          - 000
 003    - IFG2         - 008 = TX ready, 004 = RX ready
 *)

hex
code INT-OFF  C232 ,  next  end-code

: SETUP-I2C  ( -- ) \ Initialise I2C master
    int-off
    FF 2A C!        \ P2DIR     Outputs
    1 69 *bis       \ UCB0CTL1  reset USCI
    C0 26 *bis      \ P1SEL     I2C to pins
    C0 41 *bis      \ P1SEL2
    0F 68 c!        \ UCB0CTL0  Select I2C master
    81 69 c!        \ UCB0CTL1  Use SMclk
    dm 80 6A c!     \ UCB0BR0   Bitrate 100 KHz with 8 MHz DCO
    0 6B c!         \ UCB0BR1
    1 69 *bic       \ UCB0CTL1  Resume USCI
    8 3 *bis ;      \ IFG2      Start with TX buffer empty

\ USCI I2C primitives:
: I2C   ( fl -- )   ?abort ;        \ I2C error message

\ 4 = wait for data received to RX; 8 = wait for TX to be sent
\ : I2READY   ( bit -- )
\    80  begin
\        over 3 bit* if  2drop exit  then  
\    1- dup 0= until  true ?abort ;
code I2READY   ( bit -- )
    800 # day .b mov    \ 2048 to counter (day)
    begin,
        tos 3 & .b bit  cs? if,  sp )+ tos mov  next  then,
        #1 day sub
    0=? until,
chere >r  \ Reuse of code
    ip push
    ' i2c >body # ip mov
    next
end-code

\ 2 = wait for startcond. to finish; 4 = wait for stopcond. to finish
\ : I2DONE    ( bit -- )  \ wait until startcond. or stopcond. is done
\    80  begin
\        over 69 bit* 0= if  2drop exit  then  
\    1- dup 0= until  true ?abort ;
code I2DONE     ( bit -- )
    2000 # day .b mov   \ 8192 to counter (day)
    begin,
        tos 69 & .b bit  cc? if,  sp )+ tos mov  next  then,
        #1 day sub
    0=? until,
    r> jmp
end-code

: I2START   ( -- )      2 69 *bis ;       \ UCB0CTL1
: I2STOP    ( -- )      4 69 *bis ;       \ UCB0CTL1
\ : I2NACK    ( -- )      8 69 *bis ;       \ UCB0CTL1
\ : I2ACK?    ( -- fl )   8 06D bit* 0= ;   \ UCB0STAT
: I2OUT     ( b -- )    6F c!  8 i2ready ;  \ UCB0RXBUF 'b' to shiftreg.
: I2IN      ( -- b )    4 i2ready  6E c@ ;  \ UCB0RXBUF Read databyte 'b'
: >DEV      ( a -- )    2/ 11A c! ;         \ UCB0I2CSA Set I2C device address
: I2STOP}   ( -- )      i2stop  4 i2done ;  \ Stop condition & check
: I2OUT}    ( b -- )    i2out  i2stop} ;    \ Write last I2C databyte!
: I2IN}     ( -- b )    i2stop  i2in  4 i2done ; \ Read last I2C databyte!
: {I2WRITE) ( -- )      12 69 *bis  8 i2ready ;  \ UCB0CTL1  Send start condition

: {I2READ)  ( -- )      \ Send I2C device address for reading
    10 69 *bic  i2start     \ UCB0CTL1  Setup read
    8 i2ready  2 i2done ;   \ UCB0CTL1  Send start condition

: {I2WRITE  ( a -- )    \ Send I2C device address for writing
    >dev  {i2write)  6F c!  \ Set dev. addr, send start condition & store 1st databyte
    2 i2done  8 i2ready ;   \ Wait for start cond. & send first data to TX

: {I2READ   ( a -- )    \ Set and send I2C device address for reading
    >dev  {i2read) ;    \ UCB0I2CSA Set slave address


\ I2C master basic routines

\ Send data 'b' to a PCF8574 or similar slave software with address 'a'. 
\ The base adress of a PCF8574 is 040, for PCF8574A it is 070
: >SLAVE     ( b a -- )
    {i2write  i2stop} ; \ Address device, fill TX and ready

\ Read data 'b' from a PCF8574 or similar slave software with address 'a' 
\ The base adress of a PCF8574 is 040, for PCF8574A it is 070
: SLAVE>     ( a -- b )     {i2read  i2in} ;


\ Demo I2C master with USCI slave device
: >LEDS     ( b -- )    29 c! ;
: 10MS      ( +n -- )   4 + for  0A ms  next ;

: FLASH     ( -- )          \ Toggles leds on master & slave
    FF >leds  FF 50 >slave  100 ms  
    00 >leds  00 50 >slave  100 ms ;


\ The first master slave application, slave address is 50
: MASTER-OUT ( -- )         \ Show a running light on the leds
    setup-i2c  flash
    begin
        8 0 do
            1 i lshift  dup 50 >slave  >leds  50 ms  
        loop
    key? until  
    0 50 >slave  0 >leds ;


\ The second master-slave app toggles the leds, slave address is 50 
\ The delay duration is changed on a keypress on the slave (S?)
: MASTER-IN ( -- )          \ Show keypresses on leds
    setup-i2c  FF >leds  00
    begin
        dup >leds  invert  
        50 slave> 10ms  
    key? until  0 >leds ;


\ The third master-slave app does in- and output, slave address is 50
: MASTER-IO ( -- )          \ Show a running light on leds
    setup-i2c  flash
    begin
        8 0 do
            1 i lshift  dup 50 >slave  >leds
            50 slave> 10ms  
        loop
    key? until  
    0 50 >slave  0 >leds ;


\ The fourth master-slave app, has two addressed slaves 50 & 54
\ The shiftregister is copied to the slave with bus address 54,
\ the counter to the slave with bus address 50.
\ Also data from the slave at address 50 is read and used for the delay routine.
: MASTER-TRIO   ( -- )
    setup-i2c  flash  0    \ Counter init. 
    begin
        8 0 do
            dup 50 >slave  1+               \ Binary counter on slave 1
            50 slave> 10ms                  \ Switch from slave 1
            1 i lshift  dup 54 >slave >leds \ Running light here & on slave 2
        loop
    key? until  
    0 50 >slave  0 54 >slave  0 >leds  drop ; \ All leds off

setup-i2c  shield MASTER-I2C\   freeze

\ End
