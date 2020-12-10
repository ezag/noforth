(* E111B - For noForth C&V 200202 or later: CLONE noForth to another MSP430G2553
  & calibrate DCO to a 32KHz XT, when the DCO constants where destroyed!

  Do not forget to mount a 32kHz crystal. It is used as a reference
  to generate and restore a set of new DCO-constants.

  ----------------------------------------------------------------------
  LANGUAGE    : noForth BSL & calibrate DCO vsn 0001 April 2016
  PROJECT     : BSL with software RS232
  DESCRIPTION : With half duplex software RS232
  CATEGORY    : Application, size: ~1300 bytes.
  AUTHOR      : Willem Ouwerkerk, 12 April 2016
  LAST CHANGE : Willem Ouwerkerk, 14 June 2016
  ----------------------------------------------------------------------

About baudrates.

Not all baudrates are applicapable using the word WAIT-BIT 
The maximum delay now is 65535. It is to the programmer to write 
alternative versions, 9600baud is chosen as default baudrate. 
It works for every supported frequency.

  #027 CONSTANT BITRATE#            \ 9600 Baud at 1 MHz
  #059 CONSTANT BITRATE#            \ 9600 Baud at 2 MHz
  #129 CONSTANT BITRATE#            \ 9600 Baud at 4 MHz
  #268 CONSTANT BITRATE#            \ 9600 Baud at 8 MHz
  #545 CONSTANT BITRATE#            \ 9600 Baud at 16 MHz

More info about the built-in BSL in SLAU319L.PDF 
Read the pages 5 to 12 , it contains the core of the BSL.

Extra comment:
 1) BSL versions of 2.01 & higher do not! protect info flash during mass erase.
 2) BSL versions of 1.60 & higher do an automatic erase check after an erase.
    The ACK flag signals an succes, a NACK a not succes! The erase
    check instructions are not implemented here!!!
 3) A mass erase must be executed at least 12 times to ensure
    A total erasure time of 200 ms or larger. For the MSP430G2553
    this is minimal 20 ms!!
 4) The cumulative program time of a 64-byte flash block must not
    exceed 10 ms for the MSP430G2553.
 5) Location FFDE may be used to secure the flash programming.
    AA55 = Disable BSL, 0000 = Disable erasure.
 6) For the MSP430G2553 Receive = P1.5, Transmit = P1.1
 7) Timing for BSL entry improved must be at least a 100 us wait!
 8) Take care when using an incorrect password a MASS-ERASE is done!!
    This leaves you without correct DCO constants.
 9) It takes almost 16 seconds to perform a CLONE action
10) Connections from programmer to target
    Programmer         Target 
    --------------------------------
    P2.0 = Output   -> P1.5 RX
    P2.1 = Input    -> P1.1 TX
    P2.2 = Test     -> TST
    P2.3 = Reset    -> RST
    VCC             -> VCC
    GND             -> GND
    --------------------------------
    P1.0 = red led, P1.6 = green led
11) This version is for the 16MHz, 38k4 Egel kit
 *)


hex chere

routine WAIT-BIT  ( -- a )      \ Wait bittime
    dm 545 # day mov
    begin,  #1 day sub  =? until,
    rp )+ pc mov  ( ret )
end-code

code BSL-EMIT   ( char -- )     \ RS232s Char to RS232
    #0 sun mov   ( Make parity even, code Albert Nijhof)
    tos day mov
    begin,     
        day sun bix             \ Gather lowest bit
        day rra                 \ Shift char to right
    =? until,                   \ Until no bits are left high
    #1 sun bia                  \ Use bit 0 only
    sun swpb                    \ Use parity as bit-8
    sun tos bis                 \ Add to char
    200 # tos bis               \ Bit-9 is stopbit
    tos tos add                 \ Make room for startbit
    0B # moon mov               \ Start + 8 + Parity + Stop bits
    begin,
        tos rrc                 \ Get next bit to carry
        cs? if,
            #1 29 & bis         \ Send one
        else,
            #1 29 & bic         \ Send zero
        then,
        wait-bit # call         \ Wait bittime
        #1 moon sub             \ Send all bits
    =? until,
    sp )+ tos mov
    next
end-code

\ A timeout of 4 ms is added to the startbit loop.
\ When a timeout occurs a NACK (A0) is left on the stack.
code BSL-KEY    ( -- char )     \ rs232s read char from rs232
    tos sp -) mov
    1000 # moon mov             \ ~ 4 millisec. timeout
    begin,
        #1 moon sub
        =? if, A0 # tos mov next then,  \ Leave NACK at timeout
        #2 28 & bit             \ wait for startbit
    cc? until,
    30 # moon mov               \ wait extra to reach sample point
    begin,  #1 moon sub  =? until,
    #8 moon mov                 \ read 8 databits
    begin,                      \ Leave stopbit
        wait-bit # call         \ wait bittime
