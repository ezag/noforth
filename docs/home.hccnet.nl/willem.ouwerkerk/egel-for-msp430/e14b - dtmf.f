(* E14B - For noForth C&V 200202: DTMF frequency output using
  timer-A0 & timer-A1. ouputs are P1.6 and P2.1
  Frequency range of both outputs is 61 Hz to 39000 Hz 

  Port-1.6 must be wired to a speaker and ground, P2.1 too. 
  The pinlayout can be found in the hardwaredoc of the launchpad.
  The user words are:  >DTMF  WILLEMO  FORTHGG

\   DTMF keypad frequencies
\   freq0   |   1209 Hz 1336 Hz 1477 Hz 1633 Hz  (freq1)
\   0697 Hz |     1       2       3       A
\   0770 Hz |     4       5       6       B
\   0852 Hz |     7       8       9       C
\   0941 Hz |     *       0       #       D

    FEDCBA9876543210 bit-numbers
 BN 0000000001000000 = 0040 - Select P1.6
 BN 0000000000000010 = 0002 - Select P2.1
 BN 0000000011100000 = 00E0 - toggle-set output
 BN 0000001001010100 = 0254 - TA clear, up, SMCLK, presc = /2

Adresses for Timer-A0
 160 = TA0CTL       - Timer A0 control
 164 = TA0CCTL1     - Timer A0 Comp/Capt. control 0
 172 = TA0CCR0      - Timer A0 Comp/Capt. 0
 174 = TA0CCR1      - PBM at P1.2, P1.6 or P2.6
Adresses for Timer-A1
 180 = TA1CTL       - Timer A1 control
 184 = TA1CCTL1     - Timer A1 Comp/Capt. control 0
 192 = TA1CCR0      - Timer A1 Comp/Capt. 0
 194 = TA1CCR1      - PBM at P2.1 or P2.2
\ P1
 021 = P1OUT        - Port 1 output
 022 = P1DIR        -        direction
 026 = P1SEL        -        selection
\ P2
 029 = P2OUT        - Port 2 output
 02A = P2DIR        -        direction
 02E = P2SEL        -        selection
 *)

hex
: STOP0         ( -- )      0 160 ! ;   \ TA0CTL
: STOP1         ( -- )      0 180 ! ;   \ TA1CTL
: PERIOD0       ( p -- )    dup 1 rshift 174 !  172 ! ; \ TA0CCR1, TA0CCR0 Set tone with
: PERIOD1       ( p -- )    dup 1 rshift 194 !  192 ! ; \ TA1CCR1, TA1CCR0 50% dutycycle
: -TONE0        ( -- )      stop0  40 26 *bic ; \ P1SEL  Tone off
: -TONE1        ( -- )      stop1  2 2E *bic ;  \ P2SEL  Tone off

: TONE0         ( period -- )   \ Tone at P1.6
    stop0  40 22 *bis           \ P1DIR  
    40 26 *bis  period0         \ P1SEL
    E0 164 !  254 160 ! ;       \ TA0CCTL1, TA0CTL 

: TONE1         ( period -- )   \ Tone at P2.1
    stop1  2 2A *bis            \ P2DIR  
    2 2E *bis  period1          \ P2SEL
    E0 184 !  254 180 ! ;       \ TA1CCTL1, TA1CTL 

\   DTMF keypad frequencies
\   freq0   |   1209 Hz 1336 Hz 1477 Hz 1633 Hz  (freq1)
\   0697 Hz |     1       2       3       A
\   0770 Hz |     4       5       6       B
\   0852 Hz |     7       8       9       C
\   0941 Hz |     *       0       #       D
decimal
create FREQ0  05739 , 05195 , 04695 , 04251 ,   \ Period time of DTMF freq.
create FREQ1  03309 , 02994 , 02708 , 02449 ,

value wait  80 to wait  hex                     \ Tone length
: SOUND     ( adr -- )                          \ Sound DTMF tones
    c@ dup F and 2* freq1 + @ tone1             \ Set freq. from low nibble
    4 rshift F and 2* freq0 + @ tone0           \ Set freq. from high nibble
    wait ms  -tone1 -tone0 ;                    \ Hold a while and silence

\ Each nibble stands for one of four frequencies
\ The high nibble is frequency-0, the low niblle frequency-1
create 'DTMF    00 c, 01 c, 02 c, 03 c,         \ Tone combinations
                10 c, 11 c, 12 c, 13 c, 
                20 c, 21 c, 22 c, 23 c, 
                30 c, 31 c, 32 c, 33 c, 

create 'CHARS   ch 1 c, ch 2 c, ch 3 c, ch A c, \ Valid DTMF digits
                ch 4 c, ch 5 c, ch 6 c, ch B c,
                ch 7 c, ch 8 c, ch 9 c, ch C c,
                ch * c, ch 0 c, ch # c, ch D c,

: DTMF      ( c -- )        \ Sound one valid DTMF digit
    10 0 do
        dup i 'chars + c@ =
        if  drop  i 'dtmf + sound  unloop exit  then
    loop  drop ;

: >DTMF     ( addr u -- )   \ Sound one DTMF string
    bounds ?do  i c@ dtmf  loop ;

: WILLEMO   s" 026-4431305" >dtmf ;
: FORTHGG   s" 071-5216531" >dtmf ;

shield DTMF\  freeze

\ End
