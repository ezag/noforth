(*  E44UB - For noForth C2553 lp.0, C&V version: SPI master adapted for WS2812
    This is a more flexible version for longer WS2812 strips. These may be
    devided in virtual strips called a field. Fields can be set using >FIELD
    and may be from 1 to the number of leds connected.

    This code needs 16 MHz DCO!
    Note! Change the DCO frequency for noForth to 16 MHz using: Patch 2553.f

                     MSP430G2xx3
                  -----------------
              /|\|              XIN|-
               | |                 |
               --|RST          XOUT|-
                 |                 |
                 |             P1.7|-> Data Out to WS2812 (UCB0SIMO)
                 |                 |

  This routine is made for an 16MHz clock! And the output is P1.7
  The pulse timing is now a little over the maximum frequency of 800kHz!
  The running light demo is just within WS2812 parameters.
  The low part of the bit-pulses around the dot, are 4700 nanosec.

   Data on WS2812 timing now:
    High bit: 800ns high, 400ns low  /""\__/
    Low bit : 400ns high, 800ns low  /"\___/
    Reset   : 10000ns low
    The low part of the bits may be longer,
    but no longer then 5000ns!!!
    Note that each led needs 24-bits!!

    For this software in general:
    #LEDS   - Number of connected leds, from 8 to 1000
    #FIELD  - Number of leds in a field from 8 to 1000
              A field is repeated over the all the connected leds
    WAIT    - Wait time in millisec. in between actions

    For MSHIFT effect program:
    #DOT    - Dotsize in pixels, from 0 to #FIELD

Forth user commands:

LED-SETUP ( -- )  - Set DCO to 16MHz & init RS232, MS, Flash & SPI output
ALL  ( dc - )     - Set all leds to 'ACC using the color from the stack
BLACK ( - dc )    - Some color examples
WHITE ( - dc )
GREEN ( - dc )
RED ( - dc )
BLUE ( - dc )
>COLOR0 ( dc -- ) - Set background color
>COLOR1 ( dc -- ) - Set foreground color
>LEDS ( +n -- )   - Set number of connected WS2812 leds (#LEDS)
>FIELD ( +n -- )  - Set number of leds in a virtual #FIELD unit
>DOT  ( +n - )    - Set dot length in led pixels (#DOT)
>TIME ( u - )     - Set dot hold time (WAIT)
MSHIFT ( -- )     - Shift a variable length dot
VOLUME ( - )      - Special effect 1
BOUNCE ( - )      - Special effect 2 bouncing dot
RAINBOW ( - )     - Set a rainbow divided over all leds
<ROTATE ( -- )    - Rotate rainbow left
ROTATE> ( -- )    - Rotate rainbow right
 *)

code INT-OFF    #8 sr bic  next  end-code

\ Note! Change the DCO frequency of noForth to 16 MHz using: Patch 2553.f

value WAIT          \ Shift wait time
value #LEDS         \ Number of connected leds
value #FIELD        \ Divide large led string to smaller virtual units
value #DOT          \ Dot size
: >FIELD    ( +n -- )       #leds umin  to #field ; \ Max. #field is #leds
: >DOT      ( dotsize -- )  #field umin  to #dot ;  \ Max. dot is #field
: >TIME     ( ms -- )       200 umin  to wait ;     \ Max. a half second
: >LEDS     ( +n -- )
    dup to #leds  #field u<     \ Set #LEDS , #LEDS smaller?
    if  #leds >field  then      \ Yes, replace #FIELD by #LEDS
    ;

: LED-SETUP  ( -- )
    01 069 *bis     \ UCB0CTL1  Reset USCI
    80 026 *bis     \ P1SEL     P1.7 is SPI SIMO
    80 041 *bis     \ P1SEL2
    09 068 c!       \ UCB0CTL0  Clk=low, LSB first, 8-bit
    80 069 *bis     \ UCB0CTL1  USCI clock = SMClk
    02 06A !        \ UCB0BR0   Clock is 16Mhz/2 = 8 MHz
    00 06C c!       \ UCB0MCTL  Not used must be zero!
    01 069 *bic     \ UCB0CTL1  Free USCI
    40 >time        \ Wait time for each step
    10 >leds        \ Number of connected WS2812 leds
    10 >field       \ Number of WS2812 leds in a field
    04 >dot ;       \ Dot size for running light

\ The databyte for WS2812 must be present in the register MOON !
\ High-bit: H=625ns, L=375ns, Low-bit: H=375ns, L=625ns
routine ONEBYTE ( -- adr )
    moon swpb                   \ Low databyte to high byte
    #8 day mov                  \ One byte = 8 bits
    begin,
        begin,  #8 003 & .b bit cs? until, \ Pulse ready?
        moon moon add           \ Next bit to carry
        cs? if,                 \ Bit high?
            1F # 06F & .b mov   \ Yes, make high pulse
        else,                   \ No,
            moon moon mov       \ Stretch low off time
            moon moon mov
            07 # 06F & .b mov   \ Make low pulse
        then,
        #1 day sub              \ Count bits
    =? until,
    rp )+ pc mov  ( ret )
end-code

routine LED)    ( -- adr )  \ Sent color data to one led
    w )+  moon .b mov
    onebyte # call          \ Green
    w )+  moon .b mov
    onebyte # call          \ Red
    w )+  moon .b mov
    onebyte # call          \ Blue
    rp )+ pc mov  ( Ret )
