(* E52 - For noForth C&V 200202: Low Power Mode. Bit output, watchdog
   interrupt,  with machine code, using port-1 and port-2.
   In low power mode it runs on an 32kHz XT, when active on the 8MHz DCO.
   Watchdog used as interval timer activates a running light.

  Wire 6 leds & resistor{s} or a led-print to P2.0 to P2.5 & ground

* The settings for the watchdog can be found from page 344
  and and beyond in SLAU144J.PDF

* Details about the setting of DCO clock from page 280, etc.
  of SLAU144J.PDF The settings for de baudrate from page 424, etc.
  of the same document. More on DCO setup data at page 15 of SLAS735J.PDF

    0 - IE1    Interrupt enable register 1
   21 - P1OUT  P1 output bits
   22 - P1DIR  P1 direction bits
   29 - P2OUT  P2 output bits
   2A - P2DIR  P2 direction bits
  120 - WDTCTL Watchdog timer control register
  More info about the setup of the setting of the system clock
  in the files XT1.F and XT2.F

  FFF4 - Watchdog timer interrupt vector

  MSP430 power modes name shortcuts & short explanation:
  AM   = Active Mode      - CPU & clocks active
  LPM0 = Low Power Mode 0 - CPU & MCLK disabled, DCO, SMCLK & ACLK active
  LPM1 = Low Power Mode 1 - Same as mode 0 except when DCO is not used
  LPM2 = Low Power Mode 2 - Only DC generator & ACLK active
  LPM3 = Low Power Mode 3 - Only ACLK active
  LPM4 = Low Power Mode 4 - CPU & clocks disabled
  More info at pages 28, etc. and page 45 of SLAU144J.PDF
 *)

hex
: >LEDS     ( b -- )    29 c! ; \ P2OUT
: FLASH     ( -- )      -1 >leds A0 ms  0 >leds A0 ms ;

code INT-ON     #8 sr bis  next  end-code
code INT-OFF    #8 sr bic  next  end-code
code LPM0       10 # sr bis  next  end-code \ Go from AM to LPM0
code LPM2       90 # sr bis  next  end-code \ Go from AM to LPM2
code LPM3       D0 # sr bis  next  end-code \ Go from AM to LPM3

: 32KHZ     ( -- )
    int-off
    40 57 c!        \ BCSCTL1   Switch 32KHz osc on
    C 53 c!         \ BCSCTL3   12pF
    begin           \ LFXT osc. running?
        2 2 *bic    \ IFG1      Clear bit 2
        noop  noop  \ Wait, Bit 2 remains clear
    2 2 bit* 0= until \ when osc. runs fine!
    C8 58 c!        \ BCSCTL2   LFXT1CLK on SMCLK
    81 61 c!        \ UCA0CTL1  uart use SMCLK
    03 62 c!        \ UCA0BR0   32 KHz, baudrate 9600
    00 63 c!        \ UCA0BR1
    06 64 c!        \ UCA0CTL0  modulation ucbrsx = 3
    01 61 *bic      \ UCA0CTL1  enable USCI
    A500 12A !      \ FCTL2     mclk/1=32KHz
    4 TO ms# ;      \ MS timing

\ Current use of CPU without leds = 2,56mA
: 8MHZ      ( -- )  \ Baudrate stayes 9600B
    int-off
    10FD c@ 57 c!   \ BCSCTL1   set dco = 8 mhz
    10FC c@ 56 c!   \ DCOCTL
    00 58 c!        \ UCA0CTL2  DCO on
    81 61 *bis      \ UCA0CTL1  uart use SMCLK
    41 62 c!        \ UCA0BR0   8 mhz, baudrate 9600
    03 63 c!        \ UCA0BR1   idem
    04 64 c!        \ UCAMCTL   modulation ucbrsx = 2
    01 61 *bic      \ UCA0CTL   enable USCI
    A550 12A !      \ FCTL2     mclk/17=470KHz flash timing
    7CF TO ms# ;    \ MS timing

value TIME)  \ Decreases each second
\ Clock = 32768/32768 longest interval 65535 sec.
\ Watchdog timer interrupt activated & I/O-port setup
: PREPARE     ( -- )     1 0 *bis  41 21 *bic  FF 2A *bis ; \ IE1, P1OUT, P2DIR
: WAKE        ( -- )     8mhz  5A94 120 !  int-off ;  \ WDTCTL
: SECONDS     ( u -- )   to time)  32khz  5A1C 120 !  int-on ;  \ WDTCTL

\ Decrease TIME) until it's zero
routine TIMER      ( -- )
    #0 adr time) & cmp
    =? if,
        F8 # rp ) bic   \ Interrupt off, CPU active again!
        reti
    then,
    #-1 adr time) & add
    reti
end-code

\ Running light
: RUNNER    ( -- )  1  8 for  dup >leds  2*  50 ms  next  drop ;

\ The main loop sets up for 32kHz XT and starts an interval timer.
\ Then activates a running light. After one run de CPU goes to sleep
\ mode LPM0 after activating a watchdog timer interrupt.
\ The watchdog timer generates an interrupt with one run of the lights.
\ Power use at 3V3: AM+leds=10,4mA; AM-leds=2,6mA; LPM0=26uA
: SLEEP0    ( -- )
    prepare  flash  5 for  runner  05 seconds  lpm0  wake  next ;

\ The main loop sets up for 32kHz XT and starts an interval timer.
\ Then activates a running light. After one run de CPU goes to sleep
\ mode LPM2 after activating a watchdog timer interrupt.
\ The watchdog timer generates an interrupt with one run of the lights.
\ Power use at 3V3: AM+leds=10,4mA; AM-leds=2,6mA; LPM2=25uA
: SLEEP2    ( -- )
    prepare  flash  5 for  runner  05 seconds  lpm2  wake  next ;

\ The main loop sets up for 32kHz XT and starts an interval timer.
\ Then activates a running light. After one run de CPU goes to sleep
\ mode LPM3 after activating a watchdog timer interrupt.
\ The watchdog timer generates an interrupt with one run of the lights.
\ Power use at 3V3: AM+leds=10,4mA; AM-leds=2,6mA; LPM3=2,2uA
: SLEEP3    ( -- )
    prepare  flash  5 for  runner  05 seconds  lpm3  wake  next ;

timer  FFF4 vec!    \ Install watchdog interrupt vector
shield LPM\  freeze

\ End
