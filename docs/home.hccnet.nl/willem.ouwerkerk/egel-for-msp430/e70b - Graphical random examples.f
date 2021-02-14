(* E70b - For noForth C&V 200202ff: test random generators on OLED
   based on work by W. Ouwerkerk
   this version: (c) J.J. Hoekstra - 2020
   tested with noForth CC5994 200202 on MSP430FR5994
   uses eUSCI B1 for the SPI
   on my standard setup: MCLK=16MHz, SMCLK=1MHz
*)

hex
code -ROT                       \ noForth has no -ROT
    tos w mov   sp ) tos mov
    2 sp x) sp ) mov   w 2 sp x) mov
next end-code

code I+ rp ) tos add  next  end-code \ adds i to top - saves ~15c/loop

: SPI-SETUP
    01 680 **bis                    \ UCB1CTLW  keep eUSCI_b1 in reset
    07 24A *bis                     \ =p5sel0       p5sel0.0-2 must be 0x1 -> *bis with 0x7 - p5.0, p5.1, p5.2 = SPI
    07 24C *bic                     \ =p5sel1   p5sel1.0-2 must be 0x0 -> *bic with 0x7 - p5.0, p5.1, p5.2 = SPI
    88 244 c!                       \ p5DIR     set bit3 and bit7 -> CSn on pin5.3 - D/C on pin5.7
    E981 680 !                          \ UCB1CTLW      CLK=low, MSB first, Master, Synchroon, SMCLK -> A981 werkt ook
    00 686 !                            \ UCB1BRW       Clock is 1Mhz/1 = 1MHz
    08 242 *bis                     \ p5OUT     CSneg=p5.3 set to 0x1 => no chip selected
    80 242 *bis                         \ P5OUT     d/c = high -> = data
    01 680 **bic ;                  \ UCB1CTLW      release eUSCI_B1

code >SPI   ( b -- )                    \ Write b to SPI-bus
   B3E2 , 6AC , 2BFD , 47C2 , 68E , 4437 , next
 end-code

code COMM   80 # 242 & .b bic  next  end-code       \ DC=p5.7=low - ok
code DATA   80 # 242 & .b bis  next  end-code       \ DC=p5.7=high - ok
code {{     8 # 242 & .b bic  next  end-code        \ CSn=low - ok
code }}     8 # 242 & .b bis  next  end-code        \ CSn=high - ok

