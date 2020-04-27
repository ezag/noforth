(* E80 - For noForth C&V5739 ex.0, hardware multiply on MSP430FR5739.

   Addresses and Labels  
    4C0         MPY
    4C2         MPYS
    4C8         OP2
    4D2         MPY32H
    4E0         OP2L
    4E2         OP2H
    4E4         RES0
    4E6         RES1
    4CA         RESSLO
    4CC         RESHI

 More info on these multiply routines, see page 364 of SLAU272A.PDF
 *)

code DU*S   ( ud1 u -- ud2 )       \ 32*16=32
    tos 4D0 & mov       \ MPY32L Load operand +n
    #0 4D2 & mov        \ MPY32H Extend to 32-bit with zero
    2 sp x) 4E0 & mov   \ OP2L   Load ud1l
    sp )+ 4E2 & mov     \ OP2H   Pop ud1h, start multiply
    4E4 & sp ) mov      \ RES0   Read result low
    4E6 & tos mov       \ RES1   Read result hi
    next
end-code

code UM*    ( x y -- plo phi )      \ 16*16=32
    tos 4C0 & mov       \ MPY    Load 1st operand
    sp ) 4C8 & mov      \ OP2    Load 2nd operand, start multiply
    4CA & sp ) mov      \ RESLO  Read low result
    4CC & tos mov       \ RESHI  Read high result
    next
end-code

code M*     ( n1 n2 -- dl dh )   \ 16*16=32
    tos 4C2 & mov       \ MPYS   Load 1st operand
    sp ) 4C8 & mov      \ OP2    Load 2nd operand, start multiply
    4CA & sp ) mov      \ RESLO  Read low result
    4CC & tos mov       \ RESHI  Read high result
    next
end-code

code *      ( n1 n2 -- n3 )   \ 8*8=16
    tos 4C2 & mov       \ MPYS   Load 1st operand
    sp )+ 4C8 & mov     \ OP2    Load 2nd operand, start multiply
    4CA & tos mov       \ RESLO  Read low result
    next
end-code

\ Examples:
\ @)10 10 * . 100  OK.0
\ @)-10 10 * . -100  OK.0
\ @)-10 10 M* D. -100  OK.0
\ @)FFFF 10 UM* D. FFFF0  OK.0
\ @)dn 100 FFFF du*s d. FFFF00  OK.0
\ @)

freeze

\ End
