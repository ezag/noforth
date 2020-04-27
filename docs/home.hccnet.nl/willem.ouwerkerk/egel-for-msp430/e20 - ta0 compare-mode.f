(* E20 - For noForth C&V2553 lp.0, bit output, timer interrupt with machine code, 
  on MSP430G2553 using port-1. More info, see page 369 and beyond of SLAU144J.PDF
  Flashing LEDS using a timer compare interrupt, using SMCLK or ACLK
  Compare mode 2 is used here, means counting to FFFF. Uses register R11=XX. 
  The frequency may be adjusted by changing the value PERIOD 
  A higher value means slower flash frequency, default is 1
  Forth words are: SMCLK-ON  ACLK-ON  TIMER-OFF

  Register addresses for Timer-A
160 - TA0CTL   Timer A control
162 - TA0CCTL0 Timer A Comp/Capt. control 0
172 - TACCR0   Timer A Compare register

  Bits in TA0CCTL0
010 - CCIE       \ Enable compare capture intrpt
  Bits in TA0CTL with SMCLK
004 - TACLR      \ Reset TAR register {bit2}
020 - MC-1       \ Timer counts to FFFF {bit4,5}
040 - ID-3       \ Input divider /2 {bit =6,7}
200 - TASSEL-2   \ SMCLK as clock source {bit8,9}
  Bits in TA0CTL with ACLK
000 - ID-3       \ Input divider /1 {bit =6,7}
100 - TASSEL-2   \ 32kHz ACLK as clock source {bit8,9}
021 - P1OUT      \ Output reg.
022 - P1DIR      \ Direction reg.
008 - GIE        \ General interrupt enable bit
 *)

hex
value PERIOD            \ Extra divider
code INT-ON     ( -- )  #8 sr bis  next  end-code
code INT-OFF    ( -- )  #8 sr bic  next  end-code
code INIT-TIMER ( -- )  adr period & xx mov  #8 sr bis  next  end-code

\ Interrupt subroutine
routine TIMER-INT   ( -- )
    #-1 xx add              \ Decrease divider
    =? if,                  \ Zero?
        adr period & xx mov \ Reload divider
        41 # 021 & xor>     \ P1OUT  Toggle both LEDs
    then,
    reti
end-code

\ Timer compare interrupt off
: TIMER-OFF     ( -- )  int-off  010 162 **bic ; \ TA0CCTL0

\ Set timer compare interrupt on with SMCLK and init. leds
\ Clockdivider=/2, Up mode & Timer A clear.
: SMCLK-ON      ( -- )
    int-off  41 022 *bis    \ P1DIR    Set pins with LED1,2 to output
    01 021 *bis 40 021 *bic \ P1OUT    Set red led on, green off
    264 0160 !              \ TA0CTL   Set timer mode to SMCLK/2
    010 0162 **bis          \ TA0CCTL0 Enable interrupts on Compare 0
    1 to period init-timer  \ Activate timer
    ;

\ Set timer compare interrupt on with ACLK and init. leds
\ Clock divider=/1, Up mode & Timer A clear.
: ACLK-ON       ( -- )
    int-off  41 022 *bis    \ P1DIR    Set pins with LED1,2 to output
    01 021 *bis 40 021 *bic \ P1OUT    Set red led on, green off
    124 0160 !              \ TA0CTL   Set timer mode to ACLK/2
    010 0162 **bis          \ TA0CCTL0 Enable interrupts on Compare 0
    01 to period init-timer \ Activate timer
    ;

timer-int  FFF2 vec!        \ Timer-A0 vector
shield TIMER0\  freeze
smclk-on
