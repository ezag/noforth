(* E112D - For noForth C2553 lp.0, C&V version: Pseudo random number generator
   CHOOSE - Make pseudo random number u2 the range of u2 is 0 to u1-1 
*)

: /MS           0 ?do  30 0 do loop  loop ;  \ Wait u times 0,1 ms

extra definitions
value RND   ( Work location for pseudo random numbers )

decimal     ( Make pseudo random number ud )
: RANDOM        ( -- ud )       rnd 31421 *  6927 +  dup to rnd ;
: CHOOSE        ( u1 -- u2 )    random  um* nip ;
: POSITION      ( -- +n )       256 choose ;
: SERVO-NR      ( -- +n )       020 choose ;
: SETUP-RANDOM  ( -- )          31414 to rnd ;
hex

forth definitions
shield random\
freeze
    
( Einde )
