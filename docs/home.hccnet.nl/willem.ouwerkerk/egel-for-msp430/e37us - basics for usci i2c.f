(* E37US - For noForth C&V2553 lp.0, USCI I2C on MSP430G2553 using pull-ups.
   The bitrate values are for an 8 MHz DCO, for 16 MHz they should be doubled.
   This is a better version, the routines work more solid. Code Vsn 1.02s

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
  User words:  {I2ME?  I2FINISH}  I2ACK?  I2IN  I2IN  I2OUT  SETUP-I2C

  An example:  50 FALSE SETUP-I2C  ( Set I2C as slave receiver at address 50 )
  Here a word that accepts only data from the I2C-bus, all other request
  are ignored! I2IN reads the databyte, I2FINISH waits for the stop condition.
  : GET-DATA  ( -- b )  BEGIN  {I2ME? 0= UNTIL  I2IN  I2FINISH} ;

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

\ Initalise USCI as I2C slave, a = always own I2C bus-address
: SLAVE-I2C     ( a -- )
    int-off
    C0 026 *bis     \ P1SEL     I2C to pins
    C0 041 *bis     \ P1SEL2
    01 069 *bis     \ UCB0CTL1  reset USCI
    07 068 c!       \ UCB0CTL0  I2C slave
    81 069 c!       \ UCB0CTL1  Use SMclk
    dm 80 06A c!    \ UCB0BR0   Bitrate 100 KHz with 8 MHz DCO
    00 06B c!       \ UCB0BR1
    2/ 118 c!       \ UCB0I2CSA Set own address
    01 069 *bic     \ UCB0CTL1  Resume USCI
    08 003 *bis ;   \ IFG2      Start with TX buffer empty

: I2C         ( fl -- )   ?abort ;        \ I2C error message

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
: I2OUT     ( b -- )    06F c!  08 i2ready ; \ UCB0TXBUF Write data
: I2IN      ( -- b )    04 i2ready  06E c@ ; \ UCB0RXBUF Read data

\ : I2FINISH? ( -- )      begin  i2stop?  key? or until ;
code I2FINISH ( -- )    \ UCB0STAT  Wait till stop cond. finished
    begin,  #4 06D & .b bit  cs? until  next
end-code

\ code I2ME   ( -- )    \ Wait for I2C address match
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

50 slave-i2c  shield SLAVE-I2C\  freeze

\ End
