\ Disassembler for noForth m(cv)
\ (C) 2015, 2016, 2017. Albert Nijhof & Willem Ouwerkerk
\ an    -- 05mei12 -- 430 disassembler
\ an jan2016 - XOR> and AND> changed to BIX and BIA
\ an 30mei2017 - stopper per line

\ This disassembler output uses noForth assembler notation.
\ MSP assembly     disassembles to
\ ------------     ------------      --------------
\ PC TOS           pc tos            Register names
\ PC@              pc )              Indirect addressing
\ @PC+             pc )+             Indirect with autoincrement
\ 430              xx pc x)          xx + pc = 430 (Symbolic mode)
\ 2(R8)            2 r8 x)           Indexed
\ #430             430 #             constant 430 assembled as pc )+
\ &430             430 &             Absolute using SR
\ #4 #8            #4 #8             Constants using RS
\ #0 #1 #2 #-1     #0 #1 #2 #-1      Constants using CG

hex  \ until the end
V:   fresh inside definitions
value dasa
value dasa+
: GETCELL ( -- dascode )    dasa+ dasa + @  2 +to dasa+ ;
\ : BL- ( a n -- a n2 )  dup 0 do 2dup + 1- c@ bl = + loop ; \ -trailing
: .MNEMO  ( +n adr -- )
  swap 2* 2* + 4
  dup 0 do 2dup + 1- c@ bl = + loop
  type space ;
:  .W&W ( -- )                          \ Print where and what
   cr dasa 5 u.r ." :" space            \ Print address
   dasa 2 0 do count dup 7F bl within if drop bl then emit
            loop drop space             \ Print text
   dasa @   5 u.r 3 spaces              \ Print content
   2 +to dasa ;

chere
\  R0  R1  R2  R3  R4  R5  R6  R7  R8  R9  R10 R11 R12 R13 R14 R15
S" pc  rp  sr  cg  sp  ip  w   tos day moonsun xx  yy  zz  dox nxt "  M,
: .DST ( a r -- )
   over 1 = if getcell u.
      dup 2 = if  2drop ." & " exit then then
   [ rot ] literal .mnemo
   dup 1 = if ." x)" then
   dup 2 = if ." )"  then
   dup 3 = if ." )+" then
   if space then ;

: .SRC ( a reg -- )
   dup 3 = if drop dup 3 = if 4 - then  ." #" . exit then   \ cg #-1 #0 #1 #2
   over 2 and over 2 = and if ." #" 1- swap lshift . exit then  \ sr #4 #8
   over 3 = over 0= and if 2drop
   getcell u. ." # " exit then .dst ;
: B/W     ( dascode -- )  40 and if ." .b " then ;

chere
S" RRC SWPBRRA SXT PUSHCALLRETI7?  "  M,
: ONE-OP ( dascode 1 )   drop >r
   r@ ( dascode )  7 rshift 7 and   dup 6 <>  \ not reti?
   if    r@ 4 rshift 3 and   r@ 0f and .src   r@ b/w
   then  r> drop
   [ rot ] literal .mnemo ;

chere
S" MOV ADD ADDCSUBCSUB CMP DADDBIT BIC BIS BIX BIA "  M,
: TWO-OP ( dascode 4..F )   swap
   ( src a,r ) dup 4 rshift 3 and   over 8 rshift 0F and   .src space space
   ( dst a,r ) dup 7 rshift 1 and   over          0F and   .dst  b/w
   ( mnemo )   4 -
   [ rot ] literal .mnemo ;

chere
\  J0<>J0= JCC JCS J0< J>= J<  GOTO"
S" =?  <>? cs? cc? pos?>?  <eq?    "  M,
: JMP-OP ( dascode 2..3 )   drop
   dup 03FF and 0200 over and    \ Negative distance?
   if FC00 or
   then s>d >r          \ Backward?
   2* dasa +            \ Calculate destination
   swap 0A rshift 7 and
   dup
   [ rot ] literal .mnemo
   7 =
   if 8 emit r@ if ." AGAIN," else ." AHEAD," then
   else      r@ if ." UNTIL," else ." IF," then
   then 5 spaces   ch + r> 2* - emit   ch > emit   u. ;

\ Decode one instruction, addr has to be in dasa
: DAS+ ( -- ) \ disassemble next instruction
   dasa @+ = if .w&w ." --- cfa ---" then
   .w&w   0 to dasa+
   dasa cell- @   dup
   dup 0C rshift                        \ opcode  n
        dup 0=  if 2drop ." ?"          \ Invalid opcode
   else dup 1 = if one-op
   else dup 4 < if jmp-op
   else ( 4..F )   two-op
   then then then 4630 = if ." --->>"  cr then
   dasa+ 2/ 0 ?do dasa @+ = if leave then .w&w loop
   dasa @+ = if cr then ;

\ ----- User words
V:   forth definitions inside
(*
: MDAS ( adr -- )
   FFFE and to dasa
   begin das+ stopper until ;   \ oude versie
*)
: MDAS FFFE to dasa
    1 for das+ recur next ;     \ nieuwe versie

: DAS  ( ccc -- ) ' mdas ;
V:   fresh
shield DAS\ freeze
cr .(  noForth disassembler loaded )

\ <><>
