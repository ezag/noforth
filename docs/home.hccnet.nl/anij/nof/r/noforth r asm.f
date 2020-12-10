\ 28jul20
\ risc-v ASSEMBLER voor noForth r(cv)
\ an - 09apr20, 16apr20, 19mei20, 15jun20
\ Definierende woorden eindigen op ~ (tilde)
\ Woorden die met een punt beginnen hebben betrekking op condensed 16bits code.
\ De mnemo-code staat achteraan.
\ Volgorde van de operanden is: doel - bron
\ Ook bij .MOV HMOV en BMOV is de volgorde: doel - bron
\ Let op, bij .SW SH en SB is de volgorde: reg - memadr
\   doel  bron   mnemo       reg memadr mnemo
\   sp -) tos    .mov    =   tos sp -)  .sw
\   tos   sp )+  .mov    =   tos sp )+  .lw

HEX \ until the end
v: ASSEMBLER definitions also
v: vocabulary ASM
v: ASM also
\ -------------------------------------------------
\ --- registernamen
v: ASM definitions
: >REG ( x -- r# )      8000 xor ;
: REG~ ( n naam -- )    >reg constant ;
v: ASSEMBLER definitions
 0 REG~ ZERO     1 REG~ LINK
 2 REG~ RP
 6 REG~ RAM      7 REG~ NXT
 8 REG~ TOS      9 REG~ SP
0A REG~ IP      0B REG~ W
0C REG~ HOP     0D REG~ DAY
0E REG~ SUN     0F REG~ MOON
\ --- adresseerwijzen
-1 constant -)  \ alleen bij destination voor store woorden
-2 constant )   \ impliciet offset 0.
-3 constant x)  \ with offset
-4 constant )+  \ alleen bij source voor load woorden
\ --- hulpwoordjes voor imm en offset
v: ASM definitions
\ --- controles
: ?.REG ( reg -- r# )   >reg 8 - 7 over u< ?abort ; \ 8..0F
: ?REG  ( reg -- r# )   >reg 1F over u< ?abort ;    \ 0..1F
: ?MODUS ( flag -- )    ?abort ;            \ voor modus controle
: ?RANGE.U ( x r -- )   1+ u< 0= ?abort ;   \ range control, unsigned
: ?RANGE.S ( x r -- )   1+ tuck 2/ + swap u< 0= ?abort ;    \ signed
: BP ( offset bits -- bitpatroon )      \ bitpatroon voor offset en imm
    >r     \ imm#
    0
    begin 2* over r> 1+ dup >r
        c@ dup 20 <
    while rshift 1 and or
    repeat 2drop 1 rshift               \ imm# imm# ch  r: adr
    rdrop nip ;
: BITS( ( offset inls -- bp )   r> dup count + aligned >r bp ;
\ KJIHGFEDCBA9876543210
\ 09876543210
\ na BITS moet precies 1 spatie komen
: BITS ( ccc -- )           \ maak inline bitlijst, only compiling
    state @ 0= ?abort
    postpone bits(   bl parse
    dup 1+ c,   0
    do count   40 over < 7 and -   10 -
        1F and c, loop drop
    -1 c, align ; immediate
: PUT ( opc1 bitpatr #lshifts -- opc2 ) lshift or ;
\ --- veel voorkomende coderingen
: REG/2     swap ?REG  2 put ;
: REG/7     swap ?reg  7 put ;
: REG/14    swap ?REG 14 put ;
: REG/0F    swap ?reg 0F put ;
: .REG/2    swap ?.reg 2 put ;
: .REG/7    swap ?.reg 7 put ;
: .NOP 1 h, ;
\ ------------------------------------------------- csrr
: CSRR~   create h,   does> h@
    swap over 4000 and
    if 1F and else ?reg then 0F put
    swap 14 lshift or
    reg/7 , ;
v: ASSEMBLER definitions
1073 csrr~ CSRRW
2073 csrr~ CSRRS
3073 csrr~ CSRRC
5073 csrr~ CSRRWI
6073 csrr~ CSRRSI
7073 csrr~ CSRRCI
\ ------------------------------------------------- .sub
v: ASM definitions
: .SUB~   create h,   does> h@
    .reg/2 .reg/7 h, ;
v: ASSEMBLER definitions
8C01 .SUB~ .SUB
8C21 .SUB~ .XOR
8C41 .SUB~ .OR
8C61 .SUB~ .AND
\ ------------------------------------------------- .mw .add
v: ASM definitions
: ?R0 0= ?abort ;
: .MW~   create h,   does> h@
    reg/2   over ?r0   reg/7  h, ;
v: ASSEMBLER definitions
8002 .MW~ .MW
9002 .MW~ .ADD
\ ------------------------------------------------- .jr .jalr
v: ASM definitions
: .JR~   create h,   does> h@
    over ?r0   reg/7  h, ;
v: ASSEMBLER definitions
8002 .JR~ .JR           \ sun .JR
9002 .JR~ .JALR
\ ------------------------------------------------- .addi
: .ADDI ( n reg -- )
    0001
    over 3F  ?range.s       \ 6bits-s
    over bits 43210  2 put
    swap bits 5     0C put
    reg/7  h, ;
\ ------------------------------------------------- moving 32bits
v: ASM definitions
(*
: .SW C000                      \ tos offset? day modus opc
    swap >r                     \ tos offset? day opc  r: modus
    r@ dup -4 u<   swap )+ = or ?modus
    r@ -) = if  over -4 .addi then
    r> x) =
    if  rot swap                \ tos day offset opc  r: modus
        over 7F  ?range.u       \ 7bits-u
        over bits 543 0A put
        swap bits 26   5 put
    then .reg/7 .reg/2 h, ;
: .LW 4000                      \ tos offset? sun modus opc
    swap >r                     \ tos offset? sun opc  r: modus
    r@ dup -4 u<   swap -) = or ?modus
    r@ )+ = if over r> 2>r then \ tos offset? sun opc  r: sun modus
    r@ x) =
    if rot swap                 \ tos sun offset opc
        over 7F  ?range.u       \ 7bits-u
        over bits 543 0A put
        swap bits 26   5 put    \ tos sun opc
    then .reg/7 .reg/2 h,       \ r: sun? modus
    r> )+ = if r> 4 .addi then ;
