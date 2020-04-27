(* E44UA - For noForth C2553 lp.0, C&V version: SPI master adapted for WS2812

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

  0020 = P1IN      - Input register
  0021 = P1OUT     - Output register
  0022 = P1DIR     - Direction register
  0026 = P1SEL     - 0C0
  0027 = P1REN     - Resistance on/off
  0041 = P1SEL2    - 0C0
  0068 = UCB0CTL0  - 00F
  0069 = UCB0CTL1  - 081
  006A = UCB0BR0   - 0A0
  006B = UCB0BR1   - 000
  006C = UCB0CIE   - USCI interrupt enable
  006D = UCB0STAT  - USCI status
  006E = UCB0RXBUF - RX Data
  006F = UCB0TXBUF - TX Data
  0118 = UCB0I2C0A - NC
  011A = UCB0I2CSA - 042
  0001 = IE2       - 000
  0003 = IFG2      - 008 = TX ready, 004 = RX ready

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
    #LEDS   - Number of connected leds, from 2 to 1000
    WAIT    - Wait time in millisec. in between actions

    For MSHIFT demo program:
    #DOT    - Dotsize in pixels, from 1 to #LEDS - 1

Forth user commands:

LED-SETUP ( -- )  - Set DCO to 16MHz & init RS232, MS, Flash & SPI output
DEMO ( - )        - Initialise all and flashing primary colors
ALL  ( dc - )     - Set all leds to the color from the stack
BLACK ( - dc )    - Some color examples
WHITE ( - dc )
GREEN ( - dc )
RED ( - dc )
BLUE ( - dc )
S1 S2 S3 ( - )    - Three colorfull shiftregister examples (1SHIFT)
S4 S5 ( - )       - Two multidot shiftregister examples (MSHIFT)
>LEDS ( +n -- )   - Set number of connected WS2812 leds (#LEDS)
>DOT  ( +n - )    - Set dot length in led pixels (#DOT)
>TIME ( u - )     - Set dot hold time (WAIT)
>COLOR0 ( dc -- ) - Set background color
>COLOR1 ( dc -- ) - Set foreground color
>COLORS ( c c - ) - Set fore- and background color
RAINBOW ( - )     - Set a rainbow divided over all leds
ICY ( - )         - Ice cold light
WARM ( - )        - Cosy light
HOT ( - )         - Candle light
MOOD ( - )        - Use as: ICY MOOD
 *)

code INT-OFF    #8 sr bic  next  end-code

\ Note! Change the DCO frequency of noForth to 16 MHz using: Patch 2553.f

value WAIT          \ Shift wait time
value #LEDS         \ Number of connected leds
value #DOT          \ Dot size
: >LEDS     ( +n -- )       to #leds ;
: >DOT      ( dotsize -- )  #leds umin  to #dot ;
: >TIME     ( ms -- )       to wait ;

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
    04 >dot         \ Dot size for running light
    10 >leds ;      \ Number of connected WS2812 leds

\ The databyte for WS2812 must be present in the register MOON !
\ High-bit: H=625ns, L=375ns, Low-bit: H=375ns, L=625ns
routine ONEBYTE ( -- adr )
    moon swpb                   \ Low databyte to high byte
    #8 day mov                  \ One byte = 8 bits
    begin,
        begin,  #8 003 & .b bit cs? until, \ IFG2  Pulse ready?
        moon moon add           \ Next bit to carry
        cs? if,                 \ Bit high?
            1F # 06F & .b mov   \ UCB0TXBUF  Yes, make high pulse
        else,                   \ No,
            moon moon mov       \ Stretch low off time
            moon moon mov
            07 # 06F & .b mov   \ UCB0TXBUF  Make low pulse
        then,
        #1 day sub              \ Count bits
    =? until,
    rp )+ pc mov  ( ret )
end-code

create 'COLOR0  3 allot \ Green, Red and Blue eight color schemes
create 'COLOR1  3 allot
create 'COLOR2  3 allot
create 'COLOR3  3 allot
create 'COLOR4  3 allot
create 'COLOR5  3 allot
create 'COLOR6  3 allot
create 'COLOR7  3 allot

routine LED)    ( -- adr )  \ Sent color data to one led
    w )+  moon .b mov
    onebyte # call          \ Green
    w )+  moon .b mov
    onebyte # call          \ Red
    w )+  moon .b mov
    onebyte # call          \ Blue
    rp )+ pc mov  ( Ret )
end-code

