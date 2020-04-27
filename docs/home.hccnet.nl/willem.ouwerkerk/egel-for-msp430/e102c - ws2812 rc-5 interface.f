(* E102C - For noForth C2553 lp.0, C&V version, WS2812 using RC-5 interface layer
  Forth user command: WS2812
 *)

: gg  green all ;   : rr  red all ;     \ Led shotcuts 
: bb  blue all ;    : ww  white all ;

: ADJUST-COLOR  ( adr color -- adr )    \ 0 = green, 1 = red, 2 = blue
    over + >r  100 ms               \ adr
    begin
        dup >all                    \ adr               - Show color
        rc5key  r@ c@               \ adr key +n        - Get its value
        over 10 = if  5 +  then     \ adr key +n (vol+) - Increase 5
        over 11 = if  5 -  then     \ adr key +n (vol-) - Decrease 5
        over 20 = if  F +  then     \ adr key +n (P+)   - Increase 15
        over 21 = if  F -  then     \ adr key +n (P-)   - Decrease 15
        00 max  FF min  r@ c!       \ adr key           - In range & store
    17 = until                      \ adr (Ok key?)     - Ready
    r> drop ;                       \ adr

: SELECT-COLOR? ( -- color flag )       \ Choose color to adjust
    rainbow  rc5key 
    dup 2C = if  drop  0  gg  true exit  then   \ Green-key
    dup 2B = if  drop  1  rr  true exit  then   \ Red-key
    dup 2E = if  drop  2  bb  true exit  then   \ Blue-key
    drop  -1  false ; \ Every other key = Ready!

: >SET-COLOR    ( adr -- )      \ Adjust colors
    begin
    select-color? while         \ adr n flag
        adjust-color            \ adr
    repeat
    2drop ;

: SET-PRE       ( -- )          \ Set three predefined light colors
    ww  rc5key dup 1 4 within 
    if  1- 'pre >set-color  else  drop  mem>  then ;

: SET-EFFECT    ( -- )          \ Set two effect colors
    ww  rc5key dup 1 3 within 
    if  1- 'effect >set-color  else  drop  mem>  then ;
    
: SET-COLORS    ( -- )          \ Set eight rainbow colors by hand
    ww  rc5key dup 1 9 within 
    if  1- 'color >set-color  else  drop  mem>  then ;

: FACTORY       ( -- )          \ Set default colors
    blue >color0   red >color1  \ Set effect colors
    white    0 'pre >color      \ Set normal light defaults
    7080 70  1 'pre >color
    2050 20  2 'pre >color
    prism  2 'pre 'mem 3 move ; \ Fill color table, set default color
 
: NRKEY         ( -- +n )       rc5key dup 0 0A within 0= if drop 0 then ;
: NR2           ( -- +n )       bb  nrkey 0A *  nrkey + ;   \ 2-digit number
: NR3           ( -- +n )       gg  nrkey 64 *  nr2 + ;     \ 3-digit number
: SET-TIME      ( rc -- )       0F = if  nr3 >time  then ;  \ 13/24
: SET-LEDS      ( rc -- )       0D = if  nr3 >leds  then ;  \ Mute
: SET-DOT       ( rc -- )       22 = if  nr2 >dot   then ;  \ PP

create 'brighter  3 allot   \ Hold brightness step value for each color
create 'bright    3 allot
: CALC          ( -- )      \ Calculate 1/20th brightness value
    3 0 do
        i 'mem + c@  dup 14 /mod  \ Divide by 20
        swap 09 >  abs +    \ Values smaller then 10 is 0
        i 'bright + c!      \ Save 'brighter value
        0A /mod             \ Divide by 10
        swap 04 > abs +     \ Smaller then 5 is 0
        i 'brighter + c!    \ Save 'bright value
    loop ;

: +++           ( -- )      \ Increase brightness big step
    3 0 do
        i 'mem + c@  i 'brighter + c@ +  FF min
    loop
    3 0 do  2 i - 'mem + c! loop  mem> ;

