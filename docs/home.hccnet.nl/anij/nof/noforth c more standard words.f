\ Extra standard words for noForth C
\ (C) 2015, Albert Nijhof & Willem Ouwerkerk
\ updated april 2015
\ 30dec17 -- ABORT" 2@ 2! adapted for noForth november 2017

\ trivia
: 0>    ( n -- flag )   0 > ;
: D-    ( dn1 dn2 -- dn3 )      dnegate d+ ;
: M+    ( d n -- d )    s>d d+ ;
: CHAR+ ( n1 -- n2 )    1+ ;
: CHAR- ( n1 -- n2 )    1- ;
: CHARS ( n -- n )  ; IMMEDIATE
: ERASE     ( a n -- )  0 fill ;
: COMPILE,  ( xt -- )   , ;
: UNUSED    ( -- n )    ivecs chere - ;

create PAD  ( -- a )    20 allot        \ example

: SOURCE    ib #ib ;
: SAVE-INPUT    ( -- ib #ib >in@ )  @input 3 ;
: RESTORE-INPUT ( ib #ib >in@ 3 -- )    3 ?pair !input ;

: [ELSE] 1
  begin begin begin ?dup 0= ?exit
    ch [ beyond true >in +!
    bl-word count 2dup upper
    s" [THEN]" 2over s<> 0= while 2drop 1- repeat
    s" [ELSE]" 2over s<> 0= while 2drop dup 1 = + repeat
    s" [IF]" s<> 0= -
  again ; immediate
: [IF] ?exit postpone [else] ; immediate
: [THEN] ; immediate

\ colon definitions
\ : 2!    ( lo hi a -- )  tuck ! cell+ ! ;
\ : 2@    ( a -- lo hi )  dup cell+ @ swap @ ;

\ code definitions
\ code 2! ( lo hi a -- )  sp )+ tos ) mov
\    sp )+ 2 tos x) mov   sp )+ tos mov   next end-code
\ code 2@ ( a -- lo hi )  tos w mov
\    w )+ tos mov   w ) sp -) mov   next end-code

hex \ comma code
code 2! ( lo hi a -- )  44B7 ,  0 ,
    44B7 ,  2 ,  4437 ,  next  end-code
code 2@ ( a -- lo hi )  4706 ,  4637 ,
    8324 ,  46A4 ,  0 ,  next  end-code

: [COMPILE]     ' ?comp , ; immediate

header ABORT"   ' S" @ ,   reveal immediate
:noname if  inls count cr type -2 throw
        then inls drop ; drop

: RECURSE       ( -- )
    ?comp s0 @ dup if , exit then
    1- ?abort ; immediate

: ROLL  ( i*x u -- j*x )
    dup 1 <
    if drop
    else  swap >r 1- RECURSE r> swap
    then ;

\ symmetric signed division
: SM/REM    ( dn n -- rest quot )
    over >r >r   dabs r@ abs um/mod
    r> r@ xor ?negate swap   r> ?negate swap ;
: /REM  ( x1 x2 -- r q )    >r s>d r> sm/rem ;

\ the never dying CASE
: OF?   over = ;
: CASE  hx 88 ; immediate
: OF    postpone of? postpone if postpone drop ; immediate
: ENDOF     postpone else ; immediate
: ENDCASE   ( x -- )
    postpone drop
    begin postpone then hx 88 of?
    until drop ; immediate
\ <><>
