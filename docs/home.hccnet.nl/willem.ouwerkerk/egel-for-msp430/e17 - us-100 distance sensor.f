(* E17 - For noForth C&V 200202: routines for US-100 ultrasonic
   distance meter using 3/4 duplex software RS232 bitbanging on P2.3
   and a timer interrupt on P2.4, range from about 3 cm to 400 cm
 \ -------------------------------------------------------------------
 \ LANGUAGE    : noForth vsn April 2016
 \ PROJECT     : US-100 distance meter
 \ DESCRIPTION : Using 3/4 duplex software RS232
 \ CATEGORY    : Application, size: 1xx bytes.
 \ AUTHOR      : Willem Ouwerkerk, August 2002, 2017
 \ LAST CHANGE : Willem Ouwerkerk, August 2002, 2003, 2017
 \ -------------------------------------------------------------------

About US-100:

Note that the responce time increases with distance, at short range
this is about 7 milliseconds, this increases to 90 milliseconds when
the distance is out of range!

Note that when working in large spaces with a chance of out of range
readings, the timeout must be set to 0000 this gives the maximum time of
about 90 ms! For shorter spaces it may be set to A000 which is 40 ms.
This is enough to timeout the maxiumum applicapable distance.

The readings are very stable and are given in millimeters! Using the
RS232 mode, the readings are temperature compensated by the sensor itself.

The current timeout for the readings is about 90 milliseconds. That gives
a maximum range of about 400 cm. The distance is returned in millimeters.


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

    P2.3 = Output TX to Trig/Tx pin
    P2.4 = Input RX  to Echo/Rx pin

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

User words: RS-ON  DISTANCE  MEASURE  TEMPERATURE

 *)

hex
routine WAIT-BIT  ( -- a )  \ Wait bittime
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
            #8 29 & bis     \ P2OUT Send one
        else,
            #8 29 & bic     \ P2OUT Send zero
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
value BL#       \ Counted bits
: RS-ON             ( -- )  \ Install decoder hardware
    0000 160 !  0010 162 !  \ TA0CTL, TA0CCTL0 Timer A0 off and compare 0 interrupt on
\ Set hardware interrupt at P2.4 ready, all other bits of P2 are outputs
\ ) 00 02E c!               \ P2SEL  Port-2 use all bits as normal I/O
    10 2F *bis              \ P2REN  Bit-4 resistor on
    EF 2A c!                \ P2DIR  Bit-4 is input, rest is output
    18 29 *bis              \ P2OUT  Bit-4 pullup, bit-0 high
    10 2C *bis              \ P2IES  Bit-4 falling edge
    10 2B *bic              \ P2IFG  Bit-4 reset HW interrupt flag
    10 2D *bis              \ P2IE   Bit-4 interrupt on
    0 to rs-key?            \ Allow new key input
    interrupt-on ;          \ Activate decoder

\ : RS-OFF            ( -- )
\    interrupt-off           \ Deactivate decoder
\    0000 160 !  0000 162 !  \ TA0CTL, TA0CCTL0 Stop timer-A0
\    10 2D *bic ;            \ P2IE   HW interrupts off

routine STARTBIT
\ ) #1 21 & .b bix          \ P1OUT  Trace bit read point P1.0
    #0 adr rs-key? & cmp  =? if,
        dm 49 # 172 & mov   \ TA0R   Next half bit in 49 us
        02D4 # 160 & mov    \ TA0CTL Start timer
        10 # 2D & .b bic    \ P2IE   Stop hardware interrupt
        #0 adr bl# & mov    \ Reset bit counter
    then,
    10 # 2B & .b bic        \ P2IE   Reset HW interrupt flag
    reti
end-code

routine READBIT
    dm 102 # 172 & mov      \ TA0R   Next bit in 99 us
( ) #1 21 & .b bix          \ P1OUT  Trace bit read point P1.0
    10 # 28 & .b bit        \ P2IN   Read input P2.4 to carry
    adr RS-char & rrc       \ Save bit
    #1 adr bl# & add        \ Increase bit counter
    0A # adr BL# & cmp  =? if, \ All bits received Start + 8 + 1-Stop
        adr rs-char & adr rs-char & add  cs?  if,   \ Stopbit high?
            adr rs-char & swpb  \ Char to low byte
            #-1 adr rs-char & .b bia \ Yes, Mask low 8-bits
            #-1 adr rs-key? & mov    \ Set char received
        then,
        10 # 2B & .b bic    \ P2IFG  Reset HW interrupt flag
        10 # 2D & .b bis    \ P2IE   HW interrupt on
        #0 160 & mov        \ TA0CTL Stop timer
    then,
    reti
end-code

code RS-KEY     ( -- char ) \ rs232s read char from rs232
    tos sp -) mov
    0C00 # moon mov         \ ~ 3 millisec. timeout, because the
    begin,                  \ temperature data is received after 2.8 ms!
        sun )+ sun mov      \ Dummy opcode to timeout later
        #1 moon sub
        =? if, #-1 tos .b mov next then,  \ Leave FF at timeout
        #-1 adr RS-key? & cmp
    =? until,
    adr RS-char & tos mov
    #0 adr rs-key? & mov
    next
end-code

code TRS-KEY    ( -- char ) \ rs232s read char from rs232 with long timeout
    tos sp -) mov
\   A000 # moon mov         \ ~40 millisec. timeout (about 2.5 meters)
    0000 # moon mov         \ ~90 millisec. timeout (about 4 meters)
    ' rs-key 0C + jmp       \ Reuse RS-KEY code
end-code


\ Read distance in mm and temperature in degrees celcius!
: DISTANCE      ( -- u )        55 rs-emit  trs-key ><  rs-key or ;
: TEMPERATURE   ( -- n )        50 rs-emit  rs-key dm 45 - ;

: MEASURE   ( -- )              \ Show distance in mm
    rs-on  flash  ." Temp: " temperature .
    cr ." Distance: " begin  distance dm .  key? until ;

readbit    FFF2 vec!        \ Set Timer A0 interrupt vector
startbit   FFE6 vec!        \ Set P2 interrupt vector
shield US-100\  freeze

\ End
