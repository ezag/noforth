(* E27A - For noForth 2553 lp.0, C&V version: Period time measurement
   using timer-A0. Led tracing if wanted at P1.0 This code needs 16 MHz DCO!
   Period time measurement for use as RPM counter, laptimer, etc.
   Uses machine code, timer-A0 interrupt, hardware interrupt & arithmetic.

Note! Change the DCO frequency for noForth to 16 MHz using: Patch 2553.f

Do not forget to add this redefinition before loading the assembler:  : ##  # ;
The default Forth # operator is redefined in the MSP430 assembler!!

Used registers adresses

020 = P1IN      - Input register
021 = P1OUT     - Output register
022 = P1DIR     - Direction register
023 = P1IFG     - Interrupt flag
024 = P1IES     - Interrupt edge select
025 = P1IE      - Interrupt enable
027 = P1REN     - Resistance on/off
FFE4            - P1 Interrupt vector

Addresses for Timer-A0
160 = TA0CTL   - Timer A0 control
162 = TA0CCTL0 - Timer A0 Comp/Capt. control 0
172 = TA0CCR0  - Timer A0 Comp/Capt. 0
170 = TA0R     - Timer A0 register
23D =
FFF2           - Timer A0 Interrupt vector
00000010.00100100 = 0224 - TA is nul, overflow mode, SMCLK, presc. /1

P1.3 is the input, the measurements are printed by the user word PERIOD
The absolute maximum timer resolution of 0,0625us is chosen here.
The precision may be bettered in two ways:
    1) Using an external chrystal op 16 MHz
    2) Adjusting the DCO by trimming it, see: ....
    http://hackaday.com/2015/03/15/calibrating-the-msp430-digitally-controlled-oscillator/
    http://forum.43oh.com/topic/211-flashing-the-missing-dco-calibration-constants/
 *)

hex

code INT-ON     #8 sr bis  next  end-code
code INT-OFF    #8 sr bic  next  end-code

\ Note! Change the DCO frequency of noForth to 16 MHz using: Patch 2553.f

value (HIGH     \ 32-Bit counter, low part in TA0R
value HIGH      \ 32-Bit counter
value LOW
value READY?    \ Start new measurement cyclus
value CYCLE?    \ One complete cycle

\ Counter resolution is 1/16 microsec.
\ The high part is increased every $1000 microsec.
routine COUNTER        ( -- )
\ ) #1 021 & .b xor>                \ P1OUT  Flash green led
    #1  adr (high & add
    reti
end-code

routine START/STOP
\ ) #1 021 & .b xor>                \ P1OUT  Flash red led
    #0 adr ready? & cmp  <>? if,    \ Measurement sample not used?
        #8 023 & .b bic             \ P1IFG  Do nothing
        reti
    then,
    #0 adr cycle? & cmp  =? if,     \ Start new cycle?
        #0 170 & mov                \ TA0R   Reset cycle duration
        #0 adr (high & mov
        #-1 adr cycle? & mov        \ Measurement started
    else,
        170 & adr low & mov         \ TA0R   save pulsduration low
        adr (high &  adr high & mov \ and high part
        #0 adr cycle? & mov         \ Complete period measured!
        #-1 adr ready? & mov        \ Measurement ready!
    then,
    #8 023 & .b bic                 \ P1IFG  Reset hw interrupt flag
    reti
end-code

: MEASURE-OFF       ( -- )
    int-off                     \ Deactivate
    0000 160 !                  \ TA0CTL   Stop timer-A0
    0000 162 ! ;                \ TA0CCTL0 Interrupts off

: MEASURE-ON        ( -- )
\ Set timer interrupt ready
    0224 160 !                  \ TA0CTL Start timer, see doc. above
    0010 162 !                  \ TA0CCTL0 Compare 0 interrupt on
\ Set hardware interrupt ready
    08 020 *bic                 \ P1IN  Bit-3= input
    08 027 *bis                 \ P1REN Bit-3= resistor on
    08 021 *bis                 \ P1OUT Bit-3= pullup
    08 024 *bis                 \ P1IES Bit-3= falling edge
    08 025 *bis                 \ P1IE  Bit-3= interrupt on
    08 023 *bic                 \ P1IFG Bit-3= reset interrupt flag
    0 to cycle?                 \ Period not started!
    0 to ready?                 \ Allow measurement
    int-on ;                    \ Activate

: WAIT              ( -- )      \ Wait for next measurement
    0 to ready?                 \ Allow new measurement
    begin  key? if exit then  ready? until ; \ Next period done!


\ First application, a period time meter at P1.3

\ Divide double x by the single y leaving the double rounded quotient z
: dur/      ( xlo xhi y -- zlo zhi )    \ With rounding
    dup >r   du/s   ( dz rest )
    r> over - u< 1+ 0 d+ ;

\ Measurement range 0 to 107,374.182 seconds.
\ Note that # is replaced by ## to avoid assembler conficts.
: .PERIODLENGTH      ( -- )
    low high 05 du*s 08 dur/     \ Make rounded microsec.
    <# ## ## ## ##  ch . hold  ## ## ##  ch , hold  #s #> type ."  Sec. " ;

: PERIOD            ( -- )
    measure-on  decimal
    begin
        cr cr ." 'Egel period length meter " cr
        begin
            wait  cr ." Period length: " .periodlength
        key? until
    key bl <> until
    measure-off  cr ." Stopped " ;

start/stop  FFE4 vec!       \ Install P1 vector
counter     FFF2 vec!       \ Install TA0 vector
shield period\  freeze

\ End
