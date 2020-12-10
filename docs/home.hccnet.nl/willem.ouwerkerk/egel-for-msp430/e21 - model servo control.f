(* E21 - For noForth C&V 200202: Load noforth-asm.f first !
  Model servo pulse outputs at P1.4 and P1.5 with MSP430G2553 

  P1.4 & P1.5 are wired to two servos on the launchpad experimenters kit.
  Take care that the relais does not pull to much current. An USB power supply
  usually gives up at about 300 mA.

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
\ Space for two PWM values and pause period
create SERVOS  3 cells allot

\ I/O-bits for each output, the last cell is 0 uoutput for pause period
CREATE #BITS  10 c, 20 c, 0 c, align

: SET-PAUSE  ( -- )
    DM 20000  servos 2 cells bounds do i @ -  cell +loop  servos 2 cells + ! ;

\ Set servoposition in staps from 0 to 200
: SERVO     ( u +n -- )
    >r  DM 5 * DM 1000 + DM 2000 umin  
    r> 1 umin cells servos + !  set-pause ;

\ This interrupt gives 1 to 2 millisec. pulses at 50 Hz (24 cells, 46 cycles)
\ Register R11 (xx) can not be used for something else!!!!
code SERVO-INT  ( -- )      \ 6 - interrupt call
    day push                \ 3 - 1 Save original r8
    servos # day mov        \ 2 - 2 Load address pointer
    xx day add              \ 1 - 1 Calc. address of next period
    xx day add              \ 1 - 1 One cell!
    day ) 172 & mov         \ 5 - 2 TA0CCR0 Set next period
    #bits # day mov         \ 2 - 2 Load bit-table pointer
    xx day add              \ 1 - 1 Calculate next bit
    day ) 21 & .b bis       \ 5 - 2 P1OUT  Set bit on (P1)
\ Now the piece that resets previous servo pulse
    #0 xx cmp               \ 1 - 1 Is it the first bit?
    =? if,                  \ 2 - 1 Yes
        #2 day add          \ 1 - 1 Set bit pointer on de pause position
    then,
    #-1 day add             \ 1 - 1 To next bit
    day ) 21 & .b bic       \ 5 - 2 P1OUT  Reset previous bit (P1)
\ To next servo
    #1 xx add               \ 1 - 1 To next servo
    3 # xx cmp              \ 2 - 2 Hold pointer in valid range
    =? if, #0 xx mov then,
    rp )+ day mov           \ 3 - 1 Restore originele r8
    reti                    \ 5 - 1
end-code

code INTERRUPT-ON      #0 xx mov  #8 sr bis  next  end-code
code INTERRUPT-OFF     #8 sr bic  next  end-code

\ SERVO's op Px,y etc.
: SERVO-ON  ( -- )          \ Initialise servo hardware
    30 22 *bis              \ P1DIR    Bit P1.4 and P1.5 outputs
    0 160 !                 \ TA0CTL   Stop timer-A0
    DM 1000 172 !           \ TA0CCR0  First interrupt after 1 ms
    2D4  160 !              \ TA0CTL   Start timer
    10 162 !                \ TA0CCTL0 Set compare 0 interrupt on
    2 0 do  64 i servo loop \ Default pulse lenght is 1,5 ms
    interrupt-on ;          \ Activate

: SERVO-OFF ( -- )
    0 160 !                 \ TA0CTL   Stop timer-A0
    10 162 **bic            \ TA0CCTL0 Interrupts off
    interrupt-off ;

: BACK      ( -- )  
    dm 200 0 do
        key? if  leave  then        \ Stop at any keystrobe
        i 0 servo                   \ Set servo 0, than
        dm 200 i -  1 servo  150 ms \ servo 1 and wait a while
    0A +loop ;

: FORTH     ( -- )
    dm 200 0 do
        key? if  leave  then        \ Stop at any keystrobe
        i 1 servo                   \ Set servo 0, than
        dm 200 i -  0 servo  150 ms \ servo 1 and wait a while
    0A +loop ;
    
: MOVE-SERVOS ( -- )
    servo-on  begin  back ( and ) forth  key? until ;

' servo-int >body  FFF2 vec!        \ Install Timer-A0 vector
freeze
  
                    ( End )
