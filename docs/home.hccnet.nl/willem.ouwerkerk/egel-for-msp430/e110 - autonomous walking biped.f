(* E110 - for noForth C&V 200202 or later: ~2300 bytes code
  Biped with 4 model servo's at output P1.4 to P1.7 with MSP430G2553

  P1.4 to P1.7 are wired to four servos on the launchpad experimenters kit.
  P1.3 and P2.2 are used to connect the HC-SR04 distance meter.
  P2.1 is used to make sound using a small beeper.

  To build this small robot completely, you need these components:
    - Egel kit + shield + noForth
    - LiPo save module {To protect your LiPo from damage}
    - LM2596 3 Amp. switched power supply module {Set to 5V}
    - HC-SR04 module Ultrasonic distance measurement
    - Bluetooth module like HC06 or XM06
    - Some wires & solder
    - Small piece of breadboard & other small materials
    - Two cell LiPo accu of 900mAh
    - Four standard servo's
    - Power switch
    - Triplex or some epoxy spare board
    - Double-sided tape
    - 16 cm Alu strip 10mm x 2mm
    - Some spacers, some nuts & screws 

The robot may be controlled using your cell phone!
Use BlueTerm on your phone to control to the Biped.

 020 = P1IN     - port-1 input register
 021 = P1OUT    - port-1 input register
 022 = P1DIR    - port-1 direction register
 029 = P2OUT    - port-2 output with 8 leds
 02A = P2DIR    - port-2 direction register
 02E = P2SEL    - port-2 selection register 
 160 = TA0CTL   - timer A0 control
 162 = TA0CCTL0 - timer A0 capt./comp. control {output mode}
 172 = TA0CCR0  - timer A0 capt/comp-0 {Duty cycle} 
 180 = TA1CTL   - Timer A1 control {Start/Stop}
 184 = TA1CCTL1 - Timer A1 Comp/Capt. control 0
 190 = TA1R     - Timer A1 register {Time}
 192 = TA1CCR0  - Timer A1 Comp/Capt. 0
 194 = TA1CCR2  - Timer A1 Comp/Capt. 2

  Control four model servo's, This code uses R11 {xx} exclusive!!! 
  These four servo's control two legs of a biped robot, only a few
  fancy tricks are used in this code. beyond it is very elementary. 
  More improvements are left as a challenge to the persons who build 
  this walking robot. 

  How the four motors must be connected:
    P1.4 - Left leg upper motor
    P1.5 - Left leg lower motor
    P1.6 - Right leg upper motor
    P1.7 - Right leg lower motor
  
  After it is powered once type BIPED-ON to activate the interrupts.
  Now any command can be given manually for example HELLO the robot
  then welcomes you, if you type 4 FORW the robot steps forward 4 times, etc.
 *)

\ Divide 8.000.000/8 = 1 MHz
\ So the timer-0 clock input pulse is 1 microsec.
\ Take care the table #BITS must be changed too!!!
\  FEDCBA9876543210 bit-nummers
\  0000000011110000 CONSTANT #OUTPUT \ Choose output bit 4, 5, 6 and 7
\  0000001011010100 CONSTANT #CONFIG \ TA is zero, count up, SMCLK, presc. /8

hex
04 constant #S  ( Four servo outputs )

\ Space for #sERVOS PWM values and pause period and correction (TRIM) value
create SERVOS   #s 1+ cells allot
create TRIM     #s 1+ cells allot

: CORRECT       #s umin cells trim + ! ;        ( +n s -- )
: DEFAULT       5 0 do  0 i correct  loop ;     ( -- )

\ I/O-bits for each output, the last cell is 0 output for pause period
\ With this version of the software the maximum is eight servo's
CREATE #BITS    10 c, 20 c, 40 c, 80 c, 0 c, align

: SET-PAUSE     ( -- )
    dm 40000  servos #s cells bounds do i @ -  cell +loop  servos #s cells + ! ;

