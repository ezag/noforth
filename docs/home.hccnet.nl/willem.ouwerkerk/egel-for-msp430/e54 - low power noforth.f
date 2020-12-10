(* E54 - For noForth C&V 200202: Low Power Mode, RS232 interrupt
   using machine code. Redefining KEY , EMIT and MS to create
   a much lower avarage current use.

  This is an enhancement from previous code.
  This are the main routines:
    - SLEEP     goto deep sleep LMP4 I=0,0006mA and activate RX-interrupt
    - WAKE-RX   Wakeup when a new key arrives
    - WAKE-TX   Wakeup when emit is free to use
    - KEY}      Goto sleep when no KEY was received
    - EMIT}     Goto sleep when previous EMIT is still busy
    - MS1       A low power variant of MS uses the LPM0 I=0,36mA
    At a speed of 8MHz the CPU uses 2,6mA, average now 0,5mA
    when doing words. This is ofcourse dependent if the program.

    SLEEP must be placed before ACCEPT for example in REFILL
    INIT-SLEEP must be added to the cold start code.
    KEY} and EMIT} are the new i/o vectors.
    Right before .OK the leds must be put on, right there after
    SLEEP must be placed, it also puts the leds off!

    One bit in the OK flag register may be used for setting the
    sleep mode noForth is in to. A zero means minimal use of
    sleep modes, noForth only uses LPM0 where most clocks keep running.
    When this bit is one noForth uses deeper sleep modes. Like going
    into deep sleep before ACCEPT and using LPM2 to beyond save current.

  MSP430 power modes name shortcuts & short explanation:
  AM   = Active Mode      - 00 - CPU & clocks active
  LPM0 = Low Power Mode 0 - 10 - CPU & MCLK disabled, DCO, SMCLK & ACLK active
  LPM1 = Low Power Mode 1 - 50 - Same as mode 0 except when DCO is not used
  LPM2 = Low Power Mode 2 - 90 - Only DC generator & ACLK active
  LPM3 = Low Power Mode 3 - D0 - Only ACLK active
  LPM4 = Low Power Mode 4 - F0 - CPU & clocks disabled
  More info at pages 41, etc. and page 46 of SLAU144J.PDF

  21 - P1OUT            - Port-1 Ouput reg.
  01 - IE2    Bit-0,1   - Interrupt Enable reg. 2
  03 - IFG2   Bit-0,1   - Interrupt Flag reg. 2
  FFEE/FFEC             - RS232 RX/TX-interrupt vector

 About the avarage current use.

 Standard noForth uses about 10,5mA, without leds that is 2,6mA.
 The first current number is while the system waits for a key,
 the second current number is the average use while running.

 - DCO freq.  - LPM4-sleep  -      LPM2        -        LPM0
    1 MHz        0,0005mA     0,022mA/0,175mA       0,070mA/0,18mA
    8 MHz        0,0005mA     0,025mA/0,480mA       0,345mA/0,50mA
   16 MHz        0,0005mA     0,033mA/0,820mA       0,682mA/0,83mA

When bit 3 in OK is set, we are in LPM2 otherwise we are in LPM0
At the start of ACCEPT we are in LPM4 but only when bit 3 in OK is set.

The red & green led are used as visual prompt, the green signals an
OK, the red led an error condition.
Note that a vector XT for the wanted clock is preferable!
Default it contains the word 8MHZ
 *)

hex
code LPM0     ( -- )    18 # sr bis  next  end-code \ Go from AM to LPM0
code INT-OFF  ( -- )    #8 sr bic  next  end-code

\ Set DCO to 1 MHz, current use of CPU without leds = 0,35mA
: 1MHZ      ( -- )  \ Baudrate 9600b
    int-off  2 ms
    10FF c@ 57 c!   \ BCSCTL1   Set DCO = 1MHz
    10FE c@ 56 c!   \ DCOCTL
    0 58 c!         \ UCA0CTL2  DCO on
    81 61 *bis      \ UCA0CTL1  Uart use SMCLK
    68 62 c!        \ UCA0BR0   1 mhz, baudrate 9600
    00 63 c!        \ UCA0BR1   idem
    2 64 c!         \ UCA0CTL0  modulation ucbrsx = 1
    1 61 *bic       \ UCA0CTL   enable USCI
    A542 12A !      \ FCTL2     mclk/3=333KHz
    F9 to ms# ;     \ MS timing

