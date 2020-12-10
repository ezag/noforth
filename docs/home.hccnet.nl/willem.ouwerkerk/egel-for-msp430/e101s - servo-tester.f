(* E101s - for noForth C&V 200202 or later: Load noforth-asm.f first !
  Test model servo range using a pulse output at P1.4 with MSP430G2553
  The position is set by a potmeter on P1.7, S2 is used to print the
  current servo position in microseconds.

  P1.4 is wired to a servo on the launchpad experimenters kit.
  Take care that the servo does not pull to much current. An USB power supply
  usually gives up at about 150mA or 500 mA. Depending on the settings.

  Address 020 = P1IN,  port-1 input register
  Address 021 = P1OUT, port-1 input register
  Address 022 = P1DIR, port-1 direction register
  Address 029 = P2OUT, port-2 output with 8 leds
  Address 02A = P2DIR, port-2 direction register
  Address 02E = P2SEL, port-2 selection register 
  Address 160 = TA0CTL,   timer A0 output mode
  Address 162 = TA0CCTL0, timer A0 period timing
  Address 172 = TA0CCR0,  timer A0 Duty cycle 

  Divide 8.000.000/8 = 1 MHz
  So the timer-0 clock input pulse is 1 microsec.
  Take care the table #BITS must be changed too!!
   FEDCBA9876543210 bit-nummers
   0000000000110000 CONSTANT #OUTPUT \ Choose output bit4 and bit5
   0000001011010100 CONSTANT #CONFIG \ TA is zero, count up, SMCLK, presc. /8
 *)

hex             \ Space for PWM value and interrupt status
value PWM   value STATUS
: .PULSE    ( +n -- )           \ Show servo position in microseconds
    s? 0= if                    \ S2 pressed?
        cr dup u.               \ Yes, show microsecond value
        begin  s? until  50 ms  \ S2 released?, Yes, go on
    then
    drop ;

\ Set servoposition in steps from 0 to 1024 pulsewidth 600 us to 2700 us.
\ Show servo position in current base when S2 is pressed.
: >SERVO    ( +n -- )   2*  DM 600 +  DM 2700 umin   dup to pwm  .pulse ;
: CENTER    ( -- )      1FF >servo ; \ Servo to center position

\ This interrupt gives 0.6 to 2.7 millisec. 
\ pulses at P1.4 at about 50 Hz: 42 cells, ~27/30 cycles
routine PULSE-INT  ( -- )   \ 6 - interrupt call
    #0 adr status & cmp     \ 2 - 2 First the servo pulse?
    =? if,                  \ 2 - 1 Yes
        adr pwm & 172 & mov \ 5 - 3 TA0CCR0 Set next period
        10 # 021 & .b bis   \ 5 - 3 P1OUT  Set servo bit on (P1.4)
        #1 adr status & add \ 2 - 2 Set bit pointer on de pause position
        reti                \ 5 - 1
    then,
    dm 18000 # 172 & mov    \ 5 - 3 TA0CCR0 Set pause period
    10 # 021 & .b bic       \ 5 - 3 P1OUT  Reset servo bit (P1.4)
    #0 adr status & mov     \ 5 - 2
    reti                    \ 5 - 1
end-code

code INT-ON     ( -- )      #8 sr bis  next  end-code
code INT-OFF    ( -- )      #8 sr bic  next  end-code

\ SERVO's op Px,y etc.
: PULSE-ON  ( -- )          \ Initialise pulse hardware
    010 022 *bis            \ P1DIR    Bit P1.4 output
    0 160 !                 \ TA0CTL   Stop timer-A0
    DM 1000 172 !           \ TA0CCR0  First interrupt after 1 ms
    02D4  160 !             \ TA0CTL   Start timer
    0010 162 !              \ TA0CCTL0 Set compare 0 interrupt on
    0 to status             \ Start with a pulse
    center  int-on ;        \ Default pulse lenght is ~1,6 ms, activate

: PULSE-OFF ( -- )
    0 160 !                 \ TA0CTL   Stop timer-A0
    10 162 **bic  int-off ; \ TA0CCTL0 Interrupts off, deactivate

\ ADC on and sample time at 64 clocks
: SETUP-ADC ( -- )
    02 1B0 *bic             \ ADC10CTL0  Clear ENC
    80 04A c!               \ ADC10AE0   P1.7 = ADC in
    1810 1B0 ! ;            \ ADC10CTL0  Sampletime 64 clocks, ADC on

\ We need to clear the ENC bit before setting a new input channel
: ADC       ( +n -- u )
    02 1B0 *bic             \ ADC10CTL0  Clear ENC
    F000 and 80 or 1B2 !    \ ADC10CTL1  Select input, MCLK/5
    03 1B0 *bis             \ ADC10CTL0  Set ENC & ADC10SC
    begin 1 1B2 bit* 0= until \ ADC10CTL1  ADC10 busy?
    1B4 @ ;                 \ ADC10MEM   Read result

: POTMETER  ( -- +n )   7000 adc ;  \ Read level at P1.7

\ A servo tester using a potmeter at P1.7 and the servo at P1.4 
\ When S2 is pressed the current servo position is printed.
: TESTER    ( -- )      setup-adc  begin  potmeter >servo  key? until ;

pulse-int  FFF2 vec!        \ Install Timer-A0 vector
decimal                     \ Number base = decimal
' pulse-on to app  freeze  pulse-on  \ Activate on startup
  
                    ( End )