end-code

: TABLE create here , 3 * allot ( +n ccc -- )
        does> @  swap 3 * + ;   ( +n -- adr )

create 'MEM 3 allot         \ Current color memory
create 'ACC 3 allot         \ Active color
02 table 'EFFECT            \ Colors for effect routines
03 table 'PRE               \ Current light colors (Three)
08 table 'COLOR             \ Eight color schemes

\ The four main display routines in assembly for speed!
routine COLOR0  ( -- adr )  \ Send color0 data to SUN leds
    begin,
        #0 sun cmp
    <>? while,
        0 'effect #  w mov  \ Used color table
        led) # call         \ Address one led
        #1 sun sub          \ Count number of leds
    repeat,
    rp )+ pc mov  ( Ret )
end-code

routine COLOR1  ( -- adr )  \ Send color1 data to SUN leds
    begin,
        #0 sun cmp
    <>? while,
        1 'effect # w mov
        led) # call
        #1 sun sub
    repeat,
    rp )+ pc mov  ( Ret )
end-code

value D1  value D2          \ Dot part1 & 2 pixels, etc.
value B1  value B2          \ Background part1 & 2 pixels, etc.
routine COLOR   ( -- adr )  \ Send color data from adr in W to D1 leds
    adr d1 &  sun mov       \ D1 contains the number of leds
    w yy mov                \ Remember color array in YY
    begin,
        #0 sun cmp
    <>? while,
        yy w mov            \ Color to W
        led) # call
        #1 sun sub
    repeat,
    rp )+ pc mov  ( Ret )
end-code

code ALL>       ( -- )      \ Send color data from 'ACC to all leds
    adr #leds &  sun mov    \ #LEDS the number of leds to SUN
    begin,
        #0 sun cmp
    <>? while,
        'acc #  w mov       \ Color array to W
        led) # call
        #1 sun sub
    repeat,
    next
end-code

code MLINE)     ( -- )
    adr #leds & xx mov      \ Number of leds used
    begin,                  \ Do one field at a time!
        adr d1 & sun mov    \ Dot color
        color1 # call
        adr b1 & sun mov    \ Background color
        color0 # call
        adr d2 & sun mov    \ Dot color
        color1 # call
        adr b2 & sun mov    \ Background color
        color0 # call
        adr #field & xx sub \ One field done
        #1 xx cmp
    >? until,               \ Ready if xx <= 1
    next
end-code

code PARTY)     ( -- )
    adr #leds & xx mov      \ Number of leds used
    begin,                  \ Do one field at a time!
        0 'color # w mov    \ Start at color data 0
        color # call        \ Send color data 0
        color # call        \ Send color data 1
        color # call        \ Send color data 2
        color # call        \ Send color data 3
        color # call        \ Send color data 4
        color # call        \ Send color data 5
        color # call        \ Send color data 6
        adr d2 &  sun mov   \ Set last leds of a field
        color 4 + # call    \ Send color data 7
        adr #field & xx sub \ One field done
        #1 xx cmp
    >? until,               \ Ready if xx <= 1
    next
end-code

: >COLOR        ( dc adr -- )   \ Store color dc to adr
    >r  ff and r@ 2 + c!        \ Blue
    dup ff and r@ 1+ c!         \ Red
    ><  ff and r> c! ;          \ Green

: COLOR>    ( adr -- dc )   count >< >r  count r> or  swap c@ ;
: >COLOR0   ( dc -- )       0 'effect >color ;  \ Background
: >COLOR1   ( dc -- )       1 'effect >color ;  \ Foreground
: ALL       ( dc -- )       'acc >color all> ;  \ Same color to all leds
: >ALL      ( adr -- )      color> all ;        \ Set all leds from address
: MEM>      ( -- )          'mem >all ;         \ Set all leds from 'MEM ('ACC='MEM)
: BLACK     ( -- dc )       0000 0000 ;         \ Leds on and off
: WHITE     ( -- dc )       4040 0045 ;
: GREEN     ( -- dc )       8000 0000 ;
: RED       ( -- dc )       0080 0000 ;
: BLUE      ( -- dc )       0000 0080 ;