: ---           ( -- )      \ Decrease brightness
    3 0 do
        i 'mem + c@  i 'brighter + c@ -  00 max
    loop
    3 0 do  2 i - 'mem + c!  loop  mem> ;
  
: ++            ( -- )      \ Increase brightness small step
    3 0 do
        i 'mem + c@  i 'bright + c@ +  FF min
    loop
    3 0 do  2 i - 'mem + c! loop  mem> ;

: --            ( -- )      \ Decrease brightness
    3 0 do
        i 'mem + c@  i 'bright + c@ -  00 max
    loop
    3 0 do  2 i - 'mem + c!  loop  mem> ;

: BRIGHTNESS    ( rc -- )       \ Adjust brightness
    dup 10 = if  ++   then      \ key +n (vol+) - Increase 1/20
    dup 11 = if  --   then      \ key +n (vol-) - Decrease 1/20
    dup 20 = if  +++  then      \ key +n (P+)   - Increase 1/10
        21 = if  ---  then ;    \ key +n (P-)   - Decrease 1/10

: BACKGROUND    ( -- )      'acc  0 'effect  3 move ;
: DOTCOLOR      ( -- )      'acc  1 'effect  3 move ;

: EFFECTS       ( rc -- )       \ Activate effect
    dup 0=   if  background then    \ 00  - Use current light as background
    dup 38 = if  dotcolor   then    \ []> - Current color is dot color
    dup 04 = if  volume     then    \ 04  - Volume like
    dup 05 = if  bounce     then    \ 05  - Bouncing ball
    dup 06 = if  mshift     then    \ 06  - Shift color1 dot at color0   
    dup 07 = if  rainbow    then    \ 07  - Set rainbow colors
    dup 08 = if  <rotate    then    \ 08  - Rotate left
        09 = if  rotate>    then ;  \ 09  - Rotate right

: ON/OFF        ( -- )          \ Leds on/off
    'acc color> or              \ Leds are on?
    if  black all  else  mem> calc  then ;

: PRE           ( rc -- )       \ Set leds to predefined value
    dup 4 1 within if  drop exit  then
    dup 1 = if  drop  0 'pre  else  \ 01
    dup 2 = if  drop  1 'pre  else  \ 02
        3 = if  2 'pre        then  \ 03
            then  then
   'mem 3 move  mem> calc ;

: CHANGE        ( rc -- )       \ Change default value's
    dup 29 = if  drop set-pre exit     then \ A-key
    dup 2A = if  drop set-effect exit  then \ B-key
    dup 3F = if  drop set-colors exit  then \ C-key
        3C = if  factory  then ;            \ E-key

: COLORS        ( rc -- )       \ Set primary colors
    dup 30 2B within if  drop exit  then
    dup 2B = if  red all        then    \ Red-key
    dup 2C = if  green all      then    \ Green-key
    dup 2D = if  8080 00 all    then    \ Yellow-key
    dup 2E = if  blue all       then    \ Blue-key
        2F = if  white all      then    \ White-key
    'acc 'mem 3 move  calc ;    \ Store also in 'MEM

: >WS2812       ( rc -- )       \ RC-5 remote control interface for WS2812
    dup 0C = if  on/off  then   \ (|) On/off key
    dup colors                  \ Color keys...
    dup change                  \ A to E keys
    dup pre                     \ 1-2-3 keys
    dup effects                 \ 4-5-6-7-8-9 keys
    dup brightness              \ Vol+/Vol- P+/P- keys
    dup set-dot                 \ PP - Set dot 2-digits
    dup set-time                \ 13/24 - Set wait 3-digits
    set-leds ;                  \ Mute - Set number of connected leds 3-digits

: WS2812            ( -- )      \ Control a lamp using RC-5
    led-setup  rc-on
    rainbow  100 ms  black all  \ Show startup 
    begin
        rc5key >ws2812          \ RC-5 key received?
    key? until  rc-off ;        \ Ready

' ws2812  to app
shield REMOTE\  freeze

\ End
