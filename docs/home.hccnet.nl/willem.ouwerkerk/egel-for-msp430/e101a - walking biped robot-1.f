(* E101 - For noForth C&V 200202 or later: Load noforth-asm.f first !!
  Biped with 4 model servo's at output P1.4 to P1.7 with MSP430G2553

  P1.4 to P1.7 are wired to four servos on the launchpad experimenters kit.
  Take care that the relais does not pull to much current. An USB power supply
  usually gives up at about 300 mA.

  0020 = P1IN       - port-1 input register
  0021 = P1OUT      - port-1 input register
  0022 = P1DIR      - port-1 direction register
  0029 = P2OUT      - port-2 output with 8 leds
  002A = P2DIR      - port-2 direction register
  002E = P2SEL      - port-2 selection register 
  0160 = TA0CTL     - timer a0 output mode
  0162 = TA0CCTL0   - timer a0 period timing
  0172 = TA0CCR0    - timer a0 Duty cycle 

  Control four model servo's, This code uses R11 {xx} exclusive!!! 
  These four servo's control two legs of a biped robot, no fancy tricks
  are used in this code, it is very elementary. Improvements are left
  as a challenge to the persons who build this walking robot. 

  How the four motors must be connected:
    P1.4 - Left leg upper motor
    P1.5 - Left leg lower motor
    P1.6 - Right leg upper motor
    P1.7 - Right leg lower motor
  
  After it is powered once type BIPED-ON to activate the interrupts.
  Now any command can be given manually for example HELLO the robot
  then welcomes you, if you type 4 WALK the robot steps forward 4 times, etc.

  Divide 8.000.000/8 = 1 MHz
  So the timer-0 clock input pulse is 1 microsec.
  Take care the table #BITS must be changed too!!!
   FEDCBA9876543210 bit-nummers
   0000000011110000 CONSTANT #OUTPUT \ Choose output bit 4, 5, 6 and 7
   0000001011010100 CONSTANT #CONFIG \ TA is zero, count up, SMCLK, presc. /8
 *)

hex
04 constant #SRV  ( Four servo outputs )

\ Space for #srv servos PWM values and pause period
create SERVOS  #srv 1+ cells allot

\ I/O-bits for each output, the last cell is 0 output for pause period
\ With this version of the software the maximum is eight servo's
CREATE #BITS  10 c, 20 c, 40 c, 80 c, 0 c, align

: SET-PAUSE     ( -- )
    dm 20000  servos #srv cells bounds 
    do i @ -  cell +loop  servos #srv cells + ! ;

\ Set servoposition in staps from 0 to 200
: SERVO         ( u +n -- )
    >r  dm 5 * dm 1000 + dm 2000 umin  
    r> [ #srv 1- ] literal  umin cells servos + !  set-pause ;

\ This interrupt gives 1 to 2 millisec. pulses at 50 Hz (24 cells, 46 cycles)
\ Register R11 (xx) can not be used for something else!!!!
routine SERVO-INT ( -- )    \ 6 - interrupt call
    day push                \ 3 - Save original r8
    servos # day mov        \ 2 - Load address pointer
    xx day add              \ 1 - Calc. address of next period
    xx day add              \ 1 - One cell!
    day ) 172 & mov         \ 5 - TA0CCR0  Set next period
    #bits # day mov         \ 2 - Load bit-table pointer
    xx day add              \ 1 - Calculate next bit
    day ) 021 & .b bis      \ 5 - P1OUT  Set bit on (P1)
\ The piece that resets previous servo pulse
    #0 xx cmp               \ 1 - Is it the first bit?
    =? if,                  \ 2 - Yes
        #4 day add          \ 1 - Set bit pointer on de pause position
    then,
    #-1 day add             \ 1 - To next bit
    day ) 021 & .b bic      \ 5 - P1OUT  Reset previous bit (P1)
\ To next servo
    #1 xx add               \ 1 - To next servo
    #srv 1+ # xx cmp        \ 2 - Hold pointer in valid range
    =? if, #0 xx mov then,
    rp )+ day mov           \ 3 - Restore originele r8
    reti                    \ 5 - 
end-code

code INTERRUPT-ON      #0 xx mov  #8 sr bis  next  end-code
code INTERRUPT-OFF     #8 sr bic  next  end-code

value L/R       \ 0 = rest-position, 1 = right up, -1 = left up
value WAIT      \ Step duration ins MS

\ Activate 4 servo's at P1,4 etc.
: BIPED-ON      ( -- )
    0F0 022 *bis            \ P1DIR  Bit P1.4 to P1.7 outputs
    0 160 !                 \ TA0CTL  Stop timer-A0
    dm 1000 172 !           \ TA0CCR0  First interrupt after 1 ms
    02D4  160 !             \ TA0CTL  Start timer
    0010 162 !              \ TA0CCTL0  Set compare 0 interrupt on
    #srv 0 do 64 i servo loop \ Default pulse lenght is 1,5 ms
    150 to wait             \ Wait time 340 ms
    interrupt-on ;          \ Activate

: BIPED-OFF     ( -- )
    0 160 !                 \ TA0CTL  Stop timer-A0
    010 162 **bic           \ TA0CCTL0  Interrupts off
    interrupt-off ;

decimal  \ basic biped control routines 
: W             wait ms ;
: REST          #srv 0 do 100 i servo loop  w  0 to l/r ;
: RIGHT-UP      150 1 servo  150 3 servo  w  1 to l/r ;  
: LEFT-UP       050 3 servo  050 1 servo  w  -1 to l/r ;
: RIGHT-FORW    060 0 servo  060 2 servo  w ;
: LEFT-FORW     140 2 servo  140 0 servo  w ;
: DOWN          100 1 servo  100 3 servo  w ;
: WAVE          040 3 servo  w  150 3 servo  w ;
: TOES          160 3 servo  040 1 servo  w ;

\ Legs to rest position
: >REST         ( -- )
    l/r 0= if  exit  then
    l/r 0< if  left-up  rest exit  then
    right-up  rest ;

\ Small dance s times
: WOBBLE        ( s -- )
    0 ?do
        right-up  w  left-up  w
    loop  down ;

\ Walk s steps forward        
: WALK          ( s -- )
    0 ?do
        right-up  right-forw  down
        left-up   left-forw   down
    loop
    w  >rest ;

\ Say hello to viewers
: HELLO         ( -- )
    toes  w  rest  w  right-up  w  
    5 0 ?do  wave  loop  w  rest ;

hex
servo-int  FFF2 vec!    \ Install Timer-A0 vector
freeze
  
                    ( End )