*)
: .SW C000                      \ tos offset? day modus opc
    swap >r                     \ tos offset? day opc  r: modus
    r@ dup -4 u<   swap )+ = or ?modus
    r@ -) = if  over -4 .addi then
ahead  [ 2swap ]
    r@ x) =
    if  rot swap                \ tos day offset opc  r: modus
        over 7F  ?range.u       \ 7bits-u
        over bits 543 0A put
        swap bits 26   5 put
    then .reg/7 .reg/2 h, ;
: .LW 4000                      \ tos offset? sun modus opc
    swap >r                     \ tos offset? sun opc  r: modus
    r@ dup -4 u<   swap -) = or ?modus
    r@ )+ = if over r> 2>r then \ tos offset? sun opc  r: sun modus
[ 2swap ] then
    r@ x) =
    if rot swap                 \ tos sun offset opc
        over 7F  ?range.u       \ 7bits-u
        over bits 543 0A put
        swap bits 26   5 put    \ tos sun opc
    then .reg/7 .reg/2 h,       \ r: sun? modus
    r> )+ = if r> 4 .addi then ;
\ ----- rp moves
: (>R)
    nip                 \ tos x? modus
    C002                \ tos x? modus opc
    swap >r             \ tos x? opc  r: modus
    r@ dup -4 u<   swap )+ = or ?modus
    r@ -) = if rp -4 .addi then
    r> x) =
    if  over FF  ?range.u       \ 8bits-u
        swap bits 543276 7 put
    then reg/2 h, ;
: (R>)
    nip                             \ tos x? modus
    4002 swap >r                    \ tos x? opc  r: modus
    r@ dup -4 u<   swap -) = or ?modus
    r@ x) =
    if   over FF  ?range.u      \ 8bits-u
         over bits 5    0C put
         swap bits 43276 2 put
    then reg/7  h,
    r> )+ = if rp 4 .addi then ;
v: ASSEMBLER definitions
: .MOV s>d
    if  over rp = if (R>) exit then .LW exit
    then over 0<
    if  over x) = if swap 2swap else rot then rot
        over rp = if (>R) exit then .SW exit
    then .MW ;
\ ------------------------------------------------- shifts
v: ASM definitions
: .SRLI~   create h,   does> h@
    over 1F  ?range.u       \ [1.1F]? 5bits-u
    swap bits 43210 2 put
    .reg/7 h, ;
