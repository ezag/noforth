(* e16a - For noForth C&V2553 lp.0 routines for half duplex
   software RS232 using bitbanging on P2.0 and P2.1
 \ -------------------------------------------------------------------
 \ LANGUAGE    : noForth vsn April 2016
 \ PROJECT     : Software RS232
 \ DESCRIPTION : Half duplex compact software RS232
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

 *)

hex
routine WAIT-BIT    ( -- a )    \ Wait bittime
    dm 268 # day mov            \ Set bittime
    begin,  #1 day sub  =? until,
    rp )+ pc mov  ( ret )
end-code

code RS-EMIT    ( char -- )     \ RS232s Char to RS232
    tos tos add                 \ Room for startbit
    200 # tos bis               \ Add stopbit
    0A # moon mov               \ 1 + 8 + S bits
    begin,
        tos rrc                 \ Get next bit to carry
        cs? if,
            #1 29 & bis         \ P2OUT Send one
        else,
            #1 29 & bic         \ P2OUT Send zero
        then,
        wait-bit # call         \ Wait bittime
        #1 moon sub             \ Send all bits
    =? until,
    sp )+ tos mov
    next
end-code

code RS-KEY     ( -- char )     \ rs232s read char from rs232
    tos sp -) mov
    begin,  #2 28 & .b bit  cc? until, \ P2IN wait for startbit
    30 # moon mov               \ wait extra to reach sample point
    begin,  #1 moon sub  =? until,
    #8 moon mov                 \ read 8 databits
    begin,
        wait-bit # call         \ wait bittime
\ )     20 # 21 & .b bix        \ P1OUT Trace sample moment at P1.5
        #2 28 & .b bit          \ P2IN read rx line to carry
        tos rrc                 \ shift rx into char
        #1 moon sub             \ return at stopbit
    =? until,
    wait-bit # call             \ wait bittime for stopbit
\ ) 20 # 21 & bix               \ P1OUT Trace stopbit moment at P1.5
    tos swpb
    #-1 tos .b bia              \ Use low byte only
    next
end-code

code RS-KEY?    ( -- fl )       \ rs232s startbit detected
    tos sp -) mov
    #0 tos mov
    #2 28 & .b bit              \ P2IN Test for startbit
    cc? if,  #-1 tos mov  then,
    next
end-code

: RS-ON         ( -- )          \ rs232s initialise rs232
    01 2A *bis                  \ P2DIR txd is output
    02 2A *bic                  \ P2DIR rxd is input
    01 29 *bis  50 ms ;         \ P2OUT start with txd high

: STARTUP       ( -- )
    rs-on                       \ Boot alternative RS232
    ['] rs-key? to 'key?        \ Install new KEY?
    ['] rs-key to 'key          \ and new KEY & EMIT
    ['] rs-emit to 'emit ;

' startup to app  freeze

\ rs-on                         \ Initalise sofware UART
\ ch # rs-emit  many            \ Test output of software UART

\ End
