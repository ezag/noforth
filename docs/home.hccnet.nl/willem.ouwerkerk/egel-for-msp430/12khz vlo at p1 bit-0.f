\ For noForth C&V2553 lp.0, test if 12KHz VLO is working.

\ Test if 12KHz VLO works, gives about 12kHz on P1.0
: TEST12KHZ ( -- )
    40 57 c!        \ BCSCTL1  Select LFXT1CLK
    20 53 c!        \ BCSCTL3  12KHz VLOCLK
    01 26 *bis      \ P1SEL    Output LFXT1 on P1.0
    01 41 *bic      \ P1SEL2
    01 22 *bis      \ P1DIR
    ;

test12khz

\ End