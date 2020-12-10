(* E60a - For noForth C&V 200202: I2C driver for SSD1306 
   The SSD1306 is a 0.96 inch 128x64 pixels oled screen using USCI I2C routines. 
   Separate files with a small, big, bold & graphic character set.
*)

hex
: {ol       ( b -- )        78 {i2write  i2out1 ;   \ Start an oled command: b=00 or old data: b=40
                                                    \ Single byte command: b=80, single byte data: b=C0 
: ol}       ( b -- )        i2out  i2stop} ;        \ End an oled stream
: CMD       ( b -- )        80 {ol  noop  ol} ;     \ Single byte oled command
: 2CMD      ( b1 b0 -- )    00 {ol  i2out  ol} ;    \ Dual byte oled command
: CONTRAST  ( b -- )        81 2cmd ;               \ b = 0 to 255 (max. contrast)
: ON/OFF    ( flag -- )     1 and  AE or cmd ;      \ Display on/off
: INVERSE   ( flag -- )     1 and  A6 or cmd ;      \ Display black or white

value X  value Y
: >XY       ( x y -- )          \ Set OLED column and row
    00 {ol                      \ Command stream
    dup to y  7 and B0 or i2out \ Set page
    dup to x  dup 0F and i2out  \ Set column
    F0 and 4 rshift 10 or ol} ;

: DISPLAY-SETUP ( -- )
    setup-i2c               \ Init. 400kHz USCI I2C
    false on/off            \ Display off
    00 {ol                  \ Start oled-command stream
    0A8 i2out  03F i2out    \ Set multiplexer ratio
    0D3 i2out  000 i2out    \ Display offset = 0
    040 i2out               \ Display starts at line 0
    0A1 i2out               \ Mirror X-axis
    0C8 i2out               \ Mirror Y-axis
    0DA i2out  012 i2out    \ Alternate Com pin map
    0A4 i2out               \ Enable rendering from GDRAM
    0D5 i2out  080 i2out    \ Set oscillator clock
    08D i2out  014 i2out    \ Charge pump on
    0D9 i2out  022 i2out    \ Set precharge cycles to high cap.
    0DB i2out  030 i2out    \ VCOMH voltage to max.
    020 i2out  000 ol}      \ Horizontal display mode, end stream
    C0 contrast             \ Set contrast to 75%
    false inverse           \ Oled in normal mode
    true on/off ;           \ Display on

: &FILL         ( +n b -- ) \ Pattern 'b' to +n columns
    40 {ol   swap           \ Start oled-data stream
    begin                   \ Whole screen buffer
        over i2out          \ Output pattern
    1- ?dup 0= until  i2stop}  drop ;   \ End stream

: &ERASE        ( -- )          400 0 &fill ;       \ Erase screen
: &HOME         ( -- )          0 0 >xy ;           \ To upper left corner
: &PAGE         ( -- )          &erase  &home ;

shield SSD1306\  freeze

\ End
