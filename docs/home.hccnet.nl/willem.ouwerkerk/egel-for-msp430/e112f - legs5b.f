(* E112F - For noForth C&V 200202 or later: Leg control for hexapod beatle
  The (GO) command puts the legs in motion
  So 10 20 15 leg1 (go) moves all joints of leg1
  h = horizontal,  s = shoulder,  e = elbow 
  The h(orizontal) range from 70 degrees backward to 110 degrees forward
  So the most forward legs can maybe be used to drag something away
  and using touch to explore the world??
  The s(houlder) moves from 90 degrees upward to 90 degrees downward
  The e(lbow) moves 90 degrees square to both sides of the s(houlder)
 
    p6 ------- p1    The legs are attached to the beatle this way!
       |     |
       |     |
    p5 |     | p2
       |     |
       |     |
    p4 ------- p3

  Next steps:
  Big and small steps
  Running, etc.
*)

forth
: (HEAD)    ( n1 n2 -- )    00 (JOINT)  01 (JOINT) ;
: HEAD      ( n1 n2 -- )    (head) (go) ;

\ Invert servo movement for the other side so both sides
\ can use the same numbers to move joints.
code INV    ( b1 -- b2 )    #-1 tos .b xor>  next  end-code
\ Extend byte sign to word
code >N     ( signed-byte -- n )   tos sxt  next  end-code

