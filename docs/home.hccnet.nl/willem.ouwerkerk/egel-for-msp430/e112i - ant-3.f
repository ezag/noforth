(* E112I - For noForth C2553 lp.0, C&V version:  
   ANT simulation routine, translated to hexapod.
*)

value CHANCE    \ Random range
value ANGLE     \ Maximum angle
value STEPS     \ For ard steps

\ De scratch variant has a range from: chance - angle to chance + angle
\ That is in the case of chance = 15 and angle = 1 frpm -14 to 16
\ A greater bias to right the to left
\ The variant below is completely balanced: 
\ -chance - angle to chance + angle is -16 to 16
: GET-ANGLE     ( -- n )
\   chance 2* choose  chance angle -  - 2/ ;  \ Choose angle, scratch variant
    chance angle + 2* 1+ choose \ Choose angle
    chance angle +  -           \ Determine direction
    2/ 2/ ;                     \ A quarter of the angle is enough for Hexapod

: SENS?         ( -- )      10 ms  01 01C bit* 0= ; \ Antennas?
: AVOID         ( -- )      sens? if  even  2 backw  3 rturn  then ;

: FORW          ( s -- )         \ Do S steps
    0 ?do
        avoid  1 walk  ch . emit \ Step with escape
    loop ;

: TURN          ( -- )
    get-angle  dup .  ?dup 0=   \ New corner, corner = 0 ?
    if  even 1 forw  exit  then \ Yes, just straight out & ready!
    dup 0 >                     \ Corner positive?
    if  right else left  then   \ Yes: go right, No: go left 
    abs 0 ?do                   \ Take 1 or more steps left or right
        avoid  1 walk           \ Step with escape
    loop ;

\ ANT simulation variant  Example:  1 8 15 ant
: ANT           ( step angle chance -- )
    FE 01E c!  0 01D c!         \ Initialise input
    setup-random  even  up1     \ Hexapod gets up
    to chance to angle to steps \ Set help variables
    begin
        turn  even steps forw   \ Simulate an Ant walking
    key? until  rest2 ;         \ Ready, go rest

shield ANT\  freeze

\ End
