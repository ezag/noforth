(* e16c - For noForth C&V 200202: routines for full duplex software
   RS232 using interrupts with timer-A1 on P2.0 and timer-A0 on P2.1
 \ -------------------------------------------------------------------
 \ LANGUAGE    : noForth vsn April 2016
 \ PROJECT     : Software UART
 \ DESCRIPTION : Full duplex compact software UART
 \ CATEGORY    : Application, size: 192 bytes.
 \ AUTHOR      : Willem Ouwerkerk, August 2002, 2016
 \ LAST CHANGE : Willem Ouwerkerk, August 2002, 2003, 2016
 \ -------------------------------------------------------------------

About baudrates:

Not all baudrates are applicable using the word WAIT-BIT 
The maximum delay now is 65535. It is to the programmer to write 
alternative versions, 9600baud is chosen as default baudrate. 
It works for every supported DCO frequency.

  #027 CONSTANT BITRATE#            \ 9600 Baud at 1 MHz
  #059 CONSTANT BITRATE#            \ 9600 Baud at 2 MHz
  #129 CONSTANT BITRATE#            \ 9600 Baud at 4 MHz
  #268 CONSTANT BITRATE#            \ 9600 Baud at 8 MHz
  #545 CONSTANT BITRATE#            \ 9600 Baud at 16 MHz

    P2.0 = Output TX
    P2.1 = Input RX

  Address 028 - P2IN,  port-2 input register
  Address 029 - P2OUT, port-2 output register
  Address 02A - P2DIR, port-2 direction register

  The most hard to find data are those for the selection registers. 
  To find the data for the selection register of Port-2 here 02E you have to
  go to the "Port Schematics". This starts on page 42 of SLAS735J.PDF, for 
  P2 the tables are found from page 50 and beyond. These tables say which 
  function will be on each I/O-bit at a specific setting of the registers.

  The settings for P2.0 will be found from page 42 and beyond of SLAS735J.PDF,
  settings for timer A0 can be found on page 378 and beyond of SLAU144I.PDF

  Addresses of Timer-A0
  160 = TA0CTL   - Timer A0 control
  162 = TA0CCTL0 - Timer A0 Comp/Capt. control 0
  172 = TA0CCR0  - Timer A0 Comp/Capt. 0
  170 = TA0R     - Timer A0 register
  0000 0010 1101 0100 = 02D4 - TA = zero, count up mode, SMCLK, presc. /8
  FFF2   - Timer A0 Interrupt vector

 *)

hex
code INTRPT-ON     #8 sr bis  next  end-code
code INTRPT-OFF    #8 sr bic  next  end-code

value RS-EMIT?  \ True if software UART is busy
value TXCHAR    \ Char to be transmitted
value TX#       \ Counted bits that were transmitted 
code RS-EMIT    ( char -- ) \ RS232s Char to RS232 
    300 # tos bis           \ Add stopbit(s)
    tos tos add             \ Add startbit
    begin,
        #-1 adr rs-emit? & cmp \ Char transmitted?
    <>? until,              \ Yes
    tos adr txchar & mov    \ Store TX char
    #-1 adr rs-emit? & mov  \ UART busy
    dm 49 # 192 & mov       \ TA1CCR0 Wait half bit 49 us
    02D4 # 180 & mov        \ TA1CTL  Start timer
    #0 adr tx# & mov        \ Reset bit counter
    sp )+ tos mov           \ Pop char
    next
end-code

routine WRITEBIT
    dm 99 # 192 & mov       \ TA1CCR0 Time to next bit
    adr txchar & rrc        \ Get lowest bit
    cs? if,  #1 29 & bis    \ P2OUT  Output this bit
    else,    #1 29 & bic    \ P2OUT
    then,
\ ) #1 21 & bix             \ Trace bit output
    #1 adr tx# & add        \ Increase bit counter
    0B # adr tx# & cmp  =? if, \ All bits done
        #0 adr rs-emit? & mov  \ Yes, ready for next char
        #0 180 & mov        \ TA1CTL  Stop timer-A1
    then,    
    reti