\ Set servoposition in staps from 0 to 200
: SERVO         ( u +n -- )
    >r  dm 10 * dm 2000 + dm 4000 umin       \ Expand and scale u 
    r@ cells trim + @ 2* +                   \ Add correction value
    r> [ #s 1- ] literal  umin cells servos + !  set-pause ;

\ Correct servo position by n. Used to adjust the rest
\ position for each connected servomotor.
: SET           ( n s -- )      >r  r@ correct  064 r> servo ;

routine SERVO-INT
  1208 ,  4038 ,  servos ,  5B08 ,  5B08 , 
  48A2 ,  172 ,  4038 ,  #bits ,  5B08 ,  D8E2 ,  21 ,  930B , 
  2001 ,  5328 ,  5338 ,  C8E2 ,  21 ,  531B ,  903B ,  #s 1+ , 
  2001 ,  430B ,  4138 ,  1300 , 
end-code 

code INT-ON   430B ,  D232 ,  next  end-code 
code INT-OFF  C232 ,  next  end-code 


\ Pili Plop... making servo move smooth

: VARIABLES     create cells allot  does> @ swap cells + ;
: /MS           0 ?do  60 0 do loop  loop ;  \ Wait u times 0,1 ms

#s variables SHERE                  \ Current position
#s variables THERE                  \ Destination
#s variables DIRECTION              \ Movement direction
#s variables TANK
#s variables USAGE
    variable STEPS                  \ Largest distance in steps
    value WAIT                      \ Wait time after each step
    value LWAIT                     \ Speed memory

: PREPARE       ( -- )
    0 steps !  #s 0 do
        i there @  i shere @
        2dup u<  dup 2* 1+  i direction !
        if swap then -  dup i usage !
        steps @ umax  steps !
    loop
    #s 0 do  steps @ 2/  i tank !  loop ;

\ : .SERVO        ( n1 n2 -- )    1 .r space  3 .r space ;

: ONE-STEP      ( -- )
    ( cr ) #s 0 do
        i tank @  i usage @  -
        dup i tank !  0< if
            steps @  i tank +!
            i direction @  i shere +!
            i shere @  i servo
        then
    loop 
    wait /ms ;

\ Using two newords and two changes, a larger movement speed range is reached
\ Set protected movement speed now a larger range 
: SPEED         ( n -- )        140 min  -140 max  to wait ;
: .SPEED        ( -- )          wait . ;
: +SPEED        ( n -- )        wait +  speed  .speed ;
: FAST?         ( -- f )        wait 0< ;

\ Handle local speed, e.g. used for saving the robot hardware
: S{           ( n -- )        wait to lwait  speed ;  \ Set local speed 'n' save old
: }S           ( -- )          lwait speed ;           \ Restore local speed

\ Local speed is 'n' but only with faster speeds than 'n'
\ Speed is faster when the number 'n' is smaller!!!
\ Speed range currently from -140 to 140
: S?{          ( n -- )        wait over < if 1- then  wait max s{ ;

\ Movement now faster using negative numbers, no PiliPlop is
\ Used when the numbers are negative only delays after a movement is done
: (GO)          ( -- )
    fast? if  
        #s 0 do  i there @  i servo   loop  wait abs ms exit
    then
    prepare  steps @ 0 ?do  one-step  loop ;

\ Code for A.N's crawl routine
: !THERE        ( +n s -- )     ( range ) 2dup shere !  there ! ;
: @THERE        ( s -- +n )     there @ ;

: B.            ( +n -- )       0 <# # # #> type space ;
: (JOINT)       ( +n s -- )     fast? if  2dup shere !  then  there ! ;
: GO            ( sn .. s0 -- ) #s 0 do  i (joint)  loop  (go) ;
: JOINT         ( +n s -- )     (joint)  (go) ;
: WHERE         ( -- sn .. s0 ) 0 03 do  i shere @  -1 +loop ;
: SETUP-PILI    ( -- )          #s 0 do  64 i !there  loop  40 speed ;

value L/R       \ 0 = rest-position, 1 = right up, -1 = left up
value F/B       \ 0 = rest-position, 1 = forward walk, -1 = backward walk
: (F/B)         f/b 1 = if  l/r negate to l/r  then ;
: (B/F)         f/b 0< if  l/r negate to l/r  then ;


\ HC-SR04 ultrasonic distance meter

: US-ON     ( -- )
    08 022 *bic     \ P1DIR  P1.3 Input with pullup
    08 027 *bis     \ P1REN
    08 021 *bis     \ P1OUT
    04 02A *bis     \ P2DIR  P2.2 Output
    04 029 *bic ;   \ P2OUT

: TRIGGER   ( -- )      04 029 *bis  noop noop noop  04 029 *bic ; \ P2OUT
: START     ( -- )      2E4 180 !  0 190 ! ; \ TA1CTL, TA1R  Start counter
: STOP      ( -- )      030 180 *bic ; \ TA1CTL  Stop counter 

: DISTANCE  ( -- -1|cm )
    trigger                         \ Activate sensor
    begin  08 20 bit* until         \ P1IN   for start of echo pulse
    start                           \ Start counter
    begin 
        1 180 bit* if -1 exit then  \ TA1CTL  Counter overflow then ready!
    08 20 bit* 0= until             \ P1IN   Wait for echo to end
    stop  190 @  dm 05 dm 582 */ ;  \ TA1R   Stop, read counter & convert


\ Generate simple tones at P2.1

: NOTE-OFF   ( -- )     0 180 !  0 02E *bic ; 

\ Tone at P2.1, set period time for tone with 50% dutycycle
: NOTE-ON   ( period -- )
    0 180 !  02 02E *bis        \ TA1CTL, P2SEL  Stop timer, tone to P2.1
    dup 1 rshift 194 !  192 !   \ TA1CCR2, TA1CCR0  Set period time
    E0 184 !  254 180 ! ;       \ TA1CCTL1, TA1CTL  Start timer

decimal
\ : R         100 ms ; 
: PLAY      note-on  ms  note-off ;
: HI        300 8636 play  300 4318 play ;
: HEY       200 4318 play  200 2159 play  200 1080 play ;
: GOOD      75 39088 play  75 34544 play  75 17272 play ;

hex
\ Biped elementary instructions

\ Activate 4 servo's at P1,4 etc.
: BIPED-ON      ( -- )
    0F0 022 *bis            \ P1DIR   Bit P1.4 to P1.7 outputs
    02 02A *bis             \ P2DIR   P2.1 beeper output      
    0 160 !                 \ TA0CTL  Stop timer-A0
    dm 1000 172 !           \ TA0CCR0  First interrupt after 1 ms
    02D4  160 !             \ TA0CTL  Start timer
    0010 162 !              \ TA0CCTL0  Set compare 0 interrupt on
    0 speed  default        \ Max. speed and no pulse correction
    #s 0 do                 \ Servo's to rest position
        64 i servo  16 ms   \ at a pulse lenght of 1,5 ms 
    loop
( ) dm 20 1 set dm 30 2 set \ Adjust servo positions
    0 to l/r  0 to f/b
    int-on   us-on          \ Activate!
    setup-pili   note-off ;

: BIPED-OFF     ( -- )
    0 160 !                 \ TA0CTL  Stop timer-A0
    010 162 **bic           \ TA0CCTL0  Interrupts off
    int-off ;

decimal  \ basic biped control routines
: W             wait abs ms ;
: REST          #s 0 do 100 i (joint) loop  (go) w  0 to l/r  0 to f/b ;
: RIGHT-UP      140 1 (joint)  180 3 joint w  5 s{ 140 3 joint }s  1 to l/r ;
: LEFT-UP       060 3 (joint)  020 1 joint w  5 s{ 60 1 joint }s  -1 to l/r ;
: RIGHT-HIGH    150 1 (joint)  180 3 joint w  5 s{ 150 3 joint }s  1 to l/r ;
: LEFT-HIGH     050 3 (joint)  020 1 joint w  5 s{ 50 1 joint }s  -1 to l/r ;
: RIGHT-FORW    060 0 (joint)  060 2 joint w ;
: LEFT-FORW     140 2 (joint)  140 0 joint w ;

: RIGHT-BACKW   left-forw ;
: LEFT-BACKW    right-forw ;
: DOWN          60 s?{ 100 1 (joint)  100 3 joint w }s ;
: WAVE          040 3 joint w  150 3 joint w ;
: TOES          160 3 (joint)  040 1 joint w ;
: LTOES         140 3 (joint)  060 1 joint w ;
: HTOES         180 3 (joint)  020 1 joint w ;
: WIGGLE        125 0 (joint)  075 2 joint w  075 0 (joint)  125 2 joint w ;

: RFORW         right-up  right-forw down ;
: LFORW         left-up   left-forw  down ;
: RBACKW        right-up  left-forw  down ;
: LBACKW        left-up   right-forw down ;

: (FORW         ( s -- )
    (b/f)    1 to f/b   0 ?do
        l/r 0< if  rforw   else  lforw   then 
    loop ;

: (BACKW        ( s -- )
    (f/b)   -1 to f/b   0 ?do 
        l/r 0< if  rbackw  else  lbackw  then 
    loop ;

\ Legs to rest position
: >REST         ( -- )
    l/r 0= if  exit  then
    l/r 0< if  left-up  rest exit  then
    right-up  rest ;


\ Small dance or other movement s times

: WOBBLE        ( s -- )    0 ?do  right-up w  left-up w  loop  down ;
: STAMP         0 ?do right-high 200 ms  left-high 200 ms loop  down ;
: FORW          ( s -- )    (forw  w  >rest ;
: BACKW         ( s -- )    (backw  w  >rest ;
: DANCERIGHT    ( s -- )    0 ?do  left-up right-forw >rest  loop ;
: DANCELEFT     ( s -- )    0 ?do  right-up left-forw >rest  loop ;
: SWING         ( s -- )    0 ?do  right-forw  left-forw  loop ;
: TWIST1        ( s -- )    swing  w  rest ;
: LTWIST        ( s -- )    left-up  twist1 ;
: RTWIST        ( s -- )    right-up  twist1 ;
: WIGGLE1       ( s -- )    0 ?do  wiggle  loop  >rest ;
: LWIGGLE       ( s -- )    left-up  wiggle1 ;
: RWIGGLE       ( s -- )    right-up wiggle1 ;
: (SPITZ        ( -- )      left-up w htoes w  right-up w ltoes w ;
: SPITZ         ( s -- )    0 ?do  (spitz loop  down ;
: WAG1          ( s -- )    0 ?do  toes rest  loop ;
: WAG2          ( s -- )    0 ?do  htoes rest  loop ;

hex
: (RIGHT        ( s -- )
    0 ?do
        right-up  50 2 joint w  down
        left-up  left-forw  70 0 joint w  down
    loop ;

: (LEFT          ( s -- )
    0 ?do
        left-up  80 0 joint w  down
        right-up  right-forw  60 2 joint w  down
    loop ;

: RIGHT         ( s -- )    (right >rest ;
: LEFT          ( s -- )    (left >rest ;

\ Say hello to viewers
: HELLO         ( -- )
    toes  w  rest  w  right-up  w  
    hi  5 s{ 5 0 ?do  wave  loop }s  w  rest ;


\ Autonomous mode

decimal
value END?
: (ADJUST       ( ch -- )
    dup ch + = if  drop  -2 +speed exit  then  \ Faster
    dup ch - = if  drop   2 +speed exit  then  \ Slower
          bl = if  ch ? emit  key drop   then  \ Wait for any key
    true to end? ;

: ADJUST        ( -- )      key? if  key (adjust  then ;

: NEAR          ( -- )          
    hey  4 (backw                 \ Step back and search for open space
    10 0 do
        2 (right  distance 50 u> if  
            good  8 s{ 4 wag2 }s  leave
        then
    loop ;

: (WALK         ( cm -- )
    dup 50 u> if                  \ Large free room?         
        good  adjust  1 (forw     \ Do two and a half steps 
        adjust  2 (forw  drop exit
    then
    30 u< if                      \ Something in front? 
        2 (left  hi               \ Yes, turn left
    else
        adjust  1 (forw           \ No, half step forward
    then ;
 
: WALK          ( -- )            \ Autonomous mode
    biped-on  40 speed  us-on  hi
    false to end?   5 s{  16 wag1  }s
    begin
        distance dup 13 u< if     \ Something to close
            drop  near            \ Yes, step back & turn right
        else
            (walk                 \ No, just wander
        then
        adjust                    \ Change speed
    end? until  >rest ;


\ Key interpreter for remote control
hex
: HELP          ( -- )
    cr ." ? = Commands"
    cr ." b = walk Backward"
    cr ." f = walk Forward"
    cr ." l = turn Left"
    cr ." r = turn Right"
    cr ." h = say Hallo"
    cr ." s = Stamp"
    cr ." t = dance Twist"
    cr ." 1 = dance 1"
    cr ." 2 = dance 2"
    cr ." + = increase speed"
    cr ." - = decrease speed"
    cr ." p = rest Position"
    cr ." w = Walk autonomous"
    cr ." n = to Noforth" ;

: DEMO          ( -- )
    biped-on  hi  help
    begin
        key 
        dup ch ? = if  help         then
        dup ch b = if  1 (backw       then
        dup ch f = if  1 (forw        then
        dup ch l = if  1 (left      then
        dup ch r = if  1 (right     then
        dup ch h = if  hello        then
        dup ch s = if  4 stamp      then
        dup ch t = if  4 twist1     then
        dup ch 1 = if  4 rtwist     then
        dup ch 2 = if  4 lwiggle    then
        dup ch p = if  >rest        then
        dup ch w = if  walk         then
        dup ch + = if -2 +speed     then    \ Faster
        dup ch - = if  2 +speed     then    \ Slower
            ch n = if  exit         then    \ Ready to noForth
    again ;
    
servo-int   FFF2 vec!        \ Install timer-A0 vector
' demo  to app  shield biped\  freeze
  
\ End
