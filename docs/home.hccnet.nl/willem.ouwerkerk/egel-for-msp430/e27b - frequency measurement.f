(* E27B - For noForth 2553 lp.0, C&V version: Frequency measurement
   using timer-A0. Led tracing if wanted at P1.0
   Period time measurement for use as RPM counter, laptimer, etc.
   Uses machine code, timer-A0 interrupt, hardware interrupt & arithmetic.

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

P1.3 is the input, the measurements are printed by the user word FREQUENCY
The absolute maximum timer resolution of 0,0625us is chosen here.
The precision may be bettered in two ways:
    1) Using an external chrystal op 16 MHz
    2) Adjusting the DCO by trimming it, see: ....
    http://hackaday.com/2015/03/15/calibrating-the-msp430-digitally-controlled-oscillator/
    http://forum.43oh.com/topic/211-flashing-the-missing-dco-calibration-constants/
 *)

hex
\ Divide double x by the double y leaving the double rounded quotient z
: du/du ( xlo xhi ylo yhi -- zlo zhi )  \ z = x/y
    dup
    if  begin
            du2/ 2>r
            du2/ 2r>
        dup 0= until
    then
    drop  dur/ ;

\ Valid range from 0,5 Hz to 100.000 Hz with 16MHz clock
: .FREQUENCY        ( -- )
    dm dn 160,000,000  low high du/du
    <# ## ch . hold #s #> type ."  Hz " ;

: FREQUENCY          ( -- )
    measure-on  decimal
    begin
        cr cr ." 'Egel frequency measurement "
        begin  wait  cr .frequency  100 ms  key? until
    key bl <> until
    measure-off  cr ." Stopped " ;

start/stop   FFE4 VEC!      \ Install P1 vector
counter      FFF2 VEC!      \ Install Timer-A0 vector
shield FREQUENCY\  freeze

\ End