code COLOR0   ( u -- )      \ Send color0 data to u leds
    tos sun mov
    sp )+ tos mov
    begin,
        #0 sun cmp
    <>? while,
        'color0 #  w mov    \ Used color table
        led) # call         \ Address one led
        #1 sun sub          \ Count number of leds
    repeat,
    next
end-code

code COLOR1    ( u -- )     \ Send color1 data to u leds
    tos sun mov
    sp )+ tos mov
    begin,
        #0 sun cmp
    <>? while,
        'color1 # w mov
        led) # call
        #1 sun sub
    repeat,
    next
end-code

value D1  value D2          \ Dot part1 & 2 pixels, etc.
value B1  value B2          \ Background part1 & 2 pixels, etc.
code COLOR    ( adr -- )    \ Send color data from adr to d1 leds
    tos xx mov              \ Color array to xx
    sp )+ tos mov
    adr d1 &  sun mov       \ D1 contains the number of leds
    begin,
        #0 sun cmp
    <>? while,
        xx w mov
        led) # call
        #1 sun sub
    repeat,
    next
end-code

: >COLOR        ( dc adr -- )   \ Store color dc to adr
    >r  ff and r@ 2 + c!        \ Blue
    dup ff and r@ 1+ c!         \ Red
    ><  ff and r> c! ;          \ Green

: COLOR>    ( adr -- dc )   count >< >r  count r> or  swap c@ ;
: >COLOR0   ( dc -- )       'color0 >color ; \ Background
: >COLOR1   ( dc -- )       'color1 >color ; \ Foreground
: >COLORS   ( dc0 dc1 -- )  >color1  >color0 ;
: ALL       ( dc -- )       >color0 #leds color0 ;  \ Same color to all leds

: BLACK         ( -- dc )       0000 0000 ;         \ Six basic colors
: WHITE         ( -- dc )       ffff 00ff ;
: GREEN         ( -- dc )       ff00 0000 ;
: RED           ( -- dc )       00ff 0000 ;
: BLUE          ( -- dc )       0000 00ff ;

: DEMO          ( +n -- )       \ Flash three basic colors
    led-setup  >time
    begin
        red all    wait ms
        green all  wait ms
        blue all   wait ms
    key? until
    black all ;


\ Simple one dot shiftregister

: 1LINE         ( pos -- )
    #leds over - 1-  to b1
    ( pos ) color0  1 color1  b1 color0 ;

: 1SHIFT        ( -- )          \ One dot shiftregister
    begin
        #leds 0 do  i 1line  wait ms  loop
    key? until
    black all ;

: S1    ( -- )  blue  red   >colors  1shift ; \ Demo's
: S2    ( -- )  green black >colors  1shift ;
: S3    ( -- )  red   white >colors  1shift ;


\ Multi dot shiftregister

\ pos = 0              -> d2=0  b2=0 or d1=0 b1=0  - d1 d1 b1 b1 b1 b1 b1 b1
\ #leds-#dot < pos > 0 -> d1=0                     - b1 b1 b1 d1 d1 b2 b2 b2
\ pos > #leds-#dot     -> b2=0                     - d1 b1 b1 b1 b1 b1 b1 d2
: MLINE         ( pos -- )          \ Display one full line
    #leds  over #dot +  >           \ Cursor dot one line?
    if  0 to d1  #dot to d2         \ Yes, build pattern
        ( pos ) to b1
        #leds b1 - d2 - to b2
    else                            \ No, split cursor pattern
        0 to b2  #leds #dot - to b1 \ Background is one piece!
        #leds swap - to d2          \ Start dot
        #dot d2 - to d1             \ End dot
    then
    d1 color1  b1 color0  d2 color1  b2 color0 ;

: MSHIFT        ( -- )              \ Multi dot shift
    begin
        #leds 0 do  i mline  wait ms  loop
    key? until  black all ;

: S4    ( -- )  blue green >colors  mshift ;    \ Demo's
: S5    ( -- )  blue red   >colors  mshift ;


: PRISM         ( -- )              \ Put a rainbow divided over all leds
    00C0 00 >color0                 \ Red
    4080 00 >color1                 \ Orange
    6050 00 'color2 >color          \ Yellow
    C000 00 'color3 >color          \ Green
    3000 70 'color4 >color          \ Blue-green
    0000 E0 'color5 >color          \ Blue
    0030 80 'color6 >color          \ Purple
    5050 60 'color7 >color ;        \ White

: PARTY         ( -- )              \ Set leds to six different colors
    #leds 8 / to d1
    'color0 color  'color1 color  'color2 color
    'color3 color  'color4 color  'color5 color
    'color6 color  'color7 color ;

: RAINBOW       ( -- )      prism party ;     \ Demo


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