v: ASSEMBLER definitions
8001 .SRLI~ .SRLI
8401 .SRLI~ .SRAI
: .SLLI 0002
    over 1F  ?range.u       \ [1.1F]? 5bits-u
    swap bits 43210 2 put
    reg/7 h, ;
\ ------------------------------------------------- slt
v: ASM definitions
: SLT~   create ,   does> @
    reg/14 reg/0F reg/7 , ;    \ s2=d s1 d
v: ASSEMBLER definitions
    0033 SLT~ ADD  \             000.Z.0011.0011
    1033 SLT~ SLL  \             001.Z.0011.0011
    2033 SLT~ SLT  \             010.Z.0011.0011
    3033 SLT~ SLTU \             011.Z.0011.0011
    5033 SLT~ SRL  \             101.Z.0011.0011
40000033 SLT~ SUB  \ 0100.Z.Z.Z.0000.Z.0011.0011
40005033 SLT~ SRA  \ 0100.Z.Z.Z.0101.Z.0011.0011
\ ------------------------------------------------- .li
: .LI   4001
    over 3F  ?range.s       \ 6bits-s
    over bits 5    0C put
    swap bits 43210 2 put
    over ?r0   reg/7 h, ;
\ ------------------------------------------------- .andi
: .ANDI   8801
    over 3F  ?range.s       \ 6bits-s
    over bits 5    0C put
    swap bits 43210 2 put
    .reg/7 h, ;
\ ------------------------------------------------- moving 8 & 16 bits
v: ASM definitions
: LB~   create h,   does> h@          \ r1 offset? r2 x) opc
    swap >r                     \ r1 offset? r2 opc  r: modus
    r@ dup -4 u<   swap -) = or ?modus
    r@ )+ = if over r> 2>r then \ tos offset? sun opc  r: sun modus
    r@ x) =
    if rot swap                 \ r1 r2 offset opc
        over FFF ?range.s       \ 12bits-s
        swap  14 put
    then reg/0F reg/7 dup ,     \ opc
    r> )+ =
    if r> over 1000 and 0= 2 + .addi
    then drop ;
v: ASSEMBLER definitions
0003 LB~ LB
1003 LB~ LH
4003 LB~ LBU
5003 LB~ LHU
v: ASM definitions
: SB~   create h,   does> h@              \ r1 offset? r2 modus opc
    swap >r                         \ r1 offset? r2 opc  r: modus
    r@ dup -4 u<   swap )+ = or ?modus
    r@ -) = if  2dup 1000 and 0= 2 + negate .addi then
    r> x) =
    if  rot swap                    \ r1 r2 offset opc
        over FFF ?range.s           \ 12bits-s
        over bits BA98765 19 put    \ r1 r2 offset opc
        swap bits 43210    7 put    \ r1 r2 opc
    then reg/0F reg/14 , ;
v: ASSEMBLER definitions
0023 SB~ SB
1023 SB~ SH
: BMOV    s>d if LBU exit then
    over x) = if swap 2swap else rot then rot SB ;
: HMOV    s>d if LHU exit then
    over x) = if swap 2swap else rot then rot SH ;
\ ------------------------------------------------- mul div
v: ASM definitions
: MULDIV~   create ,   does> @
    reg/14 reg/0F reg/7 , ;
v: ASSEMBLER definitions
2000033 muldiv~ MUL
2001033 muldiv~ MULH
2002033 muldiv~ MULHSU
2003033 muldiv~ MULHU
2004033 muldiv~ DIV
2005033 muldiv~ DIVU
2006033 muldiv~ REM
2007033 muldiv~ REMU
\ ------------------------------------------------- addi slti
v: ASM definitions
: ADDI~   create h,   does> h@
    over FFF ?range.s       \ 12bits-s
    swap FFF and    14 put
    reg/0F reg/7 , ;
v: ASSEMBLER definitions
0013 ADDI~ ADDI
2013 ADDI~ SLTI
3013 ADDI~ SLTIU
4013 ADDI~ XORI
6013 ADDI~ ORI
7013 ADDI~ ANDI
\ ------------------------------------------------- lui
v: ASM definitions
: LUI~   create h,   does> h@
    swap 0C rshift 0C put
    reg/7 , ;
