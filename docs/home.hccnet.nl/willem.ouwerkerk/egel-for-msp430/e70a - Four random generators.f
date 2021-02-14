\ e70a - J.J. Hoekstra - (c) 2020 for this implementation - can be used freely at own risk

\ Brodie generator (LCG): originally published by Thomson & Rotenberg
\   also see: 'Starting Forth' by Leo Brodie
\ Knuth generator : published by D. Knuth in: The Art of Computer Programming Vol. 2 - 1981
\   also see: Forth Dimensions VIII-3 page 31
\ LFSR generator: originally published by Tausworthe, here in Galois configuration
\ Marsaglia generator: published by Prof. G. Marsaglia in 2003

\ The Brodie generator can be seeded with any number
\ The Knuth generator is seeded by RNDMINIT - see below
\ The LFRS generator must be seeded with a non-zero number
\ The Marsaglia generator must be seeded with at least 1 non-zero number

\ These generators are all light-weight, use only in non-critical applications
\ All times mentioned are the time needed to generate 1 milion random numbers




\ ** CHOOSE routine ****************************
\ CHOOSE    ( u1 -- u2 )
\ CHOOSE returns random integer in range 0 <= u2 < u1. )
\ combine with of the random generators below
\ **********************************************

: CHOOSE ( u1 - u2 ) random um* nip ;



\ ** Brodie generator **************************
\ **********************************************
decimal
value RND 23 to rnd                 \ any number allowed as seed
: RANDOM    ( -- u )                   \ 11s
    rnd 31421 * 6927 + dup to rnd ;




\ ** Knuth generator ***************************
\ uses RANDOM of Brodie and shuffles the results in a 33 element table
\ call RANDINIT once to set up the generator
\ **********************************************
decimal
create RANDARRAY 33 cells allot
: RANDINIT  ( -- )
    33 0 do random randarray i cells + ! loop ;
: SHRANDOM  ( -- u )                \ 30s
    randarray 32 cells + dup @
    32 um* nip cells
    randarray + dup @ random rot !
    dup rot ! ;




\ ** LFSR generator ****************************
\ known as Linear Feedback Shift Register -> LFSR
\ here in Galois configuration
\ take care: the lower bits are not very random
\ **********************************************
hex
value RANDL 3E9 to randl            \ any non-zero number allowed as seed

: RANDOM    ( -- u )                \ 14s
    randl dup 1 and                 \ test bit 0 - if 1 -> toggle bits
    if 1 rshift B400 xor            \ taps at position 16, 14, 13, 11
    else 1 rshift
    then dup to randl ;


\ ** LFSR in assembler *************************
hex
value RANDL 3E9 to randl            \ any non-zero number allowed as seed

code RANDOM ( -- u )                \ 4s - fastest generator in this document
    tos sp -) mov                   \ Save TOS
    adr randl & tos mov             \ Get RANDL to TOS
    tos day mov                     \ Save copy
    #1 sr bic  tos rrc              \ Left shift RANDL
    #1 day bit  cs? if,             \ Test bit 0 of RANDL
        B400 # tos bix              \ When set XOR taps 16, 14, 13, 11
    then,
    tos adr randl & mov             \ Save in RANDL
    next
end-code


\ ** LFSR in comma-code ************************
hex
value RANDL 3E9 to randl

code RANDOM     ( -- u )
8324 ,  4784 ,     0 ,  4217 , adr randl ,  4708 ,  C312 ,  1007 ,
B318 ,  2802 ,  E037 ,  B400 , 4782 ,  adr randl ,  next
end-code




\ ** Marsaglia generator ***********************
\ generator with good quality and normally distributed random numbers
\ 32 bit state -> 2^32-1 long cycle
\ The shift factors are critical, only use:
\       6, 7, 13    or  7, 9, 8 ( used below )
\   or  7, 9, 13    or  9, 7, 13
\ **********************************************
value SEED0 1 to seed0              \ at least one of the seeds must be seeded with a non-zero number
value SEED1 0 to seed1

: RANDOM    ( -- u )                \ 28s
    seed0 seed1 to seed0            \ put seed0 on stack and move value of seed1 to seed0
    dup 7 lshift xor                \ see comments above for the shift-factors
    dup 9 rshift xor
    dup 8 lshift xor
    dup seed1 xor to seed1 ;        \ xor new 16b rando with old value in seed1


\ ** Marsaglia in assembler ********************
decimal
value ASEED0 1 to aseed0            \ at least one of the seeds must be seeded with a non-zero number
value ASEED1 0 to aseed1

code RANDOM ( -- 16b )              \ 6.5s -> 2nd fastest with excellent quality
    tos  sp -) mov                  \ push tos at stack
    adr aseed0 & tos mov            \ put aseed0 in tos
    adr aseed1 & adr aseed0 & mov   \ move aseed1 to aseed0 ( yeahh!! )

    \ 7 lshift and xor with old value
    tos day mov                     \ copy tos to day for later in xor
    #1 sr bic                       \ clear carry
    tos rrc                         \ rol right over carry once
    tos swpb                        \ swap bytes tos = 8 rol
    cs? if,                         \ =jnc
        128 # tos add
    then,
    127 # tos bic                   \ clear lower 7 bits
    day tos bix                     \ bix=xor top with old top

    \ 9 rshift and xor with old value
    tos day mov
    255 # tos bic                   \ clear lower 8 bits
    tos swpb                        \ do a 8 rshift
    #1 sr bic                       \ clear carry
    tos rrc                         \ rol right over carry once
    day tos bix                     \ xor top with old top

    \ 8 lshift and xor with old value
    tos day mov
    tos swpb                        \ 8 rol
    255 # tos bic                   \ clear lower 8 bits -> now a 8 lshift
    day tos bix                     \ xor top with old top

    \ xor tos to aseed1
    adr aseed1 & day mov            \ get value in aseed1 in day
    tos day bix                     \ xor tos to day
    day adr aseed1 & mov            \ and move changed value back to aseed1

    next end-code                   \ back to the real world


\ ** Marsaglia in comma-code *******************
hex
value ASEED0 1 to aseed0            \ init aseed0 with 1
value ASEED1 0 to aseed1            \ init aseed1 with 0

code RANDOM ( -- u )                \ 6.5s
8324 , 4784 ,    0 , 4217 , adr aseed0 , 4292 , adr aseed1 , adr aseed0 ,
4708 , C312 , 1007 , 1087 , 2802 , 5037 ,   80 , C037 ,
  7F , E807 , 4708 , C037 ,   FF , 1087 , C312 , 1007 ,
E807 , 4708 , 1087 , C037 ,   FF , E807 , 4218 , adr aseed1 ,
E708 , 4882 , adr aseed1 ,  next
end-code


\ ** END OF FILE *******************************




