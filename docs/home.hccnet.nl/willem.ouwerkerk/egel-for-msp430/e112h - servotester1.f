(* E112H - For noForth C2553 lp.0, C&V version: Load noforth-asm.f first !
  Model servo pulse outputs at P1.4 and P1.5 with MSP430G2553 

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
   
  Control two model servo's, This code uses R11 {xx} exclusive!!!

  Divide 8.000.000/8 = 1 MHz
  So the timer-0 clock input pulse is 1 microsec.
  Take care the table #BITS must be changed too!!
   FEDCBA9876543210 bit-nummers
   0000000000110000 CONSTANT #OUTPUT \ Choose output bit4 and bit5
   0000001011010100 CONSTANT #CONFIG \ TA is zero, count up, SMCLK, presc. /8
 *)

hex
\ Space for a PWM value and pause period
create SERVOS  2 cells allot

: SET-PAUSE  ( -- )
    DM 20000  servos @ -  servos cell+ ! ;

\ Set servoposition in steps from 0 to 255 pulsewidth 500 us to 2500 us
: SERVO     ( u -- )
    DM 8 * DM 500 + DM 2500 umin   dup servos !  set-pause 
    s? 0= if  cr dup u.  begin s? until  50 ms  then  drop ;

\ This interrupt gives 0.5 to 2.5 millisec. pulses at 50 Hz (yy cells, xx cycles)
\ Register R11 (xx) can not be used for something else!!!!
routine SERVO-INT  ( -- a ) \ 6 - interrupt call
    day push                \ 3 - 1 Save original r8
    servos # day mov        \ 2 - 2 Load address pointer
    xx day add              \ 1 - 1 Calc. address of next period
    day ) 172 & mov         \ 5 - 2 TA0CCR0 Set next period
\ Now the piece that sets servo pulse
    #0 xx cmp               \ 1 - 1 First entry?
    =? if,                  \ 2 - 1 Yes
        10 # 021 & .b bis   \ 5 - 2 P1OUT  Set bit on (P1.4)
        #2 xx add           \ 1 - 1 Increase pointer
        rp )+ day mov       \ 3 - 1 Restore originele r8
        reti                \ 5 - 1
    then,
\ Second entry = pause period?
    10 # 021 & .b bic       \ 5 - 2 P1OUT  Reset bit on (P1.4)
    #0 xx mov
    rp )+ day mov           \ 3 - 1 Restore originele r8
    reti                    \ 5 - 1
end-code

code INTERRUPT-ON      #0 xx mov  #8 sr bis  next  end-code
code INTERRUPT-OFF     #8 sr bic  next  end-code

\ SERVO's op Px,y etc.
: SERVO-ON  ( -- )          \ Initialise servo hardware
    010 022 *bis            \ P1DIR    Bit P1.4 output
    0 160 !                 \ TA0CTL   Stop timer-A0
    DM 1000 172 !           \ TA0CCR0  First interrupt after 1 ms
    02D4  160 !             \ TA0CTL   Start timer
    0010 162 !              \ TA0CCTL0 Set compare 0 interrupt on
    7D servo                \ Default pulse lenght is 1,5 ms
    interrupt-on ;          \ Activate

: SERVO-OFF ( -- )
    0 160 !                 \ TA0CTL   Stop timer-A0
    010 162 **bic           \ TA0CCTL0 Interrupts off
    interrupt-off ;

\ ADC on and sample time at 64 clocks
: SETUP-ADC ( -- )
    02 1B0 *bic               ( ADC10CTL0  Clear ENC )
    80 04A c!                 ( ADC10AE0   P1.7 = ADC in )
    1810 1B0 ! ;              ( ADC10CTL0  Sampletime 64 clocks, ADC on )

\ We need to clear the ENC bit before setting a new input channel
: ADC       ( +n -- u )
    02 1B0 *bic               ( ADC10CTL0  Clear ENC )
    F000 and 80 or 1B2 !      ( ADC10CTL1  Select input, MCLK/5 )
    03 1B0 *bis               ( ADC10CTL0  Set ENC & ADC10SC )
    begin 1 1B2 bit* 0= until ( ADC10CTL1  ADC10 busy? )
    1B4 @ ;                   ( ADC10MEM   Read result )

: POTMETER  ( -- +n )   7000 adc ;  \ Read level at P1.7
: CENTER    ( -- )      07D servo ; \ Servo to center position
\ A servo tester using a potmeter at P1.7
: TESTER    ( -- )      setup-adc  begin  potmeter 2/ 2/ servo  key? until ;

servo-int  FFF2 vec!        \ Install Timer-A0 vector
' servo-on to app  freeze  servo-on
  
                    ( End )
