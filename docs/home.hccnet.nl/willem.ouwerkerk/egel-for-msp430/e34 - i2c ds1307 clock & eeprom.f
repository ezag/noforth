(* E34 - For noForth C&V2553 lp.0, bitbang I2C on MSP430G2553 using port-1.
   I2C data memory and RTC with an 24C32 & DS1307 using external pull-ups

  Connect the Tiny RTC I2C-module from AliExpress or any other module
  with a DS1307 RTC and 24C32 EEPROM and connect the power lines, 
  P1.7 to SDA and P1.6 to SCL, that's it

  For the DC1307 RTC all numbers are in BCD
    00 = seconds
    01 = minutes
    02 = hour
    03 = weekday
    04 = date
    05 = month
    07 = Clock control
    08 - 3F = 56 bytes RAM
 *)

hex
\ Output routine for PCF8574(a) chips 042 = device address 1 of a PCF8574
\ : !BYTE     ( b a -- )   i2write  i2out  i2stop ;
\ : >LEDS     ( b -- )     invert  042 !byte ;
\ : FLASH     ( -- )       FF >leds 100 ms  00 >leds 100 ms ;

\ PCF8583 bcd conversion
: >BCD      ( bin -- bcd )  0A /mod  4 lshift + ;
: BCD>      ( bcd -- bin )  >r  r@ 4 rshift 0A *  r> 0f and  + ;

\ Set data 'x' at address 'a' from DS1307.
: !CLOCK    ( x a -- )
    D0 i2write          \ send chip address write
    i2out               \ send address byte and
    i2out               \ then databyte
    i2stop ;            \ ready

\ Read data 'x' from address 'a' from DS1307.
: @CLOCK    ( a -- x )
    D0 i2write          \ send chip address write
    i2out               \ send address
    i2read)             \ send chip address for reading
    i2in                \ read contents address 
    i2nack  i2stop ;    \ ready

\ Set & read time to/from DS1307. s(ec) m(in) and h(our) are in decimal!
: SET-CLOCK ( s m h -- ) 02 !clock  >bcd 01 !clock  >bcd 00 !clock ;    
: GET-SEC   ( -- sec )   00 @clock bcd> ;
: GET-MIN   ( -- min )   01 @clock bcd> ;
: GET-CLOCK ( -- s m h ) get-sec  get-min  02 @clock bcd> ;

\ Two free RAM locations in DS1307 we use for alarm function
08 constant MINS
09 constant SECS
: SET-ALARM  ( s m -- )  mins !clock  secs !clock ;
: ALARM?     ( -- f )    get-sec secs @clock =  get-min mins @clock =  and ;
: NEXT-ALARM ( -- )      0A 00 set-alarm  0 0 0 set-clock ;

value TICK)                     \ Remember second
: TICK      ( -- ) 
    get-sec tick) <> if         \ Second passed ?
        get-sec to tick)        \ Yes, save second
        ch . emit               \ show dot
    then ;

\ Three RTC example programs
: TIMER     ( -- )              \ Show timer
    setup-i2c  cr ." Start " 
    begin
        next-alarm              \ Advance alarm
        begin tick alarm? until \ wait for alarm. show seconds
        cr ." Ready, restart "  \ after alarm
    key? until ;


: ALARM     ( sec min -- )      \ Show timer
    setup-i2c 
    set-alarm   0 0 0 set-clock \ Next alarm time
    begin  tick  alarm? until   \ wait for alarm, show seconds pulse
    begin  cr ." Ready "  key? until ;


: (.TIME    ( s m h -- )    . ." Hr "  . ." Min "  . ." Sec " ;
: .TIME     ( -- )  get-clock  (.time ;

\ Needs seven segment or LCD to build a real clock
\ First set the time using SET-CLOCK  ( s m h -- )
: CLOCK     ( -- )
     setup-i2c  base @ >r  decimal
     begin
         get-sec tick) <> if
            get-sec to tick)
            cr ." Time " .time 
\           FF >leds  19 ms  00 >leds
         then
    key? until
    r> base ! ;


\ Example with clock & 24C32 EEPROM
: EEADDR    ( a -- )            \ Address EEprom at addr. 'a'
    A0 i2write  dup >< i2out  i2out ; \ EE dev. addr. then ee-addr.

\ Read data b from 24C32 EEPROM byte-address addr. 
: EC@       ( addr -- b )
    eeaddr  i2read)  i2in   \ Read data from address
    i2nack  i2stop ;        \ stop reading from EEPROM

\ Write data b to 24C32 EEPROM byte-address addr.
: EC!       ( b addr -- )
    eeaddr  i2out  i2stop  poll ; \ Wait until write is done

value ADDRESS  0 to address     \ Store b in EEPROM
: STORE     ( b -- )
    address 1000 < if  dup address ec!  20 ms  1 +to address  then  drop ;

\ Show stored data in decimal from EEPROM
: SHOW      ( -- )
    base @ >r  decimal
    address 0 ?do
        cr  i 2 + ec@  i 1+ ec@  i ec@ (.time
        stop? if  leave  then
    3 +loop 
    r> base ! ;

: GATHER    ( -- )              \ Gather time data in EEPROM
    setup-i2c  0 to address
    begin
         get-sec tick) <> if
            get-sec to tick)  ch . emit
            get-clock  store store store
        then
    key? until ;        

shield DS1307\  freeze

\ End
