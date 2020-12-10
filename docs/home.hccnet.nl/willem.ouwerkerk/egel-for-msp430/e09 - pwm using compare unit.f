(* E09 - For noForth C&V 200202: Port input using switches
  at P1.4 & P1.5 . Using the onboard P1.0 led as output.
  Pulswidth power control with 4KHz PWM at P2.4 or P2.5
  with a resolution of 1000 steps

  Port-1 must be wired to 2 switches, placed on the launchpad
  experimenters kit, Wire P1.4 & P1.5 to the switches on the breadboard.
  The pinlayout can be found in the hardwaredoc of the launchpad.
  Port-1 bit 3 holds a switch on the Launchpad board.

  P2.4 must be wired to a logic power FET like the BUK954 using
  a suppression diode like 1N4001. Any 5 or 6 Volt DC motor or lamp
  may be used. Take care for the maximum USB-driver current of 150mA!

  Address 020 = P1IN, port-1 input register
  Address 022 = P1DIR, port-1 direction register
  Address 027 = P1REN, port-1 resistor enable
  Address 029 = P2OUT, port-2 output with 8 leds
  Address 02A = P2DIR, port-2 direction register
  Address 02E = P2SEL, port-2 selection register
  Address 180 = TA1CTL, timer a1 compare mode
  Address 186 = TA1CCTL2, timer a1 output mode
  Address 192 = TA1CCR0, timer a1 period timing
  Address 196 = TA1CCR2, timer a1 Duty cycle

  FEDCBA9876543210 bit-numbers
  0000000000010000 - Choose output bit4 or bit5
  0000000011000000 - toggle-set output
  0000001000110100 - TA clear, up/down, SMCLK, no presc.
 *)

hex
\ Period length is 1000 clock cycles ( #CYCLUS )
dm 1000 constant #CYCLUS
value POWER

: STOP-TIMER1       0 180 ! ;   \ TA1CTL
: PWM-OFF           stop-timer1  10 2E *bic ; \ P2SEL

: SET-PWM           ( 0 to #CYCLUS -- )
    #cyclus umin  196 !         \ TA1CCR2   Set pulselength
    10 29 *bic ;                \ P2OUT

\ PWM AT 2.4 or P2.5
: SETUP-PWM         ( -- )
    38 22 *bic 38 21 *bis       \ P1DIR,  P1IN  P1.3 to P1.5 are inputs
    38 27 *bis                  \ P1REN   with pullup
    10 2E *bis 10 2A *bis       \ P2SEL, P2DIR  Set PWM to output pin P2.4
    stop-timer1  #cyclus 192 !  \ TA1CCR0  Set period time
\   C0 186 !                    \ TA1CCTL2 Set output mode negative pulse
    40 186 !                    \ TA1CCTL2 Set output mode positive pulse
    234  180 !                  \ TA1CTL   Activate timer
    0 to power ;

: LOWER             power if  -1 +to power  then ;
: HIGHER            power #cyclus u< if  1 +to power  then ;

\ The switch on P1.4 is the increase speed key
\ The switch on P1.5 is the decrease speed key
: SET-POWER         ( -- )
    10 20 bit* 0= if  higher  then    \ P1IN
    20 20 bit* 0= if  lower   then    \ P1IN
    power set-pwm  2 ms  power .
    ;

\ Two demonstrations of pulsewidth modulation power control
: CYCLUS        setup-pwm  #cyclus 1+ 0 ?do  i set-pwm 02 ms  loop  pwm-off ;
: POWERCONTROL  setup-pwm  begin  set-power  key? until  pwm-off ;

pwm-off  freeze

                              ( End )
