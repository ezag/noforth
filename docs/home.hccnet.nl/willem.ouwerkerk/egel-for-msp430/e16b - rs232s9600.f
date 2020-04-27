(* e16b - For noForth C&V2553 lp.0 routines for 3/4 duplex software
   RS232 using bitbanging on P2.0 and a timer interrupt on P2.1
 \ -------------------------------------------------------------------
 \ LANGUAGE    : noForth vsn April 2016
 \ PROJECT     : Software RS232
 \ DESCRIPTION : 3/4 duplex compact software RS232
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
routine WAIT-BIT    ( -- a ) \ Wait bittime
    dm 268 # day mov        \ Set bittime
    begin,  #1 day sub  =? until,
    rp )+ pc mov  ( ret )
end-code

code RS-EMIT    ( char -- ) \ RS232s Char to RS232
    100 # tos bis           \ Add stopbit
    tos tos add             \ Add startbit
    0A # moon mov           \ 1 + 8 + Stop bits
    begin,
        tos rrc             \ Get next bit to carry
        cs? if,
            #1 29 & bis     \ P2OUT Send one
        else,
            #1 29 & bic     \ P2OUT Send zero
        then,
        wait-bit # call     \ Wait bittime
        #1 moon sub         \ Send all bits
    =? until,
    sp )+ tos mov
    next
end-code

code INTERRUPT-ON       #8 sr bis  next  end-code
code INTERRUPT-OFF      #8 sr bic  next  end-code

value RS-KEY?   \ True if char is received
value RS-CHAR   \ Received char
value RS#       \ Counted bits
: RS-ON             ( -- )  \ Install decoder hardware
    0000 160 !  0010 162 !  \ TA0CTL, TA0CCTL0 Timer A0 off and compare 0 interrupt on
\ Set hardware interrupt at P2.1 ready, all other bits of P2 are outputs
\ ) 00 02E c!               \ P2SEL  Port-2 use all bits as normal I/O
    02 2F *bis              \ P2REN  Bit-1 resistor on
    FD 2A c!                \ P2DIR  Bit-1 is input, rest is output
    03 29 *bis              \ P2OUT  Bit-1 pullup, bit-0 high
    02 2C *bis              \ P2IES  Bit-1 falling edge
    02 2B *bic              \ P2IFG  Bit-1 reset HW interrupt flag
    02 2D *bis              \ P2IE   Bit-1 interrupt on
    0 to rs-key?            \ Allow new key input
    interrupt-on ;          \ Activate decoder

: RS-OFF            ( -- )
    interrupt-off           \ Deactivate decoder
    0000 160 !  0000 162 !  \ TA0CTL, TA0CCTL0 Stop timer-A0
    02 2D *bic ;            \ P2IE   HW interrupts off

routine STARTBIT
\ ) #1 21 & .b bix          \ P1OUT  Trace bit read point P1.0
    #0 adr rs-key? & cmp  =? if,
        dm 49 # 172 & mov   \ TA0R   Next half bit in 49 us
        02D4 # 160 & mov    \ TA0CTL Start timer
        #2 2D & .b bic      \ P2IE   Stop hardware interrupt
        #0 adr rs# & mov    \ Reset bit counter
    then,
    #2 2B & .b bic         \ P2IE   Reset HW interrupt flag
    reti
end-code

routine READBIT
    dm 99 # 172 & mov       \ TA0R   Next bit in 99 us
\ ) #1 21 & .b bix          \ P1OUT  Trace bit read point P1.0
    #2 28 & .b bit          \ P2IN   Read input P2.1 to carry
    adr rs-char & rrc       \ Save bit
    #1 adr rs# & add        \ Increase bit counter
    0A # adr rs# & cmp  =? if, \ All bits received Start + 8 + 1-Stop
        adr rs-char & adr rs-char & add  cs?  if,   \ Stopbit high?
            adr rs-char & swpb  \ Char to low byte
            #-1 adr rs-char & .b bia \ Yes, Mask low 8-bits
            #-1 adr rs-key? & mov    \ Set char received
        then,
        #2 2B & .b bic      \ P2IFG  Reset HW interrupt flag
        #2 2D & .b bis      \ P2IE   HW interrupt on
        #0 160 & mov        \ TA0CTL Stop timer
    then,
    reti
end-code

code RS-KEY     ( -- char ) \ rs232s read char from rs232
    tos sp -) mov
    begin,                  \ Wait for key
        #-1 adr rs-key? & cmp
    =? until,
    adr rs-char & tos mov
    #0 adr rs-key? & mov
    next
end-code

: STARTUP       ( -- )
    rs-on                   \ Boot alternative RS232
    ['] rs-key? to 'key?    \ Install new KEY?
    ['] rs-key to 'key      \ and new KEY & EMIT
    ['] rs-emit to 'emit ;

readbit    FFF2 vec!        \ Set Timer A0 interrupt vector
startbit   FFE6 vec!        \ Set P2 interrupt vector
' startup to app  freeze

\ rs-on                     \ Initalise sofware UART
\ ch # rs-emit  many        \ Test output of software UART

\ End