: CSWAP     ( -- )          \ Swap cursor and background color
    0 'effect color>        \ -- dc
    1 'effect  0 'effect  3 move
    1 'effect >color ;      \ --

value END?
: UP/DOWN   ( -- )
    wait  key >r             \ +n        - x1 on top
    r@ ch - = if  5 +    then     \ +n (+) - Increase wait by 5
    r@ ch + = if  5 -    then     \ +n (-) - Decrease wait by 5
    r@ ch 3 = if  1E +   then     \ +n (9) - Increase wait by 30
    r@ ch 9 = if  1E -   then     \ +n (3) - Decrease wait by 30
    r@ ch S = if  cswap  then     \ +n (S) - Swap colors
    r> 1B = if true to end? then  \    (Esc) Ready
    00 max >time ;                \ Not below zero!

\ Key actions:
\ +     - Speed faster
\ -     - Speed slower
\ 9     - Speed much faster
\ 3     - Speed much slower
\ S     - Swap used colors
\ Esc   - Stop current function
: <WAIT>    ( -- )      key? if  up/down  else  wait ms  then ;

\ Multi dot shiftregister

\ pos = 0               -> d2=0  b2=0 or d1=0 b1=0  - d1 d1 b1 b1 b1 b1 b1 b1
\ #field-#dot < pos > 0 -> d1=0                     - b1 b1 b1 d1 d1 b2 b2 b2
\ pos > #field-#dot     -> b2=0                     - d1 b1 b1 b1 b1 b1 b1 d2
: MLINE         ( pos -- )          \ Display one full line
    #field  over #dot +  >          \ Cursor dot one line?
    if  0 to d1  #dot to d2         \ Yes, build pattern
        ( pos ) to b1
        #field b1 - d2 - to b2
    else                            \ No, split cursor pattern
        0 to b2  #field #dot - to b1 \ Background is one piece!
        #field swap - to d2         \ Start dot
        #dot d2 - to d1             \ End dot
    then
    mline) ;

: MSHIFT        ( -- )              \ Multi dot shift
    false to end?
    begin
        #field 0 do  i mline  <wait>  loop
    end? until  all> ;

: VOLUME        ( -- )              \ Rising and shrinking bar
    false to end?  #dot
    begin
        #field 0 do  i >dot  0 mline  <wait>  loop
        0 #field do  i >dot  0 mline  <wait>  -1 +loop
    end? until  >dot  all> ;

: BOUNCE        ( -- )              \ Bouncing dot
    false to end?  #dot
    begin
        #field #dot -  dup 0 ?do  i mline  <wait>  loop
        1 swap ?do  i mline  <wait>  -1 +loop
    end? until  >dot  all> ;

: PRISM         ( -- )              \ Put a rainbow divided over all leds
    00B0 00 0 'color >color         \ Red
    4080 00 1 'color >color         \ Orange
    6050 00 2 'color >color         \ Yellow
    B000 00 3 'color >color         \ Green
    3000 70 4 'color >color         \ Blue-green
    0000 E0 5 'color >color         \ Blue
    0030 80 6 'color >color         \ Purple
    4040 50 7 'color >color ;       \ White

: PARTY         ( -- )              \ Set led fields to eight different colors
    #field 8 /mod to d1  d1 + to d2  party) ;

: RAINBOW       ( -- )      prism party ;     \ Demo

: <ROTATE       ( -- )              \ Rotate colors to left
    false to end?
    begin
        0 'color color>  1 'color  0 'color  15 move
        7 'color >color   <wait>  party
    end? until ;

: ROTATE>       ( -- )              \ Rotate colors to right
    false to end?
    begin
        7 'color color>  0 'color  1 'color  15 move
        0 'color >color  <wait>  party
    end? until ;


\ General color setting by saving color themes
create 'MOOD0  3 allot
: >MOOD ( adr -- )  color> all ;    \ Set all leds to color from adr
: ICY   ( -- )      B0B0 FF 'mood0 >color ;
: WARM  ( -- )      C0FF 80 'mood0 >color ;
: HOT   ( -- )      C0D0 20 'mood0 >color ;
: MOOD  ( -- )      'mood0 >mood ;

' led-setup  to app
shield WS2812\  freeze

\ End
