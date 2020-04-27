(* E34U - For noForth C&V2553 lp.0, bitbang I2C on MSP430G2553 using port-1.
   I2C data memory and RTC with an 24C32 & DS1307 using external pull-ups

  Connect the Tiny RTC I2C-module from AliExpress or any other module
  with a DS1307 RTC and 24C32 EEPROM and connect the power lines, 
  P1.7 to SDA and P1.6 to SCL and jumper P1.6 to the green led has to 
  be removed, that's it.

 Addresses, Lables and Bit patterns  
 0069    - UCB0CTL1     - 081
 0003    - IFG2         - 008 = TX ready, 004 = RX ready

  For the DC1307 RTC all numbers are in BCD
    00 = seconds
    01 = minutes
    02 = hour
    03 = weekday
    04 = date
    05 = month
    07 = Clock control
    08 - 3F = 56 bytes RAM

This code implements a RTC with a DS1307 chip and data storage with 
an 24C32 EEPROM

User words: SET-CLOCK   ( sec min hr -- )   Set new time for RTC
            ALARM       ( -- )              Give every 10 seconds an alarm
            TIMER       ( sec min -- )      Simulate a cooking timer
            CLOCK       ( -- )              Show RTC
            GATHER      ( -- )              Gather time data in EEPROM
            SHOW        ( -- )              Show time data from EEPROM

 *)

hex
\ Output routine for PCF8574(a) chips 042 = device address 1 of a PCF8574
\ : !BYTE     ( b a -- )   {i2write  i2out1  i2stop} ;
\ : >LEDS     ( b -- )     invert  42 !byte ;
\ : FLASH     ( -- )       FF >leds 100 ms  00 >leds 100 ms ;

\ PCF8583 bcd conversion
: >BCD      ( bin -- bcd )  0A /mod  4 lshift + ;
: BCD>      ( bcd -- bin )  >r  r@ 4 rshift 0A *  r> 0f and  + ;

\ Set data 'x' at address 'addr' from DS1307.
: !CLOCK    ( x addr -- )   \ set x in address addr
    D0 {i2write  i2out1     \ send chip address & clock address
    i2out  i2stop} ;        \ then databyte & ready

\ Read data 'x' from address 'addr' from DS1307.
: @CLOCK    ( addr -- x )   \ read de contents from adr, x
    D0 {i2write  i2out1     \ send chip address & clock address
    {i2read)  i2in} ;       \ repeated start & read data 

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
: ALARM     ( -- )              \ Show timer
    setup-i2c  cr ." Start " 
    begin
        next-alarm              \ Advance alarm
        begin tick alarm? until \ wait for alarm. show seconds
        cr ." Ready, restart "  \ after alarm
    key? until ;


: TIMER     ( sec min -- )      \ Show timer
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
: {EEADDR   ( a -- )            \ Address EEprom
    A0 {i2write  dup >< i2out1  \ High EE-addr.
    i2out ;                     \ then low ee-addr.

\ Read data b from 24C32 EEPROM byte-address addr. 
: EC@       ( addr -- b )
    {eeaddr  {i2read)  i2in} ;  \ Address EE & rep. start & read data

\ Write data b to 24C32 EEPROM byte-address addr.
: EC!       ( b addr -- )
    {eeaddr  i2out  i2stop}  {poll} ; \ Address EE & write data

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
