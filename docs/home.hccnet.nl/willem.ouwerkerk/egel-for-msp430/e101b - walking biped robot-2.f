(* E101b - noForth C&V 200202: ~2300 bytes code. 
  This example can be compiled without loading the assembler first.
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
  then welcomes you, if you type 4 WALK the robot steps forward 4 times, etc.

  Divide 8.000.000/8 = 1 MHz
  So the timer-0 clock input pulse is 1 microsec.
  Take care the table #BITS must be changed too!!!
   FEDCBA9876543210 bit-nummers
   0000000011110000 CONSTANT #OUTPUT \ Choose output bit 4, 5, 6 and 7
   0000001011010100 CONSTANT #CONFIG \ TA is zero, count up, SMCLK, presc. /8
 *)

hex
04 constant #SRV  ( Four servo outputs, low level part )

\ Space for #SeRVos PWM values and pause period
create SERVOS  #srv 1+ cells allot

\ I/O-bits for each output, the last cell is 0 output for pause period
\ With this version of the software the maximum is eight servo's
CREATE #BITS  10 c, 20 c, 40 c, 80 c, 0 c, align

: SET-PAUSE     ( -- )
    dm 20000  servos #srv cells bounds 
    do i @ -  cell +loop  servos #srv ells + ! ;

\ Set servoposition in staps from 0 to 200
: SERVO         ( u +n -- )
    >r  dm 5 * dm 1000 + dm 2000 umin  
    r> [ #srv 1- ] literal  umin cells servos + !  set-pause ;

routine SERVO-INT
  1208 ,  4038 ,  servos ,  5B08 ,  5B08 , 
  48A2 ,  172 ,  4038 ,  #bits ,  5B08 ,  D8E2 ,  21 ,  930B , 
  2001 ,  5328 ,  5338 ,  C8E2 ,  21 ,  531B ,  903B ,  #srv 1+ , 
  2001 ,  430B ,  4138 ,  1300 , 
end-code 

code INT-ON   430B ,  D232 ,  next  end-code 
code INT-OFF  C232 ,  next  end-code 


\ PiliPlop to make servos run very smooth!

: VARIABLES     create cells allot  does> @ swap cells + ;
: /MS           0 ?do  30 0 do loop  loop ;  \ Wait u times 0,1 ms

#srv variables SHERE                \ Current position
#srv variables THERE                \ Destination
#srv variables DIRECTION            \ Movement direction
#srv variables TANK
#srv variables USAGE
    variable STEPS                  \ Largest distance in steps
    value WAIT                      \ Wait time after each step
    value LWAIT                     \ Speed memory

: PREPARE       ( -- )
    0 steps !  #srv 0 do
        i there @  i shere @
        2dup u<  dup 2* 1+  i direction !
        if swap then -  dup i usage !
        steps @ umax  steps !
    loop
    #srv 0 do  steps @ 2/  i tank !  loop ;

\ : .SERVO        ( n1 n2 -- )    1 .r space  3 .r space ;

: ONE-STEP      ( -- )
    ( cr ) #srv 0 do
        i tank @  i usage @  -
        dup i tank !  0< if
            steps @  i tank +!
            i direction @  i shere +!
            i shere @  i servo
        then
    loop 
    wait /ms ;

\ Using two new words and two changes, a larger movement speed range is reached
\ Set protected movement speed now a larger range 
: SPEED         ( n -- )        140 min  -140 max  to wait ;
: .SPEED        ( -- )          wait . ;
: +SPEED        ( n -- )        wait +  speed  .speed ;
: FAST?         ( -- f )        wait 0< ;

\ Handle local speed, used for saving the robot hardware
: S{           ( n -- )        wait to lwait  speed ;  \ Set local speed 'n' save old
: }S           ( -- )          lwait speed ;           \ Restore local speed

\ Local speed is 'n' but the speed is only changed with faster speeds than 'n'
\ The speed is faster when the number 'n' is smaller!!!
\ Speed range currently from hexadecimal -140 to 140
: S?{          ( n -- )        wait over < if 1- then  wait max s{ ;

\ Movement now faster using negative numbers, no PiliPlop is
\ Used when the numbers are negative only delays after a movement is done
: (GO)          ( -- )
    fast? if  
        #srv 0 do  i there @  i servo   loop  wait abs ms exit
    then
    prepare  steps @ 0 ?do  one-step  loop ;

\ Code needed for A.N's crawl routine
: !THERE        ( +n s -- )     ( range ) 2dup shere !  there ! ;
: @THERE        ( s -- +n )     there @ ;

: B.            ( +n -- )       0 <# # # #> type space ;
: (JOINT)       ( +n s -- )     fast? if  2dup shere !  then  there ! ;
: GO            ( sn .. s0 -- ) #srv 0 do  i (joint)  loop  (go) ;
: JOINT         ( +n s -- )     (joint)  (go) ;
: WHERE         ( -- sn .. s0 ) 0 03 do  i shere @  -1 +loop ;
: SETUP-PILI    ( -- )          #srv 0 do  64 i !there  loop  40 speed ;

value L/R       \ 0 = rest-position, 1 = right up, -1 = left up

\ Activate 4 servo's at P1,4 etc.
: BIPED-ON      ( -- )
    0F0 022 *bis            \ P1DIR  Bit P1.4 to P1.7 outputs
    0 160 !                 \ TA0CTL  Stop timer-A0
    dm 1000 172 !           \ TA0CCR0  First interrupt after 1 ms
    02D4  160 !             \ TA0CTL  Start timer
    0010 162 !              \ TA0CCTL0  Set compare 0 interrupt on
    0 speed
    #srv 0 do               \ Servo's to rest position
        64 i servo  16 ms   \ at a pulse lenght of 1,5 ms 
    loop
    int-on  setup-pili ;    \ Activate


: BIPED-OFF     ( -- )
    0 160 !                 \ TA0CTL  Stop timer-A0
    010 162 **bic           \ TA0CCTL0  Interrupts off
    int-off ;


decimal  \ Basic Biped movement routines
: W             wait abs ms ;
: REST          #srv 0 do 100 i (joint) loop  (go) w  0 to l/r ;
: RIGHT-UP      150 1 (joint)  150 3 joint w  1 to l/r ; 
: LEFT-UP       050 3 (joint)  050 1 joint w  -1 to l/r ;
: RIGHT-HIGH    170 1 (joint)  170 3 joint w  1 to l/r ; 
: LEFT-HIGH     030 3 (joint)  030 1 joint w  -1 to l/r ;
: RIGHT-FORW    060 0 (joint)  060 2 joint w ;
: LEFT-FORW     140 2 (joint)  140 0 joint w ;
: RIGHT-BACKW   left-forw ;
: LEFT-BACKW    right-forw ;
: DOWN          100 1 (joint)  100 3 joint w ;
: WAVE          040 3 joint w  150 3 joint w ;
: TOES          160 3 (joint)  040 1 joint w ;
: LTOES         140 3 (joint)  060 1 joint w ;
: HTOES         180 3 (joint)  020 1 joint w ;
: WIGGLE        125 0 (joint)  075 2 joint w  075 0 (joint)  125 2 joint w ;
: (FORW         right-up  right-forw  left-up   left-forw  down ;
: (BACKW        left-up   right-forw  right-up  left-forw  down ;           

\ Legs to rest position
: >REST         ( -- )
    l/r 0= if  exit  then
    l/r 0< if  left-up  rest exit  then
    right-up  rest ;


\ Small dances and other movement each repeated s(teps) times
: WOBBLE        ( s -- )    0 ?do  right-up w  left-up w  loop  down ;
: STAMP         ( s -- )    0 ?do  right-high w  left-high w  loop down ;
: FORW          ( s -- )    0 ?do  (forw  loop  w  >rest ;
: BACKW         ( s -- )    0 ?do  (backw  loop  w  >rest ;
: DANCERIGHT    ( s -- )    0 ?do  left-up right-forw >rest  loop ;
: DANCELEFT     ( s -- )    0 ?do  right-up left-forw >rest  loop ;
: SWING         ( s -- )    0 ?do  right-forw  left-forw  loop ;
: TWIST1        ( s -- )    swing  w  rest ;
: LTWIST        ( s -- )    left-up  twist1 ;
: RTWIST        ( s -- )    right-up  twist1 ;
: WIGGLE1       ( s -- )    0 ?do  wiggle  loop  >rest ;
: LWIGGLE       ( s -- )    left-up  wiggle1 ;
: RWIGGLE       ( s -- )    right-up wiggle1 ;
: SPITZ)        ( -- )      left-up w htoes w  right-up w ltoes w ;
: SPITZ         ( s -- )    0 ?do  spitz)  loop  down ; 

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
    5 s{ 5 0 ?do  wave  loop }s  w  rest ;


\ Small remotecontrol key interpreter for use with Bluetooth
: HELP          ( -- )
    cr ." ? = Commands"
    cr ." b = walk Backward"
    cr ." f = walk Forward"
    cr ." l = turn Left"
    cr ." r = turn Right"
    cr ." h = say Hallo"
    cr ." t = dance Twist"
    cr ." 1 = dance 1"
    cr ." 2 = dance 2"
    cr ." + = increase speed"
    cr ." - = decrease speed"
    cr ." r = Rest position"
    cr ." n = to Noforth" ;

: DEMO          ( -- )
    biped-on  help
    begin
        key 
        dup ch ? = if  help     then
        dup ch b = if  (backw   then
        dup ch f = if  (forw    then
        dup ch l = if  1 (left  then
        dup ch r = if  1 (right then
        dup ch h = if  hello    then
        dup ch t = if  4 twist1 then
        dup ch 1 = if  4 rtwist then
        dup ch 2 = if  4 ltwist then
        dup ch + = if -2 +speed then
        dup ch - = if  2 +speed then
        dup ch r = if  >rest    then
            ch n = if  exit     then
    again ;
    
servo-int  FFF2 vec!    \ Install Timer-A0 vector
' demo  to app  
shield biped\  freeze
  
\ End
