\ 28jul20
\ noForth r(cv) tools -- 1nov2020
hex \ until the end
\ 32aligned 32wide doers
v: fresh

: [ELSE] true
  begin begin begin ?dup 0= ?exit
    ch [ beyond true +to >in?
    bl-word count 2dup upper
    s" [THEN]" 2over s<> 0= while 2drop 1+ repeat
    s" [ELSE]" 2over s<> 0= while 2drop dup -1 = - repeat
    s" [IF]" s<> 0= if 1- then
  again ; immediate
: [IF] ?exit postpone [else] ; immediate
: [THEN] ; immediate
v: fresh extra definitions inside also
: STOP? ( -- true/false )
    key? dup 0= ?EXIT
    drop key  bl over =
    if drop key
    then hx 1B over = ?abort
    bl <> ;
: RECUR ( -- )  \ use only within for-next
    2r> over 0=                     \ index & unnest address
    if nip key dup 1B = ?abort      \ abort on esc
        dup bl = if drop 1          \ new index
        else ch 0 - dup 0A u< and   \ 0..9
            2* 2*                   \ new index
        then swap
    then 2>r ;
(*
  1 for ... recur next \ repeat controlled by key
  esc = abort
  space bar = once again
  key 0..9 = n*4 times
  rest = ready
*)
v: inside definitions
: pchar ( x -- )    dup hx 7F < and bl max ;

v: extra definitions
: MANY   ( -- )  >in @ stop? and >in ! ;

v: forth definitions
: .S ( -- )
    ?stack (.) space
    depth false
    ?do  depth i - 1- pick
        base @ 0A = if . else u. then
    loop ;

v: extra definitions
\ ----- DUMP - 20nov17 an
: DMP ( a -- )                  \ this is a DUMP without count
   hx FF s>d du.str nip 1+      \ column width
   swap    ( colw adr )
    1 for cr base @ hex over 5 u.r ." : " base !
        swap ( adr colw )
        over 8 bounds do i c@ over .r loop ."  |"
        swap ( colw adr )
        8 false    do count pchar emit loop ." | "
    recur next 2drop ;

v: only definitions  extra also  forth also  inside
\ nieuwe versie 2nov20 + iwords
: WORDS   ( -- )  v:  (*
 ['] <> >r begin [ 2>r ]   (            \ no vocs
*)
    hot sysbuf 20 move cr
    begin false dup                     \ voor threada en lfa
        sysbuf
        8 for 2dup @ u<
            if  dup @ 2nip over
            then cell+
        next drop
        dup stop? 0= and
    while                               \ threada lfa
        dup @voc
v:      vp c@ = (*
        2 r@ execute        (           \ no vocs
*)
        if  dup lfa>n space count type space
            48 hor < if cr then
        then compile@ swap !            \ unlink
    repeat 2drop
v:  (*
    rdrop ; : IWORDS ['] = >r           \ no vocs
    [ 2r> ] again           (
*)
;

(* oude versie
: WORDS   ( -- )
    hot sysbuf 20 move
   cr
    begin false dup                     \ voor threada en lfa
        sysbuf
        8 0
        do 2dup @ u<
            if  dup @ 2nip
                over
            then
            cell+
        loop drop
        dup stop? 0= and
    while                               \ threada lfa
v:       dup @voc vp c@  =              \ the right vocabulary?
v:       if
            dup lfa>n space count type space
            48 hor < if cr then
v:       then
        compile@
        swap !                     \ unlink
    repeat 2drop
;
*)

v: fresh inside definitions
\ NFA returns 0 when no header is found!
: >NFA   ( a -- nfa | 0 )
    dup 3 and 0=    \ 32aligned?
    if dup origin chere within          \ in noForth ROM?
        if  dup 2 - h@ FFFF = 2* +      \ skip 2bhyte alignment
            dup 1- c@ FF = +            \ skip 1byte alignment
            1- false                    \ count
            begin over c@ \ 21 7F within \ char?
                dup 21 ch a within
                swap [ ch z 1+ ] literal 7F within or
            while true /string 20 over < \ walk backwards through name
            until
            then
            ?dup
            if  over c@
                       =                \ count ok? \ v
                if  dup 1 and ?EXIT     \ nfa odd -> ok
    then then then then
    false and ;
hex
v: fresh inside definitions
    : ?txt ( a -- )
    dup c@ 1 33 within
    if  dup count
        for count 7F bl within
            if r> 2drop false and exit \ leave for-next and exit
            then
        next count FF = if drop exit then
        1 and ?exit
    then false and ;

value DECA  \ inside also
c? [if]         \ compact version?
: DECOM  (  -- )
    deca ?txt ?dup
    if cr   ." string "   ch " emit   count type  ch " emit then
    deca 1+ ?txt ?dup
    if dup c@ bl <
        if cr   ." name " dup count type
        then drop
    then
    cr deca 6 u.r ." : "                    \ .adr
    deca count pchar emit c@ pchar emit     \ .2chars
    deca h@ 6 u.r                           \ .contents 16bits
(*
    ch , emit
    deca compile@ dup origin chere within
    if 5 u.r                                \ .decompiled romadr
    else drop 5 spaces
    then
*)
    2 spaces
\ adr = cfa?
    deca >nfa ?dup
    if  ." --- "                            \ .cfa
v:        dup 1- c@ 7F and .voc             \ vocabulary
        dup count type                      \ name
        5 - h@ 1 = if ."  imm" then space
        deca @ cell- >nfa ?dup
        if  (.) space count type space      \ made by ..
        then
        EXIT                                \ ----
    then
\ compile@ = cfa?
    deca compile@
    >nfa ?dup                       \ contents = nfa ?
    if  deca compile@ 6 .r space count type 5 spaces         \ .compiled word
    else
\ compile@ = body?
        deca compile@ cell- >nfa ?dup
        if  deca compile@ 6 .r space (.) space count type space     \ mady by ..
            deca h@ >r
            [ ' again 4 / 1+ ] literal r@ =
            [ ' until 4 / 1+ ] literal r@ = +
            [ ' if 4 / 1+ ] literal r@ = -
            [ ' ahead 4 / 1+ ] literal r> = -
            ?dup
            if deca 2 + dup h@ rot ?negate + .
            then
        then
    then
\ adr@ = ram location?
    deca h@ hot +
    dup hot 1+ here within swap 1 and 0= and    \ RAM location?
    if  deca h@ hot + origin
        begin
            begin
                2 + chere over u<
                if  2drop EXIT
                then
                2dup @ =
            until
            dup cell- >nfa ?dup
            if  count type  space (.) ." RAMlocation"
                2drop exit
            then
        again
    then ;

[else]          \ long version
: DECOM  ( -- )
[ c? 0= ] [if] deca 2 and +to deca [then]
    \ deca h@ 0= if 2 +to deca then
    deca ?txt ?dup
    if space    \ cr   ." string "
        ch " emit   count type  ch " emit
    then
    deca 1+ ?txt ?dup
    if dup c@ bl <
        if cr   ." name " dup count type
        then drop
    then
    cr  [ c? ] [if] deca 2 and if ." . " else space space then
    [else] space space [then]
    deca 6 u.r space                        \ .adr
    deca 4 for count pchar emit next drop   \ .4chars
    deca @ 0B u.r space                     \ .contents 32 bits
\   deca @ chere u<
\ adr = cfa?
    deca >nfa ?dup
    if  ." --- "
v:      dup 1- c@ 7F and .voc
        dup count type
        7 - h@ 1 = if ."  imm" then space
        deca @ cell- >nfa ?dup
        if  (.) space count type space

        then 2 +to deca
        EXIT                                \ ----
    then

\ compile@ = cfa?
    deca compile@
    >nfa ?dup                       \ contents = nfa ?
    if  count type 2 +to deca exit  \ .compiled word
    else
\ compile@ = body?
        deca compile@ cell-
        >nfa ?dup
        if  (.) space count type space           \ made by ..
            2 +to deca exit
        then
    then

\ adr@ = ram location?
    deca @
    dup hot here within  swap 1 and 0= and      \ even RAM location?

    if  deca @ origin
        begin
            begin
                2 + chere over u<
                if  2drop EXIT
                then
                2dup @ =
            until
            dup cell- >nfa ?dup
            if  count type space (.) ." RAMlocation"
                2drop exit
            then
        again
    then ;
[then]

v: fresh inside
: MSEE ( a -- )
    -2
    and to deca
    1 for 12345 decom
          2 +to deca
          12345 <> ?abort
          recur
    next ;
: SEE ( <name> -- )   ' msee ;

v: fresh
shield TOOLS\  freeze


\ \ \ \ <><>
