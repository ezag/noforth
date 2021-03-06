(* E35 - For noForth C&V 200202: USCI I2C on MSP430G2553 using port-1.
   Using an I2C to LCD module like: 86014 = LCD Adapter Plate I2C 

  Connect a 3 or 5 Volt version of an 1602 LCD display to an I2C
  adapter print, contrast control using potmeter. See schematic.
  Only four wires, VCC, GND, SDA=P1.7, & SCL=P1.6 and jumper P1.6 to
  the green led has to be removed, that's it.

  P4 to P7          = Data lines to LCD
  P0                = Data/Char  ( False = Data )
  P1                = R/W
  P2                = Enable ( falling edge )
  P3                = Backlight on/off
 *)

hex
value LIGHT                             \ Backlight on/off
: !LCD      ( bitmap -- )               \ Send bitmap to 86014 module
    light 8 and or  4E {i2write i2stop} ; \ with dev. address 4E, Backlight?

\ dm 40 constant B/L                    \ Display line buffer length
dm 16 constant C/L                      \ Line length of LCD
\ dm 02 constant L/S                    \ Nr. of lines of LCD
value CURSOR                            \ Current cursor position

\ Set high 4-bits at I/O-poort, bit-2 = Enable, bit-1 = Character/Data
: >LCD          ( nibble flag -- )
    1 and >r  F0 and  r> or  dup !lcd   \ Flag notes data or char
    dup 4 or !lcd  !lcd ;               \ Give enable pulse

\ Flag true = character-byte, flag false = data-byte
: LCD-BYTE      ( byte flag -- )        \ Send byte to LCD
    >r  dup r@ >lcd  4 lshift r> >lcd
    dm 40 0 do loop ;

: LCD-INSTR     ( byte -- )             \ Send data to LCD
    false lcd-byte ;

: LCD-PAGE      ( -- )                  \ Make LCD clean and set cursor
    1 lcd-instr  0 to cursor  2 ms ;    \ in upper left corner.

: LCD-SETUP     ( -- )
    setup-i2c  A0 ms  false to light    \ I2C all 8-bits are outputs, wait
    3 for  30 false >lcd  5 ms  next    \ And set 8 bits interface mode
    20 false >lcd                       \ Finally set 4 bits interface mode.
    28 lcd-instr                        \ 4 bit interf. 2 lines, 5*7 bits char.
    8 lcd-instr  lcd-page               \ Display cursor, empty screen
    6 lcd-instr                         \ Display direction from left to right
    0C lcd-instr                        \ Display on & cursor on
    true to light ;                     \ Backlight-on

: LCD-EMIT      ( char -- )     incr cursor  true lcd-byte ;
: LCD-TYPE      ( a u -- )      for  count lcd-emit  next  drop ;
: LCD-SPACE     ( -- )          bl lcd-emit ;
: LCD-SPACES    ( u -- )        for  lcd-space  next ;

: LCD-CR        ( -- )                  \ Send CR to LCD.
    c/l  cursor  - 0< if                \ Cursor at line 2 ?
        80 lcd-instr  0 to cursor       \ Yes, to line 1
    else
        C0 lcd-instr  c/l to cursor     \ No, to line 2
    then
    ;

: DEMO          ( -- )
    lcd-setup
    S" Hallo!!" lcd-type  \ Test LCD
    lcd-cr  S" Forth-gg " lcd-type ;

shield lcd\  ( ' demo  to app )  freeze

\ End
demo
