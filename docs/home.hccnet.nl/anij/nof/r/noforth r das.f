\
\ noForth r(cv) das -- disassembler -- an - 02juli20
hex \ until the end
v: fresh  extra definitions  vocabulary DASM
v: dasm definitions
: .ch ( ch -- ) [ hex ]
    dup 7F u< and bl max emit ;
: type20 ( a -- )
    10 0 do count dup emit
            bl = if leave then
    loop drop ;
: opc? ( ch a n -- )
    drop swap ch 0 + >r
    begin count r@ = if rdrop exit then
        begin  count bl = until
        dup c@ ch ? =
    until drop rdrop false ;
: .regnr ( regnr -- )
    dup 18 and 8 =        \ in 8..F ?
    if 7 and
        s" 0tos 1sp 2ip 3w 4hop 5day 6sun 7moon ?"
        OPC? ?dup if type20 then exit
   then
    dup s" 0zero 1link 2rp 6ram 7nxt ?"
      OPC? ?dup
        if type20 drop exit
        then ." x" base @ decimal swap . base ! ;
: .reg ( code positie -- ) rshift 1F and .regnr ;
: .reg' ( code positie -- ) rshift 7 and 8 + .regnr ;
: GET ( code pos -- code imm ) rshift ;
value dasa  400 to dasa
value ^
\ : .x) ." x) " ;
: .x) ( offset -- )
    if ch x emit then ." ) " ;
\ ----- quadrant 0 -----
: [26.3]u     ( x -- y )    \ addi4spn, sw lw
   0 over 0F and or 1 lshift
   swap 4 get 1 and or 2 lshift ;
: [54987623] ( x -- y )
   0 over 2 get 0F and or 2 lshift
   over 6 get 3 and or 1 lshift
   over 0 get 1 and or 1 lshift
   swap 1 get 1 and or 2 lshift ;
: ch? ( ch -- ch|0 )
    dup 7F <    if
    bl over <   if
    dup ch a - 19 u> if
        exit
    then then then drop 0  ;
: .string? ( a n -- )    \ type if name
    1E over 1- u< if 2drop exit then
    2dup 0 do
        count
       ch? 0= if unloop drop 2drop exit then
    loop drop
    cr 7 spaces type  ;
: Q0 ( -- )
^ 0= ?exit
^ 0D get 7 and
>r                              \ opc
r@ 0=
if  ^ 2 .reg'
    ^ 5 get [54987623] .
then
r@ 2 = r@ 6 = or
if  ^ 2 .reg'
    ^ 0A get 7 and
    ^ 5 get 3 and 3 lshift
    or [26.3]u >r   r@ ?dup if . then
    ^ 7 .reg' r> .x)
then
r> s" 2.lw 6.sw 0.addi4spn 4.Reserved ?"
opc? ?dup if type20 else ." ?" then ;

\ ----- quadrant 1 -----
: [B498A673.15]s ( x -- y ) \ .jal
   0 over 0A get 1 and or 1 lshift
   over 6 get 1 and or 2 lshift
   over 7 get 3 and or 1 lshift
   over 4 get 1 and or 1 lshift
   over 5 get 1 and or 1 lshift
   over 0 get 1 and or 1 lshift
   over 9 get 1 and or 3 lshift
   swap 1 get 7 and or 1 lshift
   dup 800 and 2* - ;
: [84376215]s ( x -- y )    \ beqz
   0 over 7 get 1 and or 2 lshift
   over 3 get 3 and or 1 lshift
   over 0 get 1 and or 2 lshift
   over 5 get 3 and or 2 lshift
   swap 1 get 3 and or 1 lshift
   dup 100 and 2* - ;
