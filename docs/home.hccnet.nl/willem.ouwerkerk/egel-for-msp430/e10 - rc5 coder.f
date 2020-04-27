(* E10 - For noForth C&V2553 lp.0, bit input, output, timer A1 generates 36KHz PWM.
  RC5 transmitter, software generates RC5-bitpatterns on MSP430 Launchpad.
  Timer A1 generates 36KHz carrier wave with 25% duty cycle at output P2.1
  According RC-5 specs, about every 114 milliseconds there may be a RC-burst.

  Switch S2 activates the transmitter, if S2 remains pressed the keycode is 
  repeated every 114 ms.

  Using the Egel kit, connect an IR-led to the LED connector and ready.

  The settings for P2.0 will be found from page 50 and beyond of SLAS735J.PDF,
  settings for timer A1 can be found on page 356 and beyond of SLAU144J.PDF 

  Bitpatterns and I/o-adresses

   FEDCBA9876543210 bit-numbers 
   0000000000000010 = #OUTPUT \ Choose output bit1 - 0002
   0000000011100000 = #OUT    \ Reset-set output   - 00E0
   0000001000010100 = #PWM    \ TA clear, up-mode, SMCLK, no presc. - 0214

Similar addresses for Timer-A0
160 = TA0CTL   - Timer A0 controle 
162 = TA0CCTL0 - Timer A0 Comp/Capt. controle 0 
172 = TA0CCR0  - Timer A0 Comp/Capt. 0 
174 = TA0CCR1  - Timer A0 Comp/Capt. 1 
0000 0010 0001 0100 = 0214 - TA is zero, count up, SMCLK, presc. /1

Adresses for Timer-A1
180 = TA1CTL   - Timer A1 controle              Compare mode - 0214
184 = TA1CCTL1 - Timer A1 Comp/Capt. contr. 0   Output mode Set/Reset - 000E
192 = TA1CCR0  - Timer A1 Comp/Capt. 0          Period timing - 00DA
194 = TA1CCR1  - Timer A1 Comp/Capt. 1          Dutycycle - 0036
0000 0010 0001 0100 = 0214 - TA is zero, count up, SMCLK, presc. /1

021 = P1OUT    - P1 output registers
022 = P1DIR    - P1 direction
029 = P2OUT    - P2 output registers - 02
02A = P2DIR    - P2 direction
02E = P2SEL    - P2 select

Used pins:
P2.1 RC5 Output IR led
P1.3 Switch S2
P1.6 Green led
 *)

hex
: GREEN  40 021 ;           \ P1OUT  Green led at P1.6

: FLASH         ( -- )
    green *bis  dm 10 ms    \ Led on and off
    green *bic  dm 80 ms
    ;    

\ Period length is 222 clock cycles ( ~36KHz )
dm 222 constant #CYCLUS

: OSC-OFF       0 180 ! ;    \ TA1CTL   Stop timer-A1
: RC5-OFF       osc-off  02 02E *bic  02 029 *bic ; \ P2SEL, P2DIR

\ 25% PWM op P2.1
: RC5-ON       ( -- )
    02 02A *bis             \ P2DIR  Make P2.1 output
    08 022 *bic             \ P1DIR  Make P1.3 input
    osc-off                 \ Stop timer
    #cyclus 1-  192 !       \ TA1CCTL1  Set period time
    E0 184 !                \ TA1CCTL1  Set output mode
    dm 55  194 ! ;          \ TA1CCR1   Pulsewidth 25% (222/4 = 54)

code INT-ON     ( -- )      #8 sr bis  next  end-code
code INT-OFF    ( -- )      #8 sr bic  next  end-code

\ Bit 6 t/m 10 are system bits and contain the device address
\ Bits 11, 12 and 13 are the start and control bits, here aways high!
\ TV = E0 -> 3800, CD = F4 -> 3D00 and VCR = E5 -> 3940
\ F4  6 lshift  constant RC-TYPE    \ RC5 CD transmitter type
\ E5  6 lshift  constant RC-TYPE    \ RC5 VCR transmitter type
  E0  6 lshift  constant RC-TYPE    \ RC5 TV transmitter type

routine HALFBIT-ON ( -- )           \ Wait 878 us ~ 7026 ticks
    #2 02E & bis                    \ 2 P2SEL   PWM on P2.1
    214 # 180 & mov                 \ 3 TA1CTL  PWM on
    dm 2338 # xx mov                \ 2 ticks
    begin,
        #-1 xx add                  \ 1 tick
    =? until,                       \ 2 ticks
    rp )+ pc mov                    \ 2 + 3 ticks  (RET)
END-CODE

routine HALFBIT-OFF ( -- )          \ Wait 878 us ~ 7027 ticks
    #2 02E & bic                    \ P2SEL   Normal output on P2.1
    #2 029 & bic                    \ P2OUT   Output low
    #0 180 & mov                    \ TA1CTL  PWM off
    dm 2338 # xx mov                \ 2 ticks
    begin,
        #-1 xx add                  \ 1 tick
    =? until,                       \ 2 ticks
    rp )+ pc mov                    \ 2 + 3 ticks  (RET)
end-code

\ Send 1-bit of rc5-word
code RC-ZEND        ( b1 -- b2 )
    2000 # tos bit                  \ Test bit 14
    cs? if,                         \ High bit?
        halfbit-off # call          \ Yes, send one
        halfbit-on  # call
    else,
        halfbit-on  # call          \ No, send zero
        halfbit-off # call
    then,
    tos tos add                     \ Next bit
    next
end-code

: RC-EMIT           ( b -- )        \ Send 14 bits from stack, ~25 millisec.
    int-off  rc5-on                 \ Set interrupts off, init. 36Khz at 25%
    003F and  rc-type or            \ Build a 14 bits word
    dm 14 0 do  rc-zend  loop  drop \ Send these 14 bits
    rc5-off  int-on ;               \ 36KHz off, interrupts on

\ This routine sends an RC-5 start code, each time S2 is pressed
\ the green led flashes short too, it exits on any RS232 keypress
: RC-TRANSMITTER    ( -- )          \ Send RC5 On/Off code
    02 029 *bic                     \ P2OUT  Start with ir-led off
    begin
        flash                       \ Show activation
        begin  s? 0=  key? or until \ Wait for key press
    key? 0= while
        dm 12 rc-emit               \ Send On/Off code
    repeat ;

shield rc5t\
' rc-transmitter  to app  freeze    \ RC-TRANSMITTER is executed at startup

\ End