v: ASSEMBLER definitions
0037 LUI~ LUI
0017 LUI~ AUIPC
: LI ( reg imm -- ) >r
            r@ abs 20 u<
    if r> .li exit
    then    r@ abs 801 u<
    if zero r> addi exit
    then    r@ 800 and
    if  dup r@ 1000 + lui dup
            r> FFF and 1000 - addi exit
    then dup r@ lui dup
            r> FFF and dup      \ reg reg imm imm
    if addi else 2drop drop then ;
\ ------------------------------------------------- .jal .j & conditionals
v: ASM definitions
: .JAL~   create h,   does> h@
    over FFF ?range.s               \ 12bits-s
    swap bits B498A673215 2 put h, ;
    A001 .JAL~ .J
    2001 .JAL~ .JAL
: .COND~   create h,   does> h@ ( -- pza )  \ pza = patroon-zonder-afstand
    .reg/7 ;
v: ASSEMBLER definitions
C001 .COND~ .0<>?
E001 .COND~ .0=?
v: ASM definitions
: COND~   create h,   does> h@        ( -- pza )
    reg/0F reg/14 ;  \ s1 s2   !
v: ASSEMBLER definitions
0063 COND~ <>?     \ beq
1063 COND~ =?      \ bne
4063 COND~ <EQ?    \ blt
5063 COND~ >?      \ bge
6063 COND~ U<EQ?   \ bltu
7063 COND~ U>?     \ bgeu
v: ASM definitions
: .PZAJ? ( pza -- vlag )  A001 = ;
: PZA?   ( pza -- vlag )  63 tuck and = ;
: .PZA?  ( pza -- vlag )  C001 tuck and = ;
: .PMA ( afst pza -- pma )      \ patroon-met-afstand-erin )
    over 1FF ?range.s           \ 9bits-s
    over bits 843   0A put
    swap bits 76215  2 put ;
: PMA ( afst pza -- pma )
    over FFF ?range.s           \ 12bits-s
    over bits CA98765 19 put
    swap bits 4321B    7 put ;
: .PMAJ ( afst pza -- pma )     \ for AHEAD AGAIN
    over FFF ?range.s           \ 12bits-s
    swap bits B498A673215 2 put ;
\ -------------------------------------------------
v: ASSEMBLER definitions
: AHEAD, ( -- ahead,here PZA )
    chere -1 h, A001 ;         \ see THEN,
: DATA, chere -1 h, 2001 ;
: IF, ( PZA -- if,here PZA )
    chere  swap
    dup PZA?  if -1 , exit then
    dup .PZA? if -1 h, exit then
    ?abort ;
: THEN, ( if,here PZA -- )
    >r chere over - r>                  \ if,here afst pza
    dup .PZAJ? if .PMAJ swap romh! exit then   \ AHEAD
    dup PZA?   if PMA   swap rom!  exit then
    dup .PZA?  if .PMA  swap romh! exit then
    ?abort ;
: ELSE,     AHEAD, 2swap THEN, ;
\ -------------------------------------------------
v: ASM definitions
77 constant sysBEGIN,      \ for until, again, repeat,
v: ASSEMBLER definitions
: BEGIN, ( -- begin,here sysbegin, )    chere sysbegin, ;
: UNTIL, ( begin,here sysbegin, PZA  -- )
    swap sysbegin, <> ?abort
    >r chere - r>                       \ begin,here afst PZA
    dup PZA?  if  PMA  ,  exit then
    dup .PZA? if  .PMA h, exit then
    ?abort ;
: AGAIN, ( begin,here sysbegin, -- )
    sysbegin, <> ?abort
    chere -                             \ afstand
    A001 .PMAJ h, ;
\ : .JAL ( doeladres -- )   chere - 2001 .PMAJ h, ;
: WHILE,    IF, 2swap ;
: REPEAT,   AGAIN, THEN, ;
\ ------------------------------------------------- j
\ KJIHGFEDCBA9876543210
\ 09876543210
: J ( doeladres -- )
    6F over FFFFF ?range.s   \ 20bits-s
    over bits K 1F put
    over bits A987654321 15 put
    over bits B 14 put
    swap bits JIHGFEDC 0C put  , ;
\ ------------------------------------------------- RET WFI

: MRET 30200073 , ;
: WFI  10500073 , ;

\ --- ready ---
v: fresh
shield ASM\  freeze


\ <><>
