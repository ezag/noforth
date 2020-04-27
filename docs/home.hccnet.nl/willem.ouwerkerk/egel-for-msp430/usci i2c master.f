(* E37UM For noForth C&V2553 lp.0, USCI I2C on MSP430G2553 using pull-ups.
   The bitrate values are for an 8 MHz DCO, for 16 MHz they should be doubled.
   This is a better version, the routines work more solid. Code Vsn 1.02

  The most hard to find data are those for the selection registers.
  To find the data for the selection register of Port-1 here 026 and
  041 you have to go to the "Port Schematics". For P1.6 and P1.7 these
  are page 48 and 49 of SLAS735J.PDF These tables say which function 
  will be on each I/O-bit at a specific setting of the registers.

  Address 026 - P1SEL, port-1 selection register
  Address 041 - P1SEL2, port-1 selection register 2

  A description of USCI as I2C can be found in SLAU144J.PDF from page
  449 to page 473, the register description starts at page 468. The
  UCB0CTL0 register selects the SPI- or I2C-mode we are in.
 
 Connect the I2C-print from the Forth users group or any other module
  with I2C chips. Connect the power lines, P1.7 to SDA and P1.6 to SCL,
  note that two 10k pullup resistors has te be mounted and jumper P1.6 to
  the green led has to be removed, that's it.
  User words: >DEV  {I2WRITE)  {I2WRITE  {I2READ)  {I2READ 
              I2STOP}  I2IN  I2IN}  I2OUT1  I2OUT  I2C?  
              SETUP-I2C  {I2ACK?}  {POLL}

        **** New version with less primitives ****
        **** And assembly changed to hex code ****

  An example, first execute SETUP-I2C  After that the I2C is setup as a
  master. Sent byte 'b' to an I2C device with address 'a'.
    : >SLAVE    ( b a -- )  {i2write  i2out1  i2stop} ;
    : >PCF8574  ( b -- )    40 >slave ;

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
code INT-OFF  C232 ,  4F00 ,  end-code

: SETUP-I2C ( -- )
    int-off
    C0 026 *bis     \ P1SEL     I2C to pins
    C0 041 *bis     \ P1SEL2
    01 069 *bis     \ UCB0CTL1  reset USCI
    0F 068 c!       \ UCB0CTL0  I2C master
    81 069 c!       \ UCB0CTL1  Use SMclk
\   dm 20 06A c!    \ UCB0BR0   Bitrate 400 KHz with 8 MHz DCO
    dm 80 06A c!    \ UCB0BR0   Bitrate 100 KHz with 8 MHz DCO
\   dm 160 06A c!   \ UCB0BR0   Bitrate 100 KHz with 16 MHz DCO
    00 06B c!       \ UCB0BR1
    01 069 *bic     \ UCB0CTL1  Resume USCI
    08 003 *bis ;   \ IFG2      Start with TX buffer empty

: I2C   ( fl -- )   ?abort ;        \ I2C error message

\ 04 = wait for data received to RX; 08 = wait for TX to be sent
\ : I2READY   ( bit -- )
\    80  begin
\        over 003 bit* if  2drop exit  then  
\    1- dup 0= until  true ?abort ;
\ code I2READY   ( bit -- )
\    #-1 day .b mov      \ 255 to counter (day)
\    begin,
\        tos 003 & .b bit  cs? if,  sp )+ tos mov  next  then,
\        #1 day sub
\    0=? until,
\ chere >r  \ Reuse of code
\    ip push
\    ' i2c >body # ip mov
\    next
\ end-code
code I2READY    ( bit -- )
    4378 ,  B7C2 ,  3 ,  2802 ,  4437 ,  4F00 ,
    8318 ,  23F9 ,  ( chere >r )  1205 , 
    4035 ,  ' i2c >body ,  4F00 ,
end-code

\ 02 = wait for startcond. to finish; 04 = wait for stopcond. to finish
\ : I2DONE    ( bit -- )  \ wait until startcond. or stopcond. is done
\    80  begin
\        over 069 bit* 0= if  2drop exit  then  
\    1- dup 0= until  true ?abort ;
\ code I2DONE     ( bit -- )
\    #-1 day .b mov
\    begin,
\        tos 069 & .b bit  cc? if,  sp )+ tos mov  next  then,
\        #1 day sub
\    0=? until,
\    r> jmp
\ end-code
code I2DONE     ( bit -- )
    4378 ,  B7C2 ,  69 ,  2C02 ,  4437 ,
    4F00 ,  8318 ,  23F9 ,  3FEE ,  ( r> jmp )
end-code

\ : I2START   ( -- )      02 069 *bis ;       \ UCB0CTL1
\ : I2STOP    ( -- )      04 069 *bis ;       \ UCB0CTL1
\ : I2NACK    ( -- )      08 069 *bis ;       \ UCB0CTL1
\ : I2ACK?    ( -- fl )   08 06D bit* 0= ;    \ UCB0STAT
: I2OUT1    ( b -- )    06F c!  02 i2done  noop ; \ UCB0TXBUF Send first data to TX
: I2OUT     ( b -- )    06F c!  08 i2ready  noop ; \ UCB0TXBUF TX to shiftreg.
: I2IN      ( -- b )    04 i2ready  06E c@ ;  \ UCB0RXBUF Read databyte
: I2IN}     ( -- b )    04 069 *bis  i2in  04 i2done ; \ UCB0CTL1 Read last I2C databyte
: I2STOP}   ( -- )      04 069 *bis  04 i2done ; \ UCB0CTL1 Stop condition & check
: >DEV      ( a -- )    2/ 11A c! ;             \ UCB0I2CSA Set I2C device address


: {I2WRITE) ( -- )              \ Send I2C device address for writing
    12 069 *bis  08 i2ready  noop ;   \ UCB0CTL1  Send start condition

: {I2READ)  ( -- )              \ Send I2C device address for reading
    10 069 *bic  02 069 *bis    \ UCB0CTL1  Setup read & start
    08 i2ready  02 i2done ;     \ Wait for start condition & ack

: {I2WRITE  ( a -- )            \ Send I2C device address for writing
    >dev  {i2write) ;           \ Set slave address

: {I2READ   ( a -- )            \ Set and send I2C device address for reading
    >dev   {i2read) ;           \ Set slave address

: {I2ACK?}  ( -- fl )           \ Flag 'fl' is true when in ACK is received
    {i2write)  i2stop}  08 06D bit* 0= ;

: {POLL}    ( -- )      begin  {i2ack?} until ; \ Wait until an ACK is received


\ Prints -1 if device with address 'a' is present on I2C-bus otherwise 0.
: I2C?      ( a -- )            \ Result is true when device 'a' is on I2C bus
    >dev setup-i2c {i2ack?} . ; \ Address device, present?

setup-i2c   shield HWI2C\   freeze

\ End
