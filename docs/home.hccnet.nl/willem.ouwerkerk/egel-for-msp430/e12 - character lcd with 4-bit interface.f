(* E12 - For noForth C&V2553 lp.0, bitbang LCD on MSP430G2553 using port-2.
  Timer-A1 is used for contrast control of the LCD

  Connect 3 Volt version of an 1602 LCD display to P2.0 to P2.5
  P1.6 is the contrast control ouput for the LCD. See schematic.
  The user words are: DEMO1  DEMO2
 
  Px 1- is the address of a port input register
  Px 1+ is the address of a port direction register
  021 = P1 outputs, 029 = P2 outputs
  P2.0 tot P2.3     = Data lines to LCD
  P2.4              = Data/Char  ( False = Data )
  P2.5              = Enable ( falling edge )
  P1.6              = Contrast voltage (VEE)

     FEDCBA9876543210 bit-numbers 
  BN 0000000001000000 CONSTANT #OUTPUT \ Select output bit-6 - 0040
  BN 0000000011100000 CONSTANT #OUT    \ Reset/Set output   - 00E0
  BN 0000001000010100 CONSTANT #PBM    \ TA=0, count up, SMCLK, no divider - 0214

  172   - TA1CCR0   - Period timing - 03E7 (999)
  174   - TA1CCR1   - Duty cycle - 02EE (750)
  164   - TA1CCTL1  - Output mode Set/Reset - 000E (014)
  160   - TA1CTL    - Compare mode - 0214 (532)
  021   - P1OUT
  022   - P1OUT     - Contrast of LCD
  026   - P1SEL
  029   - P2OUT
  041   - P1SEL2
  029   - P2OUT     - LCD control lines
  02A   - P2DIR
 *)

\ The period length is 1000 clock cycles ( 2 x #CYCLUS )
\ dm 500 constant #CYCLUS
hex

\ Contrast = 0 to 10
: >CONTRAST     10 umin 174 ! ;         \ TA1CCR1  ( 0 to 10 -- )
: OSC-OFF       0 160 !  040 026 *bic ; \ TA1CTL, P1SEL

\ PBM at P1.6
: OSC-ON         ( -- )
    040 022 *bis            \ Make P1.6 output
    040 026 *bis            \ P1SEL    Set OSC to P1.6
    040 041 *bic            \ P1SEL2
    dm 499 172 !            \ TA1CCR0  Set period time #CYCLUS -1
    0E0 164 !               \ TA1CCTL1 Set uitput mode
    214  160 !              \ TA1CTL   PWM setup
    dm 8 >contrast ;        \ Set default contrast for LCD

\ dm 40 constant B/L        \ Display line buffer length
dm 16 constant C/L          \ Line length of LCD
\ dm 02 constant L/S        \ Nr. of lines of LCD
value CURSOR                \ Current cursor position

\ Set low 4-bits at I/O-poort, bit-5 = Enable, bit-4 = Character/Data
: >LCD          ( nibble flag -- )
    >r  0f and  r> 10 and or  029 c!    \ P2OUT  Flag notes data or char
    20 029 *bis  20 029 *bic ;          \ P2OUT  Enable pulse

\ Flag true = character-byte, flag false = data-byte
: LCD-BYTE      ( byte flag -- )        \ Send byte to LCD
    >r  dup 4 rshift  r@ >lcd  r> >lcd
    dm 40 0 do loop ;

: LCD-INSTR     ( byte -- )             \ Send data to LCD
    false lcd-byte ;

: LCD-PAGE      ( -- )                  \ Make LCD clean and set cursor
    1 lcd-instr  0 to cursor  2 ms ;    \ in upper left corner.

: LCD-SETUP     ( -- )
    3F 02A c!   0A0 ms                  \ P2DIR  lower 6-bits are outputs, wait
    3 0 do  03 false >lcd  5 ms  loop   \ And set 8 bits interface mode
    02 false >lcd                       \ Finally set 4 bits interface mode.
    28 lcd-instr                        \ 4 bit interf. 2 lines, 5*7 bits char.
    08 lcd-instr  lcd-page              \ Display cursor, empty screen
    06 lcd-instr                        \ Display direction from left to right
    0c lcd-instr                        \ Display on & cursor on
    osc-on ;                            \ LCD contrast voltage on

: LCD-EMIT      ( char -- )     incr cursor  true lcd-byte ;
: LCD-TYPE      ( a u -- )      0 ?do  count lcd-emit  loop  drop ;
: LCD-SPACE     ( -- )          bl lcd-emit ;
: LCD-SPACES    ( u -- )        0 ?do  lcd-space  loop ;

: LCD-CR        ( -- )                  \ Send CR to LCD.
    c/l  cursor  - 0< if                \ Cursor at line 2 ?
        80 lcd-instr  0 to cursor       \ Yes, to line 1
    else
        C0 lcd-instr  c/l to cursor     \ No, to line 2
    then ;

: DEMO1         ( -- )
    lcd-setup
    S" Hi Forth" lcd-type   lcd-cr       \ Test LCD
    S" users..." lcd-type ;

: DEMO2         ( -- )
    lcd-setup
    S" noForth " lcd-type   lcd-cr       \ Test LCD
    S" Egel '16" lcd-type ;

shield lcd\
' demo2  to app  freeze

\ End