\ )     20 # 21 & bix           \ Trace sample moment at P1.5
        #2 28 & bit             \ read rx line to carry
        tos rrc                 \ shift rx into char
        #1 moon sub             \ return at stopbit
    =? until,
    wait-bit # call             \ wait bittime for parity
    wait-bit # call             \ wait bittime for stopbit
\ ) 20 # 21 & bix               \ Trace stopbit moment at P1.5
    tos swpb
    #-1 tos .b bia              \ Use low byte only
    next
end-code


\ BSL programmer for Launchpad and/or Egel kit

: ?SIGNAL       ( fl -- )       \ Red is on when fl = true, otherwise green
    if      01 21 *bis  40 21 *bic 
    else    40 21 *bis  01 21 *bic  
    then ;

: LEDS-OFF      ( -- )   41 21 *bic ;

code SPLIT      ( x -- bl bh )  \ Split word in bl=lowbyte bh=highbyte
    tos day mov
    #-1 day .b bia
    day sp -) mov
    tos swpb
    #-1 tos .b bia
    next
end-code

: SETUP-BSL     ( -- )      \ P2.0 is Output, P2.1 is Input
    02 2A *bic  0D 2A *bis  \ P2.2 is Test, P2.3 is Reset
    01 29 c!  10 ms ;       \ P2.0 is high, rest low

: RESET-TO-BSL  ( -- )
    08 29 *bic  10 ms               \ Reset low & wait
    04 29 *bis  noop  04 29 *bic    \ Test pulse 1
    04 29 *bis  1 ms  08 29 *bis    \ Pulse 2 & BSL reset
    1 ms  04 29 *bic  1 ms ;        \ Wait and release test

: RESET-CLONE   ( -- )      08 29 *bic  1 ms  08 29 *bis ;  \ Give reset
: ACK?          ( -- fl )   bsl-key 90 = ;  \ Check for ACK=true
: NACK?         ( -- fl )   ack? 0=  dup ?signal ;  \ noAck=true

: SYNC          ( -- )      \ Sync RS232 for BSL
    2 ms  80 bsl-emit  nack? ?abort  2 ms ;

: WAITACK       ( -- )      \ Wait max. 500 ms for an ACK
    80 0 ?do
        ack? if 
            false ?signal  unloop  exit
        then
    loop  true ?signal  true ?abort ;

value CHK   \ Generate checksum for commands
: INIT          ( -- )          0 to chk  leds-off ;
: CHECKSUM      ( b1 b2 -- )    >< or  chk xor  to chk ;
: SEND-CHECKSUM ( -- )          chk invert  split >r  bsl-emit  r> bsl-emit ;
: BSL-DATA      ( b1 b2 -- )    over bsl-emit  dup bsl-emit  checksum ;

\ A command contains:  Header of 8 bytes, data block & checksum
\  |80|cmd|L|L'| AL| AH| Ll | LH| data block | CKL | CKH | 
\  Answer most of the time an ACK = 90
: COMMAND)      ( adr len2 len1 command -- adr len2 )
    sync  init  80 swap bsl-data    \ a l2 l1  Sync first, then command
    4 + dup bsl-data                \ a l2     Send record length
    over split bsl-data             \ a l2     Send address
    dup split bsl-data ;            \ a l2     Send data length (max 250)

\ BSL command without data block
: COMMAND       ( adr len2 len1 command -- )
    command) 2drop  send-checksum ;

\ BSL command with data block
: DATACOMMAND   ( adr len2 len1 command -- flag )
    command)                        \ Send command frame
    bounds ?do                      \          Send data block
        i @ split bsl-data
    2 +loop
    send-checksum                   \ Finally checksum
    nack? ;                         \ Show if (no)Ack received? 

create PASS 20 allot                \ Hold BSL password
: EMPTY-PASS    ( -- )          pass 20 FF fill ; \ PW for empty MPU
: .PASS         ( -- )          pass 20 dump ;  \ Show used PW
: !PASS         ( x +n -- )     pass +  ! ;     \ Fill cell +n in PW array

: MODIFY-PASS   ( a -- )            \ Set PW for non empty noForth MPU's
    1E 0 do   FFDE i !pass  2 +loop  01E !pass ;

\ Used bootloader commands
: SEND-PASSWORD ( -- )      pass  0020   dup  10 datacommand ?abort ;
: WRITE-BLOCK   ( a +n -- )              dup  12 datacommand ?abort ;

: ERASE-FLASH   ( -- )
    ." E "  C000  A504  0000  16 command  waitack   \ Erase main
            1080  A502  0000  16 command  waitack ; \ Erase INFO-B

: WRITE-FLASH   ( -- )
    ." W "  1080 40 write-block     \ Copy INFO-B flash segment
    chere C000 ?do  i 80 write-block  80 +loop \ Copy main Flash
    FFC0 40 write-block ;           \ Copy vector table

\ Write used part of flash, vector table & segment-B of info flash
: CLONE         ( -- )
    setup-bsl  reset-to-bsl  send-password
    erase-flash  write-flash  100 ms reset-clone ;


