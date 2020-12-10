(* E14A - For noForth C&V 200202: Simple perpetual canon
   music output using timer-A0 & timer-A1. ouputs are P1.6 and P2.1
   Frequency range of both outputs is 61 Hz to 39000 Hz

  Port-1.6 must be wired to a speaker and ground, P2.1 too.
  The red LED at P1.0 flashes short when a note is activated.
  The pinlayout can be found in the hardwaredoc of the launchpad.
  The user words are: HONK  HUNTING  BJ

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
Timer-A1
 180 = TA1CTL       - Timer A1 control
 184 = TA1CCTL1     - Timer A1 Comp/Capt. control 0
 192 = TA1CCR0      - Timer A1 Comp/Capt. 0
 194 = TA1CCR1      - PBM at P2.1 or P2.2
\ P1 & P2
 021 = P1OUT        - Port 1 output
 022 = P1DIR        -        direction
 026 = P1SEL        -        selection
 029 = P2OUT        - Port 2 output
 02A = P2DIR        -        direction
 02E = P2SEL        -        selection
 *)

hex
: RED-ON        ( -- )      1 21 *bis ; \ P1OUT
: RED-OFF       ( -- )      1 21 *bic ; \ P1OUT
: STOP0         ( -- )      0 160 ! ;   \ TA0CTL  Timer A0 off
: STOP1         ( -- )      0 180 ! ;   \ TA1CTL  Timer A1 off
: -TONE0        ( -- )      stop0  40 26 *bic ; \ P1SEL  Tone off
: -TONE1        ( -- )      stop1  2 2E *bic ; \ P2SEL  Tone off

: PERIOD0       ( p -- )        \ Set tone p with 50% dutycycle
    dup 1 rshift 174 ! 172 ! ;  \ TA0CCR1, TA0CCR0
: PERIOD1       ( p -- )        \ Set tone p with 50% dutycycle
    dup 1 rshift 194 ! 192 ! ;  \ TA1CCR1, TA10CCR0

: TONE0         ( period -- )   \ Tone at P1.6
    ?dup if                     \ Only when not zero
        red-on stop0 40 22 *bis \ P1DIR
        40 26 *bis  period0     \ P1SEL
        E0 164 !                \ TA0CCTL1
        254 160 !  red-off      \ TA0CTL  Timer A0 on
    then ;

: TONE1         ( period -- )   \ Tone at P2.1
    ?dup if                     \ Only when not zero
        red-on stop1 2 2A *bis  \ P2DIR
        2 2E *bis  period1      \ P2SEL
        E0 184 !                \ TA1CcTL1
        254 180 !  red-off      \ TA1CTL  Timer A1 on
    then ;

decimal  39800 constant 100HZ
100hz 1 rshift constant 200HZ
: HONK      ( -- )      100hz tone0  200hz tone1  200 ms  -tone0  -tone1 ;


\ The frequencies of all tones are calculated from UT (UT = DO).
\ Rhythm
value TIQ   ( -- u )    \ Timescale in milliseconds, initialise!
value TIQS  ( -- u )    \ Duration in tiqs of the next tone or rest
: Q         ( n -- )    to tiqs ;
: REST      ( -- )      tiqs 0 ?do  tiq ms  loop ;

value COUNTER
: PLAY      ( period1 | period1 period0 -- period1 | )
        incr counter
        counter 1 and if            \ Second note?
            tone0  tone1  rest      \ Yes, play both
            -tone0  -tone1  exit    \ Notes off
        then ;

\ Pitch
value UT)       \ Adjustable base period, initialise!

\ A variant of */ with rounding to the nearest digit
: */ROUND   ( x a b -- q )  
    >r um*  r@ um/mod   \ Save 'b', unsigned */ 
    swap 2*             \ Remainder times two
    r> <                \ Doubled remainder smaller then 'b'
    1+ + ;              \ Convert flag to 0 or 1 & correct result

\ Set a note, defined by two constants. UT) contains the period time
\ The two constants are used two define the actual period time.
\ Actual period time: (period-base * constant1) / constant2
\ Example: ,SOL period time = UT) * 4  / 3, etc.  
: T:        ( u1 u2 ccc -- )
        create c, c,
        does>  ut) swap count swap c@  swap  */round play ;

\ ---------- Natural tuning ----------
4 3   t: ,SOL   \ 1.5000/2
5 4   t: ,LA@   \ 1.6000/2
6 5   t: ,LA    \ 1.6667/2
9 8   t: ,SI@   \ 1.7778/2
16 15 t: ,SI    \ 1.8750/2

1 1   t: UT     \ 1         DO
8 9   t: RE     \ 1.1250
4 5   t: MI     \ 1.2500
3 4   t: FA     \ 1.3333
32 45 t: FA#    \ 1.4063
2 3   t: SOL    \ 1.5000
16 25 t: SOL#   \ 1.5625
3 5   t: LA     \ 1.6667
9 16  t: SI@    \ 1.7778
8 15  t: SI     \ 1.8750

0 1   t: R      \ Rest

\ Valid note base frequencies and period numbers as used by the software
\ The routine INIT keeps these numbers in a valid range
\        \Concert pitch LA   Basetone UT)
\ freq     period               period
\ 1760Hz ->  2273 = LA ->  UT) =  1893
\ 880Hz  ->  4545 = LA ->  UT) =  3788
\ 440Hz  ->  9091 = LA ->  UT) =  7576
\ 220Hz  -> 18182 = LA ->  UT) = 15152
\ 110HZ  -> 36364 = LA ->  UT) = 30303


: INIT      ( -- )      \ Initialise UT) & tiqs in a valid range
    1 22 c!             \ P1DIR  1.0 is a LED output
    ut) 01893 <>  ut) 03788 <>  and         \ UT) not valid?
    ut) 07576 <>  ut) 15152 <>  and and
    ut) 30303 <>  and if 15152 to ut) then  \ Yes, initialise
    tiq 500 10 within if 125 to tiq then ;  \ TIQ valid?

: &         ( -- )   -1 to counter  4 q  r r ; \ Start score

: HUNTING   ( -- )   &  4 q  sol si   re la   ,si sol   re la
                        5 q  fa la   ut sol   ,la fa   ut sol ;

\ Canon: Brother John, Vader Jacob, Frere Jacques, Bruder Jakob.
\ Two notes are allways played together, in short:
\ Start a new score = &
\ Set notelength    = 4 q
\ Play dual note    = fa re
\ Play one note     = mi r
\ Play rest         = r r
: BJOHN        ( -- )
    &  4 q  ut r  re r  mi r  ut r
            ut r  re r  mi r  ut r
            mi ut  fa re  sol mi  r ut
            mi ut  fa re  sol mi  r ut
       2 q  sol mi  la mi  sol fa  fa fa
       4 q  mi sol  ut r
       2 q  sol mi  la mi  sol fa  fa fa
       4 q  mi sol  ut r
       2 q  ut sol  ut la  ,sol sol  ,sol fa
       4 q  ut mi  r ut
       2 q  ut sol  ut la  ,sol sol  ,sol fa
       4 q  ut mi  r ut
            r ut  r ,sol  r ut  r r
            r ut  r ,sol  r ut  r r ;

' init to app  init
shield NOTES\  freeze

\ End
