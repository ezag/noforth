(* E90 - For noForth C&V149 xx.p, hardware multiply on MSP430F149.

(  Addresses and Labels  
    130         MPY
    132         MPYS
    138         OP2
    13A         RESSLO
    13C         RESHI

 More info on these multiply routines, see page 91 of SLAU049A.PDF
 *)

code DU*S ( ulo uhi u -- ulo2 uhi2 )
\ u * uhi
    tos 130 & mov       \ MPY    1st operand (u)
    sp )+ 138 & mov     \ OP2    2nd operand, start multiply (uhi)
    13A & tos mov       \ RESLO  low result (uhi2)
\ u * ulo
    sp ) 138 & mov      \ OP2    2nd operand, start multiply (ulo)
    13A & sp ) mov      \ RESLO  low result (ulo2)
    13C & tos add       \ RESHI  high result (uhi2+)
    next end-code

code UM*    ( u1 u2 -- udl udh ) \ 16*16=32
    tos 130 & mov       \ MPY    Load 1st operand
    sp ) 138 & mov      \ OP2    Load 2nd operand, start multiply
    13A & sp ) mov      \ RESLO  Read low result
    13C & tos mov       \ RESHI  Read high result
    next
end-code

code M*     ( n1 n2 -- dl dh )   \ 16*16=32
    tos 132 & mov       \ MPYS   Load 1st operand
    sp ) 138 & mov      \ OP2    Load 2nd operand, start multiply
    13A & sp ) mov      \ RESLO  Read low result
    13C & tos mov       \ RESHI  Read high result
    next
end-code

code *      ( n1 n2 -- n3 )   \ 8*8=16
    tos 132 & mov       \ MPYS   Load 1st operand
    sp )+ 138 & mov     \ OP2    Load 2nd operand, start multiply
    13A & tos mov       \ RESLO  Read low result
    next
end-code

\ Examples:
\ @)10 10 * . 100  OK.0
\ @)-10 10 * . -100  OK.0
\ @)-10 10 M* D. -100  OK.0
\ @)-10 10 UM* D. FFF00  OK.0
\ @)

freeze

\ End