\ Leg horizontal default positions
\ 0 = LEG1 and LEG6
\ 1 = LEG2 and LEG5
\ 2 = LEG3 and LEG4
ecreate (HOR    60 ec, 80 ec, A0 ec,

value FORW?     \ True = forward, false = turn
value TURN?     \ True = left, false = right
: LEFT      false to forw?  true to turn? ;
: RIGHT     false to forw? false to turn? ;
: EVEN      true to forw? ;

: LHOR   ( off n -- p )
    (hor + ec@  swap >n     \ Convert 8-bit offset to 16-bit
    forw? 0=  turn? and if  4 /  then  + ;   \ Forward or turn left

: RHOR   ( off n -- p )
    (hor + ec@  swap >n     \ Convert 8-bit offset to 16-bit
    forw? 0=  turn? 0= and if  4 /  then  + ; \ Forward or turn right

: LEG1      02 (JOINT)  03 (JOINT)  0 rhor 04 (JOINT) ;  ( h s e -- )
: LEG2      05 (JOINT)  06 (JOINT)  1 rhor 07 (JOINT) ;
: LEG3      08 (JOINT)  09 (JOINT)  2 rhor 0A (JOINT) ;
: LEG4      inv 0B (JOINT)  inv 0C (JOINT)  2 lhor inv 0D (JOINT) ;
: LEG5      inv 0E (JOINT)  inv 0F (JOINT)  1 lhor inv 10 (JOINT) ;
: LEG6      inv 11 (JOINT)  inv 12 (JOINT)  0 lhor inv 13 (JOINT) ;

: >LEG1     leg1 (go) ;     : >LEG2     leg2 (go) ;
: >LEG3     leg3 (go) ;     : >LEG4     leg4 (go) ;
: >LEG5     leg5 (go) ;     : >LEG6     leg6 (go) ;

: @LEG      ec@  nec@  nec@ ;  ( ee-addr -- h-o s e )

: LLEGS     dup @leg leg1  dup @leg leg3  @leg leg5 ;  ( ee -- )
: RLEGS     dup @leg leg6  dup @leg leg4  @leg leg2 ;  ( ee -- )
: >LLEGS    llegs  (go) ;       ( ee -- )
: >RLEGS    rlegs  (go) ;       ( ee -- )
: >ALL      dup llegs >rlegs ;  ( ee -- )

\ Data structures for leg movement in EEPROM
\ Fetch data for one leg from EEPROM
\ First byte contains a signed offset to the default position of a leg!!
\ This value can be from -7F to 00 to 7F 
ecreate NORM      00 ec, 60 ec, D0 ec,
ecreate UP        00 ec, A8 ec, FF ec,
ecreate UPb       20 ec, A8 EC, FF EC,
ecreate UPF      -20 ec, A8 EC, FF EC,
ecreate BACK      20 ec, 60 ec, D0 ec,
ecreate FORW     -20 ec, 60 ec, D0 ec,

ecreate DOWN      00 ec, 00 ec, D0 ec,
ecreate REST      00 ec, 00 ec, FF ec,
ecreate PUSH      00 ec, 40 ec, FF ec,
ecreate HELP      00 ec, 80 ec, FF ec,

ecreate RESTa     00 ec, 80 ec, 80 ec,
ecreate RESTb     00 ec, FF ec, FF ec,
ecreate RESTc     00 ec, FF ec, 10 ec,
ecreate RESTd     00 ec, FF ec, 80 ec,
ecreate UPa       00 ec, B0 ec, FF ec,

value POS
: LEFT-NORM   ( -- )  norm >llegs ;
: RIGHT-NORM  ( -- )  norm >rlegs ;
: LEFT-UP     ( -- )  up >llegs ;
: RIGHT-UP    ( -- )  up >rlegs ;
: START       ( -- )  0 to pos  norm  >all ; \ norm position

: NORMAL      ( -- )            \ Normalise all legs
    up @leg >leg1  norm @leg >leg1
    up @leg >leg6  norm @leg >leg6
    up @leg >leg2  norm @leg >leg2
    up @leg >leg5  norm @leg >leg5
    up @leg >leg3  norm @leg >leg3
    up @leg >leg4  norm @leg >leg4
    ;

: SHAKE       ( -- )            \ Rattle legs in place
    -60 s{  upa @leg >leg1  norm @leg >leg1 
            upa @leg >leg6  norm @leg >leg6 
            upa @leg >leg2  norm @leg >leg2 
            upa @leg >leg5  norm @leg >leg5 
            upa @leg >leg3  norm @leg >leg3 
            upa @leg >leg4  norm @leg >leg4  }s ;

\ Other experimental movements...
\ Fold your legs under your body (like a cat)
: SLEEP       ( -- )
    left-up  down >llegs
    right-up  down >rlegs 
    rest >all ;

\ Stand up carefully from sleep position
: WAKEUP      ( -- )
    down >all                   \ First push
\   push >all                   \ Second push
    rest >llegs   help >llegs   \ Free legs
    norm >llegs                 \ Left normal and
    rest >rlegs   help >rlegs   \ Free legs
    start ;                     \ right normal


\ Turn on your place to the left & right
: LSTEP       ( -- )
    right-up   left-norm
    upb rlegs upf @leg >leg2
    back rlegs forw @leg >leg2
    left-up   right-norm 
    upf llegs upb @leg >leg5  
    forw llegs  back @leg >leg5
    ;

: RSTEP       ( -- )
    right-up   left-norm
    upf rlegs upb @leg >leg2
    forw rlegs back @leg >leg2
    left-up   right-norm  
    upb llegs upf @leg >leg5  
    back llegs  forw @leg >leg5
    ;

: LTURN       ( u -- )  0 ?do  lstep  loop  shake ;
: RTURN       ( u -- )  0 ?do  rstep  loop  shake ;


\ Crab like walk... to the right
ecreate CRAB1     00 ec, 60 ec, B0 ec,  ( A )
ecreate CRAB2     00 ec, 60 ec, F0 ec,  ( B )
ecreate UPCRAB    00 ec, A0 ec, F0 ec,  ( C )

: CRAB-REST   ( -- )    
    upcrab >rlegs  crab2 >rlegs 
    upcrab >llegs  crab2 >llegs ;

: CRABL       ( -- )
    upcrab >llegs
    crab2 @leg leg1  crab2 @leg leg3  crab1 @leg >leg5
    upcrab >rlegs
    crab1 @leg leg1  crab1 @leg leg3  crab2 @leg >leg5
    crab2 @leg leg2  crab1 @leg leg4  crab1 @leg >leg6
    upcrab >llegs
    crab1 @leg leg2  crab2 @leg leg4  crab2 @leg >leg6 ;

: CRABR      ( -- )
    upcrab >llegs
    crab1 @leg leg1  crab1 @leg leg3  crab2 @leg >leg5
    upcrab >rlegs
    crab2 @leg leg1  crab2 @leg leg3  crab1 @leg >leg5
    crab1 @leg leg2  crab2 @leg leg4  crab2 @leg >leg6
    upcrab >llegs
    crab2 @leg leg2  crab1 @leg leg4  crab1 @leg >leg6 ;

: CRAB-END    ( -- )    crab2 >llegs  upcrab >rlegs  crab2 >rlegs ;      
: RCRAB       ( u -- )  crab-rest  0 ?do  crabr  loop  crab-end ;
: LCRAB       ( u -- )  crab-rest  0 ?do  crabl  loop  crab-end ;

\ Rest positions
: REST1 ( -- )  20 s?{  resta >all  }s ;
: REST2 ( -- )  20 s?{  upa >all  }s ;
: REST3 ( -- )  rest2 rest1 ;
: REST4 ( -- )  20 s?{  restb >all  }s ;
: REST5 (  )    20 s?{  restc >all  }s ;
: REST6 ( -- )  20 s?{  restd >all  }s ;
: UP1   ( -- )  norm >all  shake ;
: UP2   ( -- )  rest2 up1 ;

inside
: READY ( -- )
    servo-on  ta-on FF ms  tb-on FF ms  
    setup-pili  even  up2 ;
forth

: (WALK         ( -- )
    up @leg >leg4  upf @leg >leg4  forw @leg >leg4
    up @leg >leg3  upf @leg >leg3  forw @leg >leg3
    upf @leg leg2  upf @leg >leg5  forw @leg leg2 forw @leg >leg5
    up @leg >leg1  upf @leg >leg1  forw @leg >leg1
    up @leg >leg6  upf @leg >leg6  forw @leg >leg6
    6 s?{  norm >all  }s ;

: (BACK         ( -- )
    up @leg >leg4  upb @leg >leg4  back @leg >leg4
    up @leg >leg3  upb @leg >leg3  back @leg >leg3
    up @leg >leg1  upb @leg >leg1  back @leg >leg1
    up @leg >leg6  upb @leg >leg6  back @leg >leg6
    upb @leg leg2  upb @leg >leg5  back @leg leg2 back @leg >leg5
    6 s?{  norm >all  }s ;

: FORW          ( u -- )    0 ?do  (walk  loop ;
: BACKW         ( u -- )    0 ?do  (back  loop ;

shield legs\  freeze

\ Demo: up2  5 forw  5 backw  rest2  5 rcrab  5 lcrab  sleep
\ End
