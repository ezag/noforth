\ tools for C CC V VV -- november 2017

hex
v: fresh inside
: STOP? ( -- true/false )
    key? dup 0= ?EXIT
    drop key  bl over =
    if drop begin key
    [ 2swap ]
    then hx 1B over = ?abort
    bl <>
    [ 2swap ]
; : STOPPER  ( - true/false ) [ 2swap ] again [ reveal 2drop

: .S ( -- )
    ?stack (.) space
    depth false
    ?do  depth i - 1- pick
        base @ 0A = if . else u. then
    loop ;

 \ NFA returns 0 when no header is found!
: >NFA   ( a -- nfa | 0 )
    dup origin
    chere within                        \ in noForth ROM?
    if  dup 1 and 0=                    \ even?
        if  1- dup c@ FF = +            \ skip alignment char
            false
            begin over c@ 21 7F within  \ char?
            while true /string 20 over <  \ walk backwards through name
            until
            then
            ?dup
            if  over c@
c:              3F and =                \ count ok? \ c
v:              7F and =                \ count ok? \ v
                if  dup 1 and ?EXIT     \ nfa odd -> ok
    then then then then
    drop false ;

: .NAME ( nfa -- ) count 1F and type ;

c: : IWORDS 40 ahead [ 2swap  2drop reveal
: WORDS   ( -- )
c:  false [ 2swap ] then  >r
    false >r                                \ counting
    fhere
    [ adr pfx-link hot - ] literal
    hot dup
    2over move drop                     \ threads > fhere
    bounds
    cr
    begin false dup                     \ threada lfa
        2over
        do  dup i @ u<
            if  2drop i dup @
            then                        \ threada lfa
        2 +loop
        dup stop? 0= and
    while                               \ threada lfa
c:        dup 1+ c@ 40 and 2r@ drop =   \ 0 for WORDS, 40 for IWORDS
v:        dup @voc vp c@ =              \ the right vocabulary?
        if  r> 1+ >r                    \ counting
            dup lfa>n space .name space
            48 hor < if cr then

        then
c:      lnk@
v:      @
        swap !                     \ unlink
    repeat
    2drop 2drop
c:    2r> (.) false .r drop
v:    r> (.) false .r
;

\ ----- DUMP - 20nov17 an
: pchar ( x -- )    dup hx 7F < and bl max ;

: DMP ( a -- )                  \ this is a DUMP without count
   hx FF s>d du.str nip 1+      \ column width
   swap    ( colw adr )
   begin cr base @ hex over 4 u.r ." : " base !
      swap ( adr colw )
      over 8 bounds do i c@ over .r loop ."  |"
      swap ( colw adr )
      8 false       do count pchar emit loop ." | "
   stopper until 2drop ;

\ --- SEE & MSEE
: DECOM  ( a -- )
    cr dup 6 u.r space                      \ .adr
    dup count pchar emit c@ pchar emit      \ .2chars
    dup @ 6 u.r space                       \ .contents
    dup >nfa ?dup
    if  ." --- "
v:      dup 1- c@ 7F and .voc
        dup .name
        c@ 80 < if ."  imm" then space
        @ cell- >nfa ?dup
        if  (.) space .name space
        then
        EXIT                                \ ----
    then

[ ' if dup @ u<
   ch Q over and            \ skip until "Q" for CC and VV
   swap invert ch ( and     \ skip until "(" for C and V
   or beyond

( ] ( not for CC and VV )
    dup @                                   \ contents
    dup 1 and                               \ odd
    if  dup -7800 <
        if          ch -  [ ' UNTIL >nfa ] literal
        else dup -7000 <
            if      ch +  [ ' IF >nfa ] literal
            else dup  7000 <
                if  2/ ." #" u. drop EXIT   \ a number
                then
                dup  7800 <
                if  ch -  [ ' AGAIN >nfa ] literal
                else ch + [ ' AHEAD >nfa ] literal
                then
            then
        then
        .name space emit ch > emit space
        FFF and 7FF - + u. EXIT
    then
    drop
( Q ] ( continue for all versions )

    @
    dup >nfa ?dup                       \ contents nfa ?
    if  .name drop EXIT                 \ .name of compiled word
    then                                \ contents
\   for compiler words via body
    dup cell- >nfa ?dup
    if  (.) space .name space drop  EXIT
    then
\
    dup hot here within                 \ RAM location?
    if  origin
        begin
            begin
                cell+ chere over u<
                if  2drop EXIT
                then
                2dup @ =
            until
            dup cell- >nfa ?dup
            if  .name ."   RAM location "
            then
        again
    then
    drop ;

: MSEE ( a -- )
    hx FFFE and
    begin dup decom cell+ stopper
    until drop ;
: SEE ( <name> -- )   ' msee ;

: MANY   ( -- )  >in @ stop? and >in ! ;

shield TOOLS\
v: fresh
freeze

\ <><>
