\ Beethoven430, Melody Player for launchpad msp430g2553
\               with noForth C,V (october 2015 or later)
\ Willem Ouwerkerk (hardware basics)
\ Albert Nijhof    (music software)
\ AN -- 25apr2015 -- revision
\ AN -- 24mei2015, 09oct2015 --

\  part I (WO) ---------------------------
v: fresh inside
hex     \ until part III

(
  Generating frequencies at P2.4 or P2.5 for AN, by WO
  Based on: Sofware by Michael Kalus
  Adapted, simplyfied and debugged to run on noForth, by WO
  Info: http://fortytwoandnow.blogspot.nl/2012/08/msp430g2-timers-and-pwm.html

 MSP hardware labels
       FEDC.BA98.7654.3210   bit-positions
  20 BN 0000,0000,0010,0000   #OUTPUT \ Choose output bit4 or bit5
  C0 BN 0000,0000,1100,0000   #OUT    \ toggle-set output
  234 BN 0000,0010,0011,0100   #PWM    \ TA clear, up/down, SMCLK, no presc.
  192   TA1CCR0    \ Period timing
  196   TA1CCR2    \ Dutycycle
  186   TA1CCTL2   \ Output mode
  180   TA1CTL     \ Compare mode
  02A   P2DIR
  02E   P2SEL
  PERIOD DM 38000 corresponds with 100HZ
)

\ s1 / s2  =  duty cycle / period
value S1
value S2
: SET-PERIOD ( period -- )
  dup   192 ( TA1CCR0 ) !
  s1 s2 */ 1 umax   196 ( TA1CCR2 ) ! ;         \ an 08dec2012

: TONE-OFF ( -- )
  0 180 ( TA1CTL ) !
  20 2E ( P2SEL ) *bic          \ #OUTPUT P2SEL *bic
;
(
 234     BN 0000,0010,0011,0100  #PWM
  TA clear, up/down, SMCLK, no presc.
)
: TONE-ON  ( period -- )        \ Tone at P2.5
  20 ( #OUTPUT ) 2E ( P2SEL ) *bis      \ Set PWM to output pin
  0 180 ( TA1CTL ) !
  set-period
  C0 186 ( TA1CCTL2 ) !         \ Set output mode
  234 180 ( TA1CTL ) !          \ Activate timer
;

\ prepare interrupt (WO) ---------------------------
\ enable interrupt
code IR ( -- )          D232 , 4F00 , end-code  \ #8 sr bis  next
\ disable interrupt
code NOIR ( -- )        C232 , 4F00 , end-code  \ #8 sr bic  next

: INITIMER   1 0 *bis ( Watchdog int. on )   IR ;

ch % beyond
  0120 constant WDTCTL
  timer on/off
  Clock = 8000000/512  longest interval 4,19 sec.
  : INTERVAL!     ( x -- )    5A02 or 120 ( WDTCTL) ! ;
  Clock = 8000000/8192 longest interval 67,10 sec.
  : INTERVAL!     ( x -- )    5A01 or 120 ( WDTCTL) ! ;
  x=18  go:      5A19 |or| 5A1A  120 ( WDTCTL) !
  x=90  stop:    5A91 |or| 5A92  120 ( WDTCTL) !
%

\ part II (AN) --------------------------------------
\ an -- 23dec2012 -- timer & interrupt routine

hex value TIME
: TIMER ( time -- )
  to time
  5A19 ( go ) 120 ( WDTCTL ) ! ;        \ timer starts now!

(       TIR
  interrupt routine for timer, uses value TIME
  TIME 0<>  --> count down
  TIME 0=   --> timer-off
)
CODE TIR ( -- )
  9382 , ADR TIME ,     \ #0 ADR TIME & cmp
  2402 ,                \ <>? if,
  8392 , ADR TIME ,     \ #1 ADR TIME & sub
  2003 ,                \ then, =? if,
  40B2 , 5A91 ,  120 ,  \ 5A91 ( stop ) # 120 ( WDTCTL ) & mov
  1300 ,                \ then, reti
  END-CODE

\ part III the music language (AN) ----------------------
decimal

\ ----- rhythm
 value TIQ      \ the unit of time (in ms)
 value STAC     \ 0 ..7, x/8 = mute part of a tone
 value MUTE     \ MUTE = TIQ * (STAC / 8)
 value SOUND    \ SOUND = TIQ - MUTE
 value DURA     \ DURA * TIQ = duration in ms
 value SHOW?    \ output to screen?

\ blurr rhythm: moet nog eenvoudiger.....
 value NN
 value XFI
 value XF       \ in [0,15]
: !XFI ( adr -- )       \ generate a new XFI
  XFI - count + NN + 5 mod 2 -
  ?dup if XFI + XF min XF negate max else XFI 2/
  then  to XFI incr NN  ;
: XFI+ ( n -- n+ ) dup XFI * 2/ 2/ 2/ 2/ s>d - 2/ + ;

: >STAC ( x -- )   \ [0,7]
  7 and to STAC
  TIQ 8 STAC - * 3 rshift 1 max to SOUND
  TIQ SOUND - to MUTE ;

: >DURA ( adr -- adr+ ) \ read inline number [1,255]
  0 >r
  begin count show? if dup emit then
        ch 0 - r> 10 * + >r
        dup c@ ch : ch 0 within
  until r> hx FF00 over and ?abort  to DURA ;

\ ----- tones
create WHITES
  11 c, 13 c, 2 c,      \ A  B  C
   4 c,  6 c, 7 c, 9 c, \ D  E  F  G

create PERIODS          \ octave= ( x - x/256 ) / 2  )
64982 , 61355 , 57930 , \ @B  B   C
54697 , 51644 , 48761 , \ #C  D  @E
46039 , 43470 , 41043 , \ E   F  #F
38752 , 36589 , 34545 , \ G  #G   A