end-code


value RS-KEY?   \ True if char is received
value RX#       \ Counted bits that were received
value RXCHAR    \ Received char
: RS-ON             ( -- )  \ Install decoder hardware
    0000 160 !  0010 162 !  \ TA0CTL, TA0CCTL0 Timer-A0 off & comp. 0 intrpt on
    0000 180 !  0010 182 !  \ TA1CTL, TA1CCTL0 Timer-A1 off & comp. 0 intrpt on
\ Set hardware interrupt at P2.1 ready, all other bits of P2 are outputs
\ ) 00 02E c!               \ P2SEL  Port-2 use all bits as normal I/O
    02 2F *bis              \ P2REN  Bit-1 resistor on
    FD 2A c!                \ P2DIR  Bit-1 is input, rest is output
    03 29 *bis              \ P2OUT  Bit-1 pullup, bit-0 high
    02 2C *bis              \ P2IES  Bit-1 falling edge
    02 2B *bic              \ P2IFG  Bit-1 reset HW interrupt flag
    02 2D *bis              \ P2IE   Bit-1 interrupt on
    0 to rs-key?            \ Allow new key input
    0 to rs-emit?           \ Allow char output
    intrpt-on ;             \ Activate decoder

: RS-OFF            ( -- )
    intrpt-off              \ Deactivate software UART
    0000 160 !  0000 162 !  \ TA0CTL, TA0CCTL0 Stop timer-A0
    0000 180 !              \ TA1CTL  Stop timer-A1
    02 2D *bic ;            \ P2IE   HW interrupts off

routine STARTBIT
\ ) #1 21 & .b bix          \ P1OUT   Trace bit read point P1.0
    #0 adr rs-key? & cmp  =? if,
        dm 49 # 172 & mov   \ TA0CCR0 Next half bit in 49 us
        02D4 # 160 & mov    \ TA0CTL  Start timer
        #2 2D & .b bic      \ P2IE    Stop hardware interrupt
        #0 adr rx# & mov    \ Reset bit counter
    then,
    #2 2B & .b bic         \ P2IE   Reset HW interrupt flag
    reti
end-code

routine READBIT
    dm 99 # 172 & mov       \ TA0CCR0 Receive next bit in 99 us
\ ) #1 21 & .b bix          \ P1OUT   Trace bit read point P1.0
    #2 28 & .b bit          \ P2IN    Read input P2.1 to carry
    adr rxchar & rrc        \ Save bit
    #1 adr rx# & add        \ Increase bit counter
    0A # adr rx# & cmp  =? if, \ All bits received Start + 8 + 1-Stop
        adr rxchar & adr rxchar & add  cs?  if,   \ Stopbit high?
            adr rxchar & swpb  \ Char to low byte
            #-1 adr rxchar & .b bia  \ Yes, Mask low 8-bits
            #-1 adr rs-key? & mov    \ Set char received
        then,
        #2 2B & .b bic      \ P2IFG   Reset HW interrupt flag
        #2 2D & .b bis      \ P2IE    HW interrupt on
        #0 160 & mov        \ TA0CTL  Stop timer
    then,
    reti
end-code

code RS-KEY     ( -- char ) \ rs232s read char from rs232
    tos sp -) mov
    begin,                  \ Wait for key
        #-1 adr rs-key? & cmp
    =? until,
    adr rxchar & tos mov
    #0 adr rs-key? & mov
    next
end-code

: STARTUP       ( -- )
    rs-on                   \ Boot alternative RS232
    ['] rs-key? to 'key?    \ Install new KEY?
    ['] rs-key to 'key      \ and new KEY & EMIT
    ['] rs-emit to 'emit ;

writebit   FFFA vec!        \ Set Timer-A1 interrupt vector
readbit    FFF2 vec!        \ Set Timer-A0 interrupt vector
startbit   FFE6 vec!        \ Set P2 interrupt vector
' startup to app  freeze

\ rs-on                     \ Initalise sofware UART
\ ch # rs-emit  many        \ Test output of software UART

\ End
