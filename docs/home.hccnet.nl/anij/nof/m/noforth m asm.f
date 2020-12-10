\ Assembler for noForth m(cv)
\ (C) 2015, 2016. Albert Nijhof & Willem Ouwerkerk
\ 12feb2016 - added: BIX BIA 0=? 0<>? (aliases for XOR> AND> =? <>=?)
\ 30mei2017 - NEXT deleted
\ 27feb2018 - test for "distance too large" added in JCODE
\ 02mar2018 - state=smart # in noForth C and CC
(*
    When state is true, the core word # is compiled,
    when state is false, the assembler # is executed.
    In assembler macros
    the assembler # will produce an error message:
             : test chere # tos add ;
   Use -4 in stead
            : test chere -4 tos add ;
*)

hex     \ until the end
V: fresh inside also assembler also definitions
\ ----- Addressing
00 constant PC  01 constant RP          02 constant SR  03 constant CG
04 constant SP  05 constant IP          06 constant W   07 constant TOS
08 constant DAY 09 constant MOON        0A constant SUN 0B constant XX
0C constant YY  0D constant ZZ          0E constant DOX 0F constant NXT
-1 constant X)  -2 constant )           -3 constant )+

-v: : # state @ if postpone # exit then -4 ; immediate
v: -4 constant #

-5 constant -)  40 constant .B          : #0  cg ;
: #2  cg ) ;    : #-1 cg )+ ;           : #1  0 cg x) ; \ no extension!
: #4  sr ) ;    : #8  sr )+ ;           : &   sr x) ;

V: inside definitions
  variable ext?        \ lo-byte:  registerposition in opcode
                       \ hi-byte:  bit1set -> ext1, bit2 set -> ext2
  value ext1   value ext2
: prep  @
  over .b = if or then
  over -) =
  if nip >r r@ 40 and swap >r   \ byte or cell?
     if #1 else #2 then r@
     [ chere ext? ! -1 , ]      \ for SUB
     0 r> x) r>                 \ followed by main instruction
  then 0 ext? ! ;
: dst ( opcode -- opcode )
  >r
  s>d 0=    if 0 then                                   \ reg.direct
  dup ) =   if drop 0 swap x) then                      \  reg )  ->  0 reg x)
  dup x) =  if rot to ext2  200 ext? **bis then         \ index>extension
  -2 over < if negate 7 ( a.pos ) lshift  r> or swap
               dup 0F u> ?abort                         \ reg error
               ext? c@ ( r.pos ) lshift or exit         \ reg  and   reg x)
            then true ?abort ;
: src ( opcode -- opcode )
  >r
  s>d 0=    if 0 then                                   \ reg.direct
  dup x) =  if rot to ext1  over cg <>                  \ ext ?
               if 100 ext? **bis then then              \ not for #1
  dup -4 =   if drop to ext1  100 ext? **bis pc )+ then  \ xxxx #
  -4 over < if negate 4 ( a.pos ) lshift  r> or swap
                 dup 0F u> ?abort                       \ reg error
                 ext? c@ ( r.pos ) lshift or exit then  \ all addrmodes
  true ?abort ;
: ,,, ( opcode -- )      ,              \ write the code
  100 ext? bit** if ext1 , then
  200 ext? bit** if ext2 , then ;
: 1op    create , does> prep src   ,,, ;
: 2op    create , does> prep dst   8 ext? c! src   ,,,  ;

V: assembler definitions
\ ----- Mnemocodes
: RETI 1300 , ;
1000 1op RRC    1080 1op SWPB   1100 1op RRA
1180 1op SXT    1200 1op PUSH   1280 1op CALL
4000 2op MOV    5000 2op ADD    6000 2op ADDC
7000 2op SUBC   8000 2op SUB    9000 2op CMP
A000 2op DADD   B000 2op BIT    C000 2op BIC
D000 2op BIS    E000 2op BIX    E000 2op XOR>
F000 2op BIA    F000 2op AND>
 ' sub ext? @ rom!      \ Patch in -)?

\ ----- Macros
\ : NEXT  nxt pc mov ;
\ : setc  #1 sr bis ;   : clrc  #1 sr bic ;
\ : eint  #8 sr bis ;   : dint  #8 sr bic ;

\ ----- Conditions
2000 constant =?        2400 constant <>?
2000 constant 0=?       2400 constant 0<>?
2800 constant CS?       2C00 constant CC?
2800 constant U<EQ?     2C00 constant U>?
3000 constant POS?      3400 constant >?
3800 constant <EQ?      3C00 constant NEVER

V: inside definitions
: ?cond ( cond -- )  never invert and ?abort ;
: jcode ( to from -- jumpcode ) \ bereken afstand en vul cond (ext1) in.
  cell+ - 2/
  dup 201 -1FF within ?abort   \ 27feb2018
  3FF and ext1 dup ?cond or ;
(
 never  = cond for always.jump, see ahead, again
 never  = masker for condition, see ?cond
 3FF    = masker for offset, see then and until
 Assembler safety numbers:
 66 sys\if,     for then, ahead, repeat,
 77 sys\begin,  for until, again, repeat,
)
V: assembler definitions
\ ----- Assembler conditionals
: IF, ( cond -- ifa ifcond+66 ) dup ?cond 66  or chere swap  -1 , ;
: BEGIN, ( -- begina 77 )       chere 77 ;
: THEN, ( ifa ifcond+66 -- )
  never
  2dup and to ext1              \ ifa ifcond+66
  invert and 66 ?pair           \ ifa=from
  chere over                    \ ifa=! chere=to ifa=from
  jcode swap                    \ jcode ifa!
  rom! ;
: AHEAD,        never if, ;     : ELSE,         ahead, 2swap then, ;

: UNTIL, ( begina 77 cond -- )
  to ext1                       \ begina 77
  77 ?pair                      \ begina=to
  chere                         \ begina=to chere=from
  jcode , ;
: AGAIN,        never until, ;      : REPEAT,       again, then, ;

: WHILE,        if, 2swap ;
: JMP           77 again, ;     \ jump, relative addr in opcode

V: fresh
shield asm\ freeze
cr .(   noForth assembler loaded    )
\ <><>