value SD        \ real MUTE time in ms

: TIMING ( -- ) \ wait until actual tone or rest is finished.
  begin begin time 0= until
        SD ?dup while tone-off timer
        0 to SD
  repeat ;

: REST ( -- )           \ start a rest
  DURA TIQ XFI+ *  TIMING  tone-off timer ;

 value @#
 value OCTAVE
 value HIGHER

: NOTE# ( char -- nr )  \ [0,85]
  ch A -  WHITES + c@
  @# +  OCTAVE +  HIGHER +
  0 to @# ;
: >PERIOD ( nr -- period )
  dup 12 < if space ch * emit dup . then        \ ***
  12 /mod
  >r cells PERIODS + @
  r> 0 ?do dup 8 rshift - 1 rshift loop \ with octave stretch
;
: TONE ( period -- )    \ start a tone
  DURA SOUND XFI+ * swap
  TIMING  tone-on
  timer
  DURA MUTE XFI+ * to SD ;

\ ----- code interpreter: PLAY and PP ----------------------
: 1AV ( x adr -- x adr )        \ prima volta, skip while repeating
   over ?exit true swap ch > scan nip ;
: !DUTY DURA 10 /mod 1 max swap 1 max over to S1 + to s2 ;
 value IDLE?
: SHOW 0 to IDLE?
       SHOW? if count emit exit then 1+ ;
: CR?  SHOW? if cr then ;
: SPACE? SHOW? if space then ;

: NEED ( ccc -- ) bl-word find nip 0= ?exit ch ; beyond ;
\ Continue after ";" when ccc already exists.

need STOP?      \ Load STOP? only when it does not exist.
: STOP? ( -- true/false ) [ 2drop ]
    key? dup 0= ?EXIT
    drop key  bl over =
    if drop
        ahead [ reveal : STOPPER [ 2>r ]
        then key
    then hx 1B over = ?abort
    bl <> [ 2r> ] ;

\ play a tune in ROM
: PLAY ( adr -- ) 0 to sd 0 to time
   true hx 2A ( p2dir) !
   0 to OCTAVE
   0 to @#
   XF 15 umin   dup to XF   XFI umin to XFI
   ." higher=" higher . ." xf=" xf .
   s1 0 .r ." /" s2 . cr
 begin    true to IDLE?
   ch S over c@ = if SHOW space? !DUTY then
   ch $ over c@ = if SHOW space? !DUTY S2 S1 - to S1 then
   ch T over c@ = if SHOW space? DURA to TIQ STAC >STAC then
   ch - over c@ = if SHOW 0 >STAC then
   ch . over c@ = if SHOW space? 4 >STAC then
   dup c@ ch U ch [ within if SHOW 1- count ch T - 3 over < - >STAC then
   dup c@ ch 1 ch : within if >DURA 0 to IDLE? space? then
   ch ' over c@ = if SHOW 12 +to OCTAVE then
   ch , over c@ = if SHOW -12 +to OCTAVE then
   ch # over c@ = if SHOW incr @# then
   ch @ over c@ = if SHOW true +to @# then
   dup c@ ch A ch H within if dup c@ NOTE# >PERIOD TONE SHOW dup !XFI then
   ch R over c@ = if SHOW REST dup !XFI then
   ch | over c@ = if cr? SHOW then
   ch < over c@ = if cr? SHOW 0 swap dup then
   ch : over c@ = if SHOW 0 to OCTAVE then
   ch ^ over c@ = if cr? SHOW 1AV then
   ch > over c@ = if cr? SHOW over if swap then nip then
   ch ; over c@ = if TIMING SHOW cr drop exit then
   IDLE? stop? or
 until SHOW 1- cr u. timing tone-off true ?abort ;

\ ----- compile (define) a tune in ROM ----------------
: DOTUNE: does> play ;
: TUNE: create dotune:
   begin bl-word count
         2dup upper
         over c@                \ adr count first-ch
         dup ch ; <>
   while >r
        dup 1 =
        if   ch \ r@ =  if postpone \   else            \ forth comment \
             ch ( r@ =  if postpone (   else            \ forth comment (
             r@ c,                      then then       \ compile character
        else ch \ r@ =   if   ch | c,   else            \ bar number
             ch ( r@ =   if             else            \ skip string
             2dup m,                    then then       \ compile string
        then
        rdrop 2drop
   repeat c, align 2drop ;

\ interactive playing
: PP ch ; parse over swap upper play ; \ Parse and Play
: INITUNE ( -- )   \ initiation
  1 to s1 2 to s2
  0 to STAC   0 to HIGHER
  0 to TIME
  2 to XF   32 dup to DURA to TIQ   initimer  ;

hex
['] TIR >body FFF4 vec!         \ Install interrupt vector
\ FFDE FFF4 vec!                \ Remove interrupt vector
' initune to app
decimal
v: fresh
INITUNE shield TUNE\
FREEZE
\ <><>