\ SPI primitives
: {CMD      ( b -- )        {{  comm  >spi noop ;   \ Start command stream
: {DATA     ( -- )          {{  data noop ;             \ Start data stream
: >DATA     ( b -- )        >spi noop ;             \ Send 1 data byte
: OL}       ( b -- )        >spi noop }} ;              \ Send 1 data byte and end of stream
: CMD       ( b -- )        {cmd  noop }} ;             \ Single byte command
: 2CMD      ( b1 b0 -- )    {cmd  ol} ;             \ Dual byte command
: >BRIGHT   ( b -- )        81 2cmd ;                   \ b = 0 to 255 (max. brightness)
: ON/OFF    ( flag -- )     1 and  AE or cmd ;          \ Display on/off
: INVERSE   ( flag -- )     1 and  A6 or cmd ;          \ Display black or white

: XY ( x page -- ) \ set X & page in OLED - now safe without use of values & ONSCR?
\ speed-critical for future single pixel drawing...
    7 and B0 or {cmd                \ set page
    7F and 2 + dup 0F and >spi          \ set column - part a
    F0 and 4 rshift 10 or ol} ;         \ set colums - part b

: SETUP-DISPLAY
    spi-setup                           \ 1MHz USCI SPI & cs&dc lines
    false on/off                            \ Display off
    D5 {cmd  80 >spi                    \ Set oscillator clock
    A8 >spi  3F >spi                    \ Set multiplexer ratio
    D3 >spi  00 >spi                    \ Display offset = 0
    40 >spi                     \ Display starts at line 0
    8D >spi  14 >spi                    \ Charge pump on
    20 >spi  00 >spi                    \ 0x0=Horizontal display mode - 0x2=page-mode
\ de next 3 lines flip the screen to account for the position of the connector
    A1 >spi                     \ Mirror X-axis (segment remap)
    C8 >spi                     \ Mirror Y-axis (COM scan direction)
    DA >spi  12 >spi                \ Alternate Com pin map
    
    D9 >spi  22 >spi                    \ Set precharge cycles to high cap: 022 was F1
    DB >spi  20 >spi                    \ VCOMH voltage - 40 or 30 also work
    A4 >spi  E3 ol}                 \ Enable rendering from GDRAM, end stream
    D0 >bright                      \ Set brightness to ~80%
    false inverse                   \ OLED in normal mode
    true on/off ;                           \ Display on

create SCRBF 400 allot                  \ 1k screenbuffer

: >OLED     ( -- )  \ copies screen buffer to OLED - depends on horizontal mode of display!
    0 0 xy {data                        \ to 0,0
    400 0 do
        scrbf i+ c@ >data               \ get bytes and copy to screen
    loop noop }} ;`

: OL-FILL   ( byte -- )                 \ now FILL-based
    >r scrbf 400 r> fill ;

: OL-PAGE   ( -- )      0 ol-fill >OLED ; \ clearscreen

: XY>ADDR   ( x y -- addr )             \ calculates screenbuffer-address due to x and y in pixels
    3F and 10 * FF80 and                \ address due to y
    swap 7F and + scrbf + ;             \ plus x pus buffer

create BMASK 1 c, 2 c, 4 c, 8 c,        \ to avoid the slow shift of MSP430
    10 c, 20 c, 40 c, 80 c,

: GETMASK   ( y -- mask )               \ #TBD: assembly
    7 and bmask + c@ ;              \ was '3F and 8 mod' which equals '7 and'

: SETPIXEL  ( x y -- )  \ sets pixel @ x and y
    dup getmask -rot xy>addr *bis ;
: CLEARPIXEL ( x y -- ) \ clears pixel @ x and y
    dup getmask -rot xy>addr *bic ;

: GO        ( -- )      setup-display ;

shield SSD1306\  freeze


\ random generator incl CHOOSE **********

hex
value ASEED0 1 to aseed0                \ init aseed0 with 1
value ASEED1 0 to aseed1                \ init aseed1 with 0

code RANDOM ( -- u )
  8324 , 4784 ,    0 , 4217 , adr aseed0 , 4292 , adr aseed1 , adr aseed0 ,
  4708 , C312 , 1007 , 1087 , 2802 , 5037 ,   80 , C037 ,
    7F , E807 , 4708 , C037 ,   FF , 1087 , C312 , 1007 ,
  E807 , 4708 , 1087 , C037 ,   FF , E807 , 4218 , adr aseed1 ,
  E708 , 4882 , adr aseed1 ,  next
end-code

: CHOOSE    ( u1 - u2 )     random um* nip ;

\ dice *********************************

: W     ( x y -- x+1, y )   swap 1+ swap 2dup clearpixel ;  \ Pixel off
: Z     ( x y -- x+1, y )   swap 1+ swap 2dup setpixel ;    \ Pixel on
: |     ( x y -- x-9 y+1 )  swap 9 - swap 1+ ;              \

: .DOT  ( x y -- )  \ prints dice-dot at x and y
    2dup clearpixel                 \ the first pixel only needs a 2dup
       w z z z z z w w
    | w z z z z z z z w
    | z z z z z z z z z
    | z z z z z z z z z 
    | z z z z z z z z z 
    | z z z z z z z w z
    | z z z z z z w z z
    | w z z w w w z z w
    | w w z z z z z w w
    2drop ;

\ bitcodes for dice-dot patterns
\  1     2
\  4  8 10
\ 20    40

create PATTERN  ( -- a )    \ array with different dice-dot patterns
    0 c,                        \ 0 = no dots
    08 c, 22 c, 2A c, 63 c, 6B c, 77 c,     \ 1...6
    49 c, 1C c,                 \ 7 & 8 for show-pikkie effects

: NEXTDOT   ( n1 -- n2 )    1 rshift dup 1 and ;

decimal
: .DOT      ( n -- )    \ translates patterns to visible dots
    OL-PAGE PATTERN + c@                 \ get dot-pattern
    dup 1 and if 41 9 .dot  then         \ if bit:0 set -> show dot at 41, 9
    NEXTDOT if  77  9 .dot  then         \ ditto for bit:1
    NEXTDOT if  41 27 .dot  then         \ etc...
    NEXTDOT if  59 27 .dot  then
    NEXTDOT if  77 27 .dot  then
    NEXTDOT if  41 45 .dot  then
    NEXTDOT if  77 45 .dot  then
    drop >OLED ;

: DICE      ( -- )      6 choose 1+ .DOT ;             \ throw dice once
: SHOW1     ( -- )      400 0 do  dice i ms  OL-PAGE 30 ms  30 +loop  dice ;

: ROLL1     ( -- )
    175 0 do
        3 .DOT i ms     8 .DOT i ms
        7 .DOT i ms     8 .DOT i ms
    25 +loop ;

: ROLL2     ( -- )
    2 0 do
        255 ol-fill >OLED 20 ms  OL-PAGE 40 ms
    loop ;

: SHOW2     ( -- )      roll1 roll2  dice ;               \ show-pikkie

\ ************************************
: RANDOMTEST ( -- )
    OL-PAGE
    25 for
        400 for
            128 choose  64 choose
            2 choose if setpixel else clearpixel then
        next  >OLED
    next ;
\ ************************************

\ End ;;;