\ Set DCO to 16 MHz, current use of CPU without leds = 5,03mA
: 16MHZ     ( -- )  \ Baudrate 9600B
    int-off  2 ms
    10F9 c@ 0057 c! \ BCSCTL1   Set DCO = 16MHz
    10F8 c@ 0056 c! \ DCOCTL
    0000 0058 c!    \ DCO on
    0081 0061 *bis  \ UCA0CTL   Uart use smclk
    0082 0062 c!    \ UCA0BR0   16 mhz, baudrate 9600
    0006 0063 c!    \ UCA0BR1
    000C 0064 c!    \ UCAMCTL   modulation ucbrsx = 6
    0001 0061 *bic  \ UCA0CTL   enable USCI
    A562 012A !     \ FCTL2     mclk/34=470KHz
    F9F to ms# ;    \ MS timing

code SLEEP      ( -- )
    41 # 21 & .b bic        \ P1OUT  Leds off
    #8  adr ok & bit        \ Low power mode?
    <>? if,
        #8 sr bic           \ interrupt off
        #1 1 & .b bis       \ IE2   RS232 RX interrupt on
        F8 # sr bis         \ Enter LPF4 & int. on (0,5uA)
    then,
    next
end-code

code EMIT}      ( c -- )
    #8 sr bic               \ Int off ^^^ important!!
    #2 1 & .b bis           \ IE2  RS232 TX interrupt on
    #8  adr ok & bit        \ Which power mode
    <>? if,
        98 # sr bis         \ Go from AM to LPM2
    else,
        18 # sr bis         \ Go from AM to LPM0
    then,
    tos 67 & .b mov         \ UCA0TXBUF  Send char
    sp )+ tos mov           \ Pop tos
    NEXT
end-code

code KEY}       ( -- c )
    tos sp -) mov           \ Push TOS
    #1 3 & .b bit           \ IFG2  Test RX flag
    =? if,                  \ Not set ?
        #8 sr bic           \ interrupt off ^^^ Important!
        #1 1 & .b bis       \ IE2   RX interrupt on
        #8 adr ok & bit     \ Which power mode?
        <>? if,
            98 # sr bis     \ Go from AM to LPM2
        else,
            18 # sr bis     \ Go from AM to LPM0
        then,
    then,
    066 &  tos .b mov       \ UCA0RXBUF  Get char
    next
end-code

\ Wakeup when KEY was received and exit low power mode
routine WAKE-RX    ( -- )
    #1 1 & .b bic           \ IE2  RS232 RX int. off
    F0 # rp ) bic           \ LPM off
    reti
end-code

\ Wakeup when EMIT was transmitted and exit low power mode
routine WAKE-TX    ( -- )
    #2 1 & .b bic           \ IE2  RS232 TX int. off
    F0 # rp ) bic           \ LPM off
   reti
end-code


\ MS with watchdog as interval timer
\ value MS#
routine MSTIMER    ( -- )   \ Decrease MS# until it's zero
    #0  adr ms# & cmp
    =? if,
        #1 0 & .b bic       \ IE1  Watchdog int. off
        F0 # rp ) bic       \ LPM off
        reti
    then,
    #1 adr ms# & sub
    reti
end-code

\ An MS routine using the Watchdog interval mode in LPM0,
\ This could go as far as LPM3 but noForth stops in LPM3.
\ And this is not desirable.
: (MS)          ( u x -- )
    120 !  to ms#           \ WDTCTL  Activate watchdog as MS-timer
    1 0 *bis  lpm0          \ IE1     Go to sleep with interrupt on
    5A91 120 !  1 0 *bic ;  \ WDTCTL, IE1  Stop watchdog & interrupt off

\ This variant should always be correct
: MS1           ( u -- )
    12A c@  ( FCTL2  Use  flash timing as reference )
    dup 00 = if  drop  1 lshift 5A1B (ms) exit  then        \ 32 KHz
    dup 42 = if  drop  dup 5A1A (ms)  5A1A (ms) exit  then  \ 1 MHz
        62 = if  dup 5A19 (ms)  then                        \ 16 MHz
    5A19 (ms) ;                                             \ 8 MHz

: SLEEP-ON      ( -- )  \ Set LPM RS232 variant routines
    int-off
    F7 22 *bis          \ P1DIR  Only P1.3 is input
    41 21 *bic          \ P1OUT  Leds off
    10 29 *bic          \ P2OUT  Set P2.4 (mosfet) off
    ['] emit} to 'emit  \ Replace vectors
    ['] key} to 'key
    5A91 120 ! ;        \ WDTCTL  Stop watchdog

: SLEEP-OFF     ( -- )  \ Restore old RS232 routines
    int-off
    ['] emit) to 'emit
    ['] key) to 'key ;

 wake-tx  FFEC vec!  \ Set TX interrupt.
 wake-rx  FFEE vec!  \ Set RX interrupt.
 mstimer  FFF4 vec!  \ Set Watchdog interrupt.

' sleep-on  to app
shield SLEEP\  freeze

\ End