: Q1 ( -- )
^ 1 = if ." .nop" exit then
^ 0D get 7 and
>r             \ p  r: opc
r@ 4 <>
if  r@ 0= r@ 2 = or
    if  ^ 7 .reg
        ^ 2 get 1F and          \ [43210]s
        ^ 0C get 1 and          \ [5]
            5 lshift - .
        r> s" 0.addi 2.li ?"
        opc? type20 exit
    then
    r@ 1 = r@ 5 = or
    if  ^ 2 get
        [B498A673.15]s dasa + .
        r> s" 1.jal 5.j ?"
        opc? type20 exit
    then
    r@ 3 =
    if  ^ 7 .reg
        ^ 2 get 1F and          \ [16:12]
        ^ 0C get 1 and          \ [17] nz
            5 lshift -
        0C lshift u.
        ." .lui" rdrop exit
    then
    r@ 5 >
    if  ^ 7 .reg'
        ^ 2 get 1F and
        ^ 0A get 7 and
            5 lshift or
        [84376215]s
        s>d 0= if ." +" then dup . ." -> "
        dasa + .
        r> s" 6.beqz 7.bnez ?"
        opc? type20 exit
    then
then rdrop     \ =4
^ 0A get 3 and
>r
r@ 2 <
if  ^ 7 .reg'
    ^ 2 get 1F and
    ^ 0C get 1 and
        5 lshift or .
    r> s" 0.srli 1.srai ?"
    opc? type20 exit
then
r@ 2 =
if  ^ 7 .reg'
    ^ 2 get 1F and
    ^ 0C get 1 and
        5 lshift - .
    ." .andi" rdrop exit
then
rdrop
^ 5 get 3 and
^ 0C get 1 and
    2 lshift +
>r
r@ 4 <
if  ^ 7 .reg'
    ^ 2 .reg'
r@ s" 0.sub 1.xor 2.or 3.and ?"
opc? ?dup if type20 then
then rdrop
;
\ ----- quadrant 2 -----
: [5.276]u
    0 over 0 get 3 and or 4 lshift
    swap 2 get 0F and or 2 lshift ;
: [4.27.5]u
    0 over 0 get 7 and or 3 lshift
    swap 3 get 7 and or 2 lshift ;
: Q2  ( -- )
^ 9002 = if ." .ebreak" exit then
^ 0D get 7 and
>r
r@ 4 <>
if r@ 0=
    if ^ 7 .reg
       ^ 2 get 1F and .
      ." .slli" rdrop exit
   then
   r@ 2 =
   if ^ 7 .reg
      ^ 2 get 1F and 1 lshift  \ [43876?]
      ^ 0C get 1 and
        or [4.27.5]u >r   r@ ?dup if . then
        ." rp " r> .x)
      ." .lwsp" rdrop exit
   then
   r@ 6 =
   if ^ 2 .reg
      ^ 7 get 7F and
      [5.276]u >r   r@ ?dup if . then
      ." rp " r> .x)
      ." .swsp"
   then
    rdrop exit
then rdrop          \ = 4
   ^ 7 .reg
   ^ 2 get 1F and
   if ^ 2 .reg
      ^ 0C get 1 and
      s" 0.mv 1.add ?"
      opc? type20 exit
   then
   ^ 0C get 1 and
   s" 0.jr 1.jalr ?"
   opc? type20 ;
\ ----- quadrant 3 -----
: muladd32 ( -- )
^ 7 .reg
^ 0F .reg
^ 14 .reg
^ 19 get
>r
^ 0C get 7 and
r@ 1 =
if s" 0MUL 1MULH 2MULHSU 3MULHU 4DIV 5DIVU 6REM 7 REMU ?"
   opc? type20 rdrop exit then
r@ 0=
if s" 0ADD 1SLL 2SLT 3SLTU 4XOR 5SRL 6OR 7AND ?"
   opc? type20 rdrop exit then
r@ 20 =
if s" 0SUB 5SRA ?"
    opc? ?dup if type20 rdrop exit then
then ." ?"
rdrop drop ;
: shiaddi32 ( -- )
^ 7 .reg
^ 0F .reg
^ 0C get 7 and
>r
^ 14 get
    r@ 5 = if 1F and then
    dup 800 and 2* - .          \ 12bits
