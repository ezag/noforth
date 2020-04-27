\ noForth meta assembler (cross assembler)
\ This 430 assembler (for a 32 bit forth) produces input commacode for noForth.
\ See the example at the end of this file.
\ Updated: 12feb2016. BIX BIA 0=? 0<>?
\ 10apr2016: -) is repaired, see locations marked with ^^^

\ Copyright (C) 2015, Albert Nijhof & Willem Ouwerkerk
\
\    This program is free software: you can redistribute it and/or modify
\    it under the terms of the GNU General Public License as published by
\    the Free Software Foundation, either version 3 of the License, or
\    (at your option) any later version.
\
\    This program is distributed in the hope that it will be useful,
\    but WITHOUT ANY WARRANTY; without even the implied warranty of
\    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
\    GNU General Public License for more details.
\
\    You should have received a copy of the GNU General Public License
\    along with this program.  If not, see <http://www.gnu.org/licenses/>.

vocabulary noforth
noforth also definitions

 hex   \ until the end

: ?input 0= abort"  End of input " ;
: CH   char state @ if postpone literal then ; immediate
: UPC) ( adr -- ) \ make ch at adr uppercast
  dup c@ dup ch a ch { within if bl xor swap c! else 2drop then ;
: UPPER ( a n -- ) over + swap ?do i upc) loop ;
: BL-WORD ( -- countedstring )        \ does refill
  begin  bl word dup c@ 0=
  while drop refill ?input
  repeat ;

\ ----- commentaarbegrenzers -----
: TEXT,   ( a n -- )  here swap dup allot move ;
: SAME? ( cstr1 cstr2 -- ? ) over c@ 1+ tuck compare 0= ;
: IGNORE ( <startstring> <endstring> -- )
  create immediate bl word  dup count upper dup c@ 1+ text, align
  does> begin bl-word dup count dup ?input
           upper over same?
        until drop ;
IGNORE <---- ---->  \ comment marker

\ ----- multiple definitions
' constant value DEFINER
: MULTI ( <def-word> -- )  ' to definer
   begin    bl-word count  over c@ ch \ <>
   while    evaluate    definer execute
   repeat   2drop ;

\ operators for 16 bit data, show what happens
: X!   2dup cr swap FFFF and 2B .r  ." >"    .  \ show
       over 8 rshift over 1+ c! c! ;            \ do
: X,   dup cr here 20 .r    ." : "   FFFF and . \ show
       dup c, 8 rshift c, ;                     \ do


\ ----- adressing
: ?ADR  abort"  Addressing error " ;
: ?REG   0F u> abort"  Register expected " ;

multi constant
  00 PC   01 RP    02 SR   03 CG    04 SP   05 IP    06 W    07 TOS
  08 DAY  09 MOON  0A SUN  0B XX    0C YY   0D ZZ    0E DOX  0F NXT
  -40 .B  -1 X)    -2 )    -3 )+    -4 #    -5 -)   \\

            : #4  sr ) ;  : #8  sr )+ ;   : &   sr x) ;
: #0  cg ;  : #2  cg ) ;  : #-1 cg )+ ;   : #1  0 cg x) ; \ no extension!

\ 0 -PAREN ^^^ is removed
multi value  4 A.POS    8 R.POS
  0 D.EXT    0 D.EXT?   0 S.EXT   0 S.EXT?    \\
\ a.pos = location of addresmode in opcode. (bit#0)
\ r.pos = location of register# in opcode.  (bit#0)

: DST ( opcode -- opcode )
   >r
   s>d 0=      if 0 then                                \ reg.direct
   dup ) =     if drop 0 swap x) then                   \  reg )  ->  0 reg x)
   dup x) =    if rot to d.ext  true to d.ext? then     \ index>extension
   -2 over <   if negate a.pos lshift  r> or swap
                  dup ?reg r.pos lshift or  exit then   \ reg  and   reg x)
   true ?adr ;

: SRC ( opcode -- opcode )
   >r
   s>d 0=      if 0 then                                   \ reg.direct
   dup x) =    if rot to s.ext  over cg <>                 \ ext ?
                  if true to s.ext? then then              \ not for #1
   dup # =     if drop to s.ext  true to s.ext? pc )+ then \ xxxx #
   -4 over <   if negate a.pos lshift  r> or swap
                  dup ?reg r.pos lshift or   exit then     \ all addrmodes
   true ?adr ;

: ASSEM, ( opcode -- )  x,
   s.ext?  if s.ext x, then   d.ext?  if d.ext x, then ;

