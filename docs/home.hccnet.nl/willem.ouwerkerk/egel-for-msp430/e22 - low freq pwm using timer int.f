(* E22 - For noForth C&V2553 lp.0, Using timer-A0 to build software PWM. 
  Three PWM outputs using timer-A0
  Generating 300Hz PWM at P2.2, P2.3 and P2.4 in steps from 0 to 100
  This PWM interrupt leaves small glitches when power is zero!
  The user word is: SHOW-PWM

     FEDCBA9876543210 bit-numbers
  BN 0000000000011100 - #OUTPUT  Choose output bit2 to bit4
  BN 0000000011000000 - #OUT     toggle output
  BN 0000001000010100 - #PWM     TA clear, up, SMCLK, no presc.

  Addresses for Timer-A0
  160 - TA0CTL     Timer A control
  162 - TA0CCTL0   Timer A Comp/Capt. control 0
  172 - TA0CCR0    Timer A Comp/Capt. 0

  Addresses for Timer-A1
  180 - TA1CTL     Timer compare mode
  182 - TA1CCTL0   Output mode at P2.0 or P2.3
  192 - TA1CCR0    PWM at P2.0 or P2.3

  0029  - P2OUT     P2 output register 
  002A  - P2DIR     P2 direction register

  FFE2      - Timer-A0 interrupt vector
 *)

hex
\ Space for three PWM values
create POWER  3 cells allot

\ Period length is 100 clock cycles here
\ Set pulselength in steps from 0 to dm 100
: >POWER    ( u +n -- )
    >r  dm 100 umin  r> 2 umin cells power + ! ;

\ This interrupt subroutine leaves small glitches when power is zero
code PWM    ( -- )
    sun push                \ 1
    power # sun mov         \ 2 Load address pointer
    sun )+ xx cmp           \ 1 Equal?
    =? if,                  \ 2
        #4 029 & .b bic     \ 2 P2OUT  Clear output P2.2
    then,
    sun )+ xx cmp           \ 1 Equal?
    =? if,                  \ 2
        #8 029 & .b bic     \ 2 P2OUT  Clear output P2.3
    then,
    sun )+ xx cmp           \ 1 Equal?
    =? if,                  \ 2
        10 # 029 & .b bic   \ 3 P2OUT  Clear output P2.4
    then,
    dm 100 1- # xx cmp      \ 2 Period finished
    =? if,                  \ 2
        01C # 029 & .b bis  \ 3 P2OUT  Set outputs
        #-1 xx mov          \ 1 Reload counter
    then,
    #1 xx add               \ 1 Increase counter
    rp )+ sun mov           \ 1 Pop original sun
    reti                    \ 1
end-code

code INT-ON     #0 xx mov  #8 sr bis  next  end-code
code INT-OFF    #8 sr bic  next  end-code

\ PWM at Px,y etc.
: PWM-ON    ( -- )
    1C 02A *bis             \ P2DIR    P2.2 to P2.4 outputs
    0000  160 !             \ TA0CTL   Stop timer-A0
    0100  172 !             \ TA0CCR0  Interrupt frequency
    0214  160 !             \ TA0CTL   Start timer
    0010  162 **bis         \ TA0CCTL0 Enable compare 0 interrupt
    int-on ;                \ Activate

: PWM-OFF   ( -- )
    0000 160 !              \ TA0CTL   Stop timer
    0010 162 **bic ;        \ TA0CCTL0 Disable interrupt

\ Demonstration of PWM use
: CYCLE     ( -- )
    dm 100 0 ?do
        i 0 >power          \ Min to Max PWM
        dm 100 i - 1 >power \ Max to min PWM
        i 2* 2 >power       \ Min to Max PWM *2
        40 ms               \ Wait 
    loop ;

\ This example lets all three outputs change, after
\ leaving the program all outputs are zero!
: SHOW-PWM  ( -- )
    pwm-on  begin  cycle key? until
    0 0 >power  0 1 >power  0 2 >power ;

['] pwm >body FFF2 vec!     \ Install Timer-A0 vector
shield PWM\  freeze

\ End

