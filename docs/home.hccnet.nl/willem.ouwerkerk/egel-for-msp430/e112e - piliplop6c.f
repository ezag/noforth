(* E112E - For noForth C2553 lp.0, C&V version: 20 servo PiliPlop mechanism
   Version for testing movements on a Hexapod, a 6 leg beatle.
   This version does direct servo control too at zero and negative numbers
*)

hex
inside also definitions
014 variables SHERE                 \ Current position
014 variables THERE                 \ Destination
014 variables DIRECTION             \ Movement direction
014 variables TANK
014 variables USAGE
    variable STEPS                  \ Largest distance in steps
    value WAIT                      \ Wait time after each step
    value LWAIT                     \ Speed memory

: PREPARE       ( -- )
    0 steps !  014 0 do
        i there @  i shere @
        2dup u<  dup 2* 1+  i direction !
        if swap then -  dup i usage !
        steps @ umax  steps !
    loop
    014 0 do  steps @ 2/  i tank !  loop ;

: ONE-STEP      ( -- )
    014 0 do
        i tank @  i usage @  -
        dup i tank !  0< if
            steps @  i tank +!
            i direction @  i shere +!
            i shere @  i servo 
        then
    loop 
    wait /ms ;

\ Using two new words and two changes, a larger movement speed range is reached
extra definitions ( Set protected movement speed now a larger range )
: SPEED         ( n -- )        140 min  -140 max  to wait ;
: .SPEED        ( -- )          wait . ;
: FAST?         ( -- f )        wait 0< ;

\ Handle local speed, used for saving the robot hardware
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
        014 0 do  i there @  i servo  loop  wait abs ms exit
    then
    prepare  steps @ 0 ?do  one-step  loop ;

\ Code for A.N's crawler routine
: !THERE        ( +n s -- )     2dup shere !  there ! ;
: @THERE        ( s -- +n )     there @ ;

: B.            ( +n -- )       0 <# # # #> type space ;
: (JOINT)       ( +n s -- )     fast? if  2dup shere !  then  there ! ;
: GO            ( sn .. s0 -- ) 014 0 do  i (joint)  loop  (go) ;
: JOINT         ( +n s -- )     (joint)  (go) ;
: WHERE         ( -- sn .. s0 ) 0 013 do  i shere @  -1 +loop ;
inside definitions

: SETUP-PILI    ( -- )
    -10 speed  zero-servos  14 0 do  80 i (joint)  loop  40 speed ;

previous  forth definitions
shield piliplop\
freeze
    
( Einde )