: NO.EXT    false to s.ext?  false to d.ext?  ;
: .B?   over .b = if swap negate or then ;
0 value 'SUB \ ^^^ added for -)
: -)?        \ ^^^ renewed
    over -) =
    if  nip >r r@ 40 and swap >r    \ byte or cell?
        if  #1 else #2
        then
        r@
        'sub execute                \ insert decrement instruction
        0 r> x) r>                  \ followed by main instruction
    then ;

<---- ^^^ removed
: -)?   >r dup -) = if  drop -2 swap x) here else 0 then to -paren r> ;
: -PAREN? -paren if -paren c@ 0F and ( reg ) 8320 or ( #2 sub ) x, then ;
---->
\ ----- mnemocodes
: A&R to r.pos to a.pos ;
: 1OP    create , does> @ .b? no.ext   4 0 a&r src   assem, ;
: 2OP    create , does> @ .b? -)? no.ext
         7 0 a&r dst   4 8 a&r src    assem, ( -paren? ^^^ ) ;

multi 1op      1000 RRC    1080 SWPB   1100 RRA
   1180 SXT    1200 PUSH   1280 CALL      \\
: RETI 1300 x, ;
multi 2op      4000 MOV    5000 ADD    6000 ADDC
   7000 SUBC   8000 SUB    9000 CMP    A000 DADD
   B000 BIT    C000 BIC    D000 BIS
   E000 XOR>   E000 BIX    F000 AND>    F000 BIA   \\
' sub to 'sub \ ^^^ added for -)
\ Macros
: NEXT    nxt pc mov  ;
: SETC  #1 sr bis ;   : CLRC  #1 sr bic ;
: EINT  #8 sr bis ;   : DINT  #8 sr bic ;

\ ----- assembler conditionals
multi constant
    2000 =?     2400 <>?    2000 0=?    2400 0<>?
    2800 CS?    2C00 CC?    2800 U<EQ?  2C00 U>?
    3000 POS?   3400 >?     3800 <EQ?   3C00 NEVER
    3FF <OFFSET>
   0055 CODE-ID   0066 IF,ID  0077 BEGIN,ID   \\

\ <offset>     = masker for offset -> then and until
\ never        = cond for always.jump -> ahead, again
\              = masker for condition -> see ?cond

: ?PAIR ( x y -- )   - abort"  Conditionals not paired. " ;
: ?COND ( cond -- )  never invert and        \ niet waterdicht
                     abort"  Condition needed. " ;

: IF, ( cond -- ifloc ifcond ) dup ?cond if,id  or here swap  2 allot ;
: BEGIN, ( -- beginloc begin,id )  here begin,id ;
: THEN, ( ifloc ifcond -- )
   dup   never invert and  if,id ?pair
   never and   dup ?cond   >r
   here over 2 + - 2/ <offset> and  r> or    swap x! ;
: UNTIL, ( beginloc begin,id cond -- )
   dup ?cond   >r     begin,id ?pair
   here 2 + - 2/ <offset> and    r> or    x, ;
: AGAIN,    never until, ;
: ELSE,     never if, 2swap then, ;
: WHILE,    if, 2swap ;
: REPEAT,   never until, then, ;
: AHEAD,    never if, ;
: JMP       begin,id again, ;  \ jump, relative addr in opcode

: NOCODE
  here bl-word dup c@ 1+ text, align
  here code-id ;
: END-CODE ( here1 here2 code-id -- )
   code-id ?pair
   cr cr ." CODE " swap count type cr
   here swap ?do
     i @ FFFF and space u. ." , "
     i 0F and 0= if cr then
          2 +loop cr ." END-CODE " cr cr ;

forth definitions
: CODE nocode ;
noforth
create RUBBISH
cr .( ----- aux430ass.f loaded ----- )

<----  example: include this text
hex
code MOVE
   sp )+ w mov  sp )+ sun mov
   #0 tos cmp
   <>? if,   w sun cmp
   u>? if,   tos sun add  tos w add
      begin,  #1 sun sub  #1 w sub
         sun ) w ) .b mov  #1 tos sub
	  =? until,
   else,
      begin,  sun )+ w ) .b mov
         #1 w add  #1 tos sub
      =? until,
   then,
   then,   sp )+ tos mov   next end-code

----- and this will come out:
 CODE MOVE
4436 , 443A , 9307 , 2410 , 960A , 2C09 , 570A ,
5706 , 831A , 8316 , 4AE6 , 0 , 8317 , 23FA , 3C05 ,
4AF6 , 0 , 5316 , 8317 , 23FB , 4437 , 4F00 ,
END-CODE
---->
\ <><>