(* DCO calibration for noForth C&V for MSP430G2553

    The program uses the capture unit to build a
    PLL = Phase Locked Loop to adjust the DCO frequency
    It does so by comparing the DCO to a 32KHz external 
    clock, divided by 8 = 4096 Hz. 1 Mhz counts exactly to 244
    in one 4096 Hz period. The routine GET-DCO trims the DCO
    and then checks the count again, until 244 is reached.
    No more no less! Finally the values are stored in 
    the INFO-A flash segment.

    Current version is more accurate by capturing the
    DCO two times. Doing it this way, the DCO runs at a
    stable frequency. By feeding the routine with real
    DCO values is stabilizes very quick.

    0244 =  1 MHz capture value, DCO seed 86D4, address 10FE
    1953 =  8 MHz capture value, DCO seed 8D8A, address 10FC
    2930 = 12 MHz capture value, DCO seed 8E95, address 10FA
    3906 = 16 MHz capture value, DCO seed 8F8F, address 10F8

    By putting this routine in the APP vector the damaged
    MSP is automaticly corrected. The program does nothing 
    when the DCO values are not erased!

    DCO values are DC0CTL & BCSCTL1
    In a word: |BSCTL1|DCOCTL|
 *)

code GET-DCO    ( delta-freq dco-seed -- dco-parameters )
    tos 056 & .b mov  \ Seed lowbyte to DCOCTL
    tos swpb
    tos 057 & .b mov  \ Seed highbyte to BCSCTL1
    sp )+ tos mov
    30 # 057 & .b bis \ BCSCTL1  Setup Timer A & capture
    5100 # 162 & mov  \ TA0CCTL0  Capture on rising edge, using ACLK
    0224 # 160 & mov  \ TA0CTL  Source=SMCLK, cont. mode, clear TA
\ Capture DCO two times, for more accurate measurement
    begin,
      begin,  #1 162 & bit  cs? until,  \ Capture1?
      #1 162 & bic
      172 & moon mov  \ TA0CCR0  Get timer
      begin,  #1 162 & bit  cs? until,  \ Capture2?
      #1 162 & bic
      172 & day mov   \ TA0CCR0  Get timer
\ Test against delta value and go adjust DCO
      moon day sub    \ Calc. capture difference
      tos day cmp     \ PLL check delta against capture difference
      =? if,    \ Delta is equal?
          #0 162 & mov  \ TA0CCTL0
          #0 160 & mov  \ TA0CTL
          30 # 057 & .b bic \ BCSCTL1
          057 & tos .b mov
          tos swpb      \ High byte = BCSCTL1
          056 & day .b mov  \ Low byte = DCOCTL
          day tos bis
          next 
      then,
      >? if,    \ Delta is greater, DCO is to slow
          #1 056 & .b add   \ Increase DCOCTL
        2over cs? until,    \ Overflow?
          #1 057 & .b add   \ Increase BCSCTL1
        2over again,
      then,             \ Delta is smaller, DCO is to fast
      #1 056 & .b sub   \ Decrease DCOCTL
    2dup cc? until,     \ Underflow?
      #1 057 & .b sub   \ Decrease BCSCTL1
    again,
end-code

code {I         ( -- )  \ Activate INFOA Flash write sequence
    sr day mov          \ Save status register
    #8 sr bic           \ Interrupts off
    A540 # 012C & mov   \ Disable lockA
    A540 # 0128 & mov
    next 
end-code

code I}         ( -- )  \ End INFOA Flash write sequence
    A500 # 0128 & mov
    A550 # 012C & mov   \ Enable lock & lock A
    #8 day and>         \ Restore interrupt enable
    day sr bis
    next 
end-code

\ Calibrate all four DCO constants and write to flash
\ but only when there are no DCO constants
: CALIBRATE-DCO ( -- )
( ) 0C 053 *bis         \ Xcap=12.5pF
( ) begin  1 053 bit* 0= until \ Wait for LFXT1 correct
    dm 0244 86D4 get-dco     \ 1 Mhz
    dm 1953 8D8A get-dco     \ 8 MHz
    dm 2930 8E95 get-dco     \ 12 MHz
    dm 3906 8F8F get-dco     \ Get 16 Mhz constants
    10FF 10F8 do  i {i ! i}  2 +loop ; \ Write

\ Rewrite DCO constants but only when they are erased
: RESTORE-DCO   ( -- )
    10F8 @ -1 =         \ DCO constants erased?
    dup ?signal  if     \ Yes, show
        calibrate-dco   \ Calibrate & write them
    then ;


  ' restore-dco  to app \ RESTORE-DCO in startup vector
  DB0E modify-pass      \ Set BSL noForth password c2553 Lp 160228
\ DB14 modify-pass      \ Set BSL noForth password C2553 LP 160202
\ empty-pass            \ Set BSL empty MSP430 password
freeze

chere swap - dm u.  ( Show size )

                              ( End )
