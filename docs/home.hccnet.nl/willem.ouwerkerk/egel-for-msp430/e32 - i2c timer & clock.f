(* E32 - For noForth C&V2553 lp.0, bitbang I2C on MSP430G2553 using port-1.
   I2C input & output with a PCF8574 & PCF8583 using external pull-ups

  Connect the I2C-print from the Forth users group or any other module
  with a PCF8574  with 8 leds & PCF8583 and connect the power lines, 
  P1.7 to SDA and P1.6 to SCL. 
  Note that two 10k pullup resistors has te be mounted, that's it
 *)

hex
\ Output routine for PCF8574(a) chips 042 = device address 1 of a PCF8574
: !BYTE     ( b a -- )   i2write  i2out  i2stop ;
: >LEDS     ( b -- )     invert  042 !byte ;
: FLASH     ( -- )       FF >leds 100 ms  00 >leds 100 ms ;

\ PCF8583 bcd conversion
: >BCD              ( bin -- bcd )   0A /mod  4 lshift + ;
: BCD>              ( bcd -- bin )   >r  r@ 4 rshift 0A *  r> 0f and  + ;

\ Set data 'x' at address 'a' from PCF8583.
: !CLOCK         ( x a -- )
    A0 i2write          \ Send dev. address write
    i2out               \ send register address
    i2out               \ then databyte
    i2stop ;            \ ready

\ Read data 'x' from address 'a' from PCF8583.
: @CLOCK         ( a -- x )
    A0 i2write          \ Send dev. address for writing
    i2out               \ send register address
    i2read)             \ send dev. address for reading
    i2in                \ read contents address 
    i2nack  i2stop ;    \ ready

\ Note: s(ec) m(in) and h(our) are in decimal !!
: SET-CLOCK  ( s m h -- )       \ set PCF8583 at time
    0 01 !clock  >bcd 04 !clock \ convert to bcd and store
    >bcd 03 !clock  >bcd 02 !clock ;    

\ read de time s(ec), m(in) en h(our).
: ALARM?        ( -- fl )   00 @clock  2 and 0<> ;
: GET-SEC       ( -- sec )  02 @clock bcd> ;

: GET-CLOCK     ( -- s m h )    \ read time from pcf8583 and convert to binary
    get-sec  03 @clock bcd>  04 @clock bcd> ;

: RESET-CLOCK   ( -- )      0 0 0 set-clock ;

: SET-ALARM     ( sec min -- )
    0 09 !clock  0 0C !clock  >bcd 0B !clock  >bcd 0A !clock ;

: NEXT-ALARM    ( -- )          \ Restart alarm time in 10 sec.
    04 00 !clock  0A 00 set-alarm  reset-clock ;

value SEC                       \ Remember second
: TICK          ( -- )          \ Flash led every second
    get-sec sec <> if           \ Second passed ?
        get-sec to sec          \ Yes, save second
        80 >leds 19 ms 0 >leds  \ flash highest led
    then ;

\ Three RTC example programs
: TIMER         ( -- )          \ Show timer
    setup-i2c  flash 
    04 00 !clock  90 08 !clock  \ Alarm clock daily alarm
    begin
        next-alarm              \ Advance alarm
        begin tick alarm? until \ wait for alarm. show seconds
        flash                   \ after alarm all leds on and off
    key? until ;


: ALARM         ( sec min -- )  \ Show timer
    setup-i2c 
    04 00 !clock  90 08 !clock  \ Alarm clock daily alarm
    set-alarm   reset-clock     \ Next alarm time
    begin tick alarm? until     \ wait for alarm, show seconds pulse
    cr ." Ready "               \ after alarm all leds on and off
    begin  flash  key? until ;


: .TIME         ( -- )
    get-clock . ." Hr "  . ." Min "  . ." Sec " ;

\ Needs seven segment or LCD to build a real clock
\ First set the time using SET-CLOCK  ( s m h -- )
: CLOCK         ( -- )
     00 00 !clock  00 08 !clock  \ Normal clock, no alarm
     base @ >r  decimal
     begin
         get-sec sec <> if
            get-sec to sec
            cr ." Time " .time 
            FF >leds  19 ms  00 >leds
         then
    key? until
    r> base ! ;

shield PCF8583\  freeze

\ End