r@ s" 0ADDI 1SLLI 2SLTI 3SLTIU 4XORI 6ORI 7ANDI ?"
opc?  ?dup if type20 rdrop exit then
r> 5 <> if ." ?" exit then
^ 19 get
0<> abs
s" 0SRLI 1SRAI ?"
opc? type20 ;
: load32 ( -- )
^ 7 .reg
^ 14 get dup 800 and 2* - >r   r@ ?dup if . then
^ 0F .reg r> .x)
^ 0C get 7 and
s" 0LB 1LH 2LW 4LBU 5LHU ?"
opc? ?dup if type20 else ." ?" then ;
: store32 ( -- )
^ 0C get 7 and
>r
2 r@ < if rdrop exit then
^ 0F .reg
^ 19 get 5 lshift
^ 7 get 1F and or
    dup 800 and 2* - >r   r@ ?dup if . then
^ 14 .reg r> .x)
r> s" 0SB 1SH 2SW ?" opc? type20 ;

: [CA.1B]s ( x -- y )    \ beq
0 over 0B get 1 and or 1 lshift
over 0 get 1 and or 0A lshift
swap 1 get 3FF and or 1 lshift
dup 1000 and 2* - ;

: beq32 ( -- )
^ 0C get 7 and
>r
r@ 2 = r@ 3 = or if rdrop exit then
^ 0F .reg
^ 14 .reg
^ 19 get 5 lshift
^ 7 get 1F and or
[CA.1B]s
s>d 0= if ." +" then dup . ." -> "
dasa + .
r> s" 0BEQ 1BNE 4BLT 5BGE 6BLTU 7BGEU ?"
OPC? TYPE20 ;
: csrr32 ( -- )
^ 7 .reg
^ 14 get .
^ 0F
^ 0E get 1 and
if get 1F and . else .reg then
^ 0C get 7 and
s" 1CSRRW 2CSRRS 3CSRRC 5CSRRWI 6CSRRSI 7CSRRCI ?"
opc? ?dup if type20 else ." ?" then  ;
: [jal]s    \ [20 10:1 11 19:12]
0 over 13 get 1 and or 8 lshift
over 0 get FF and or 1 lshift
over 8 get 1 and or 0A lshift
over 9 get 3FF and  or 1 lshift
swap 80000 and 2* - ;
: rest32 ( opc -- )
^ 7 .reg
dup 1B = ( 11011 jal )
if drop ^ 0C get [jal]s dasa + u. ." JAL" exit
then
dup 19 = ( 11001 jalr )
if ^ 0C get 7 and 0=
    if drop
       ^ 0F .reg
       ^ 14 get dup 800 and 2* - .
       ." JALR" exit
    then
then
17 and 5 <> if ." ?" exit then
^ FFFFF000 and u.
^ 5 get 1 and
s" 0AUIPC 1LUI ?"
opc? type20 ;
\ : fence32 ??

: q3 ( -- )
^ 2 get 1F and
dup 0=   if drop load32 exit then
\ dup 3  = if drop fence32 exit then
dup 4  = if drop shiaddi32 exit then
dup 8  = if drop store32 exit then
dup 0C = if drop muladd32 exit then
dup 18 = if drop beq32 exit then
dup 1C = if drop csrr32 exit then
rest32 ;
: kopje ( -- )
    dasa cell- @+ = if  cr 7 spaces ." ------  body" then
    dasa 1- count .string?
   dasa cr dup 5 u.r ." : "
   h@ to ^       \ windows, te laden voooor de meta assembler
   ^ FF and .ch
   ^ 8 rshift FF and .ch
   ^ 5 u.r space
    ;

: 1das ( -- )
\    dasa 1- count .string?
    kopje ^ 3 and
\     dup 3 = if ch " else ch ' then emit space
2 spaces
    dup 0=  if drop q0  exit then
    dup 1 = if drop q1  exit then
    dup 2 = if drop q2  exit then
    drop
    dasa @ to ^ q3
2 +to dasa
kopje ch ~ emit
    ;
v: fresh dasm also inside
: cdas ( -- )
    1
    for 12345 1das 2 +to dasa
        12345 <> ?abort
    recur next ;
: das ( 'naam' -- ) ' to dasa cdas ;
: mdas ( adr -- ) -2 and to dasa cdas ;

v: fresh
shield das\  freeze


\ <><>
