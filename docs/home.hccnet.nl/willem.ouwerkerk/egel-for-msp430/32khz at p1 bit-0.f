\ For noForth C&V 200202: Test whether 32 KHz crystal works.
\ Information about the built-in capacitators for the 32kHz xtal,
\ see SLAU144J.PDF page 274 and beyond.

\ Test if 32KHz xt on LFXT1 works, gives 32kHz on P1.0
: TEST32KHZ ( -- )
    00 57 c!        \ BCSCTL1  Select LFXT1CLK
    0C 53 c!        \ BCSCTL3  12pF on 32KHz XT
    01 26 *bis      \ P1SEL    Output LFXT1 on P1.0
    01 41 *bic      \ P1SEL2
    01 22 *bis      \ P1DIR
    ;

test32khz

\ End
