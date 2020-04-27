(* E11 - For noForth C&V2553 lp.0, bitbang SPI-like on MSP430G2553 at port-2.
  Control of seven segment display's using one or more 74HC4094 or 74HC595 chips.

  Connect a 74HC4094 to VCC and ground, pin-1 to P2.0, pin-2 to P2.1
  pin-3 to P2.2!! Pin-4 to pin-11 are eight outputs they must be connected
  to an 7-segm. display. For more digits multiple 74HC4094 maybe 
  connected to each other, strobe and cp in parallel. See schematic.

  Note that: You may use common anode or common cathode displays.
    Common cathode displays have a common ground connection, common
    anode displays have a common VCC connection!

  **** THIS CODE IS FOR A COMMON CATHODE DISPLAY ****

  029 - P2OUT is the port 2 output register
  02A - P2DIR is the port 2 direction register
 *)

hex
: READY     01 029 ;            \ P2OUT  Bit P2.0 - strobe 74HC4094
: DATA      02 029 ;            \ P2OUT  Bit P2.1 - data 74HC4094
: CLOCK     04 029 ;            \ P2OUT  Bit P2.2 - cp 74HC4094
: INIT-SPI  07 02A *bis ;       \ P2DIR

( u*8 bits output uses no more than only 3 I/O-bits )
: WRITE-BIT       ( flag -- )           ( Write one bit to 74HC4094 )
    if  data *bis else data *bic  then  clock *bic clock *bis ;

: SHOW              ( -- )              ( Set data on 74HC4094 outputs )
    ready *bis ready *bic ;
 
: >DRIVER           ( x -- )            ( Schrijf x naar display )
    8 0 do                              ( display driver )
        dup 80 and write-bit  2*
    loop
    drop ;

( Make numbers for an common anode seven segment display )
( using 74HC4094 building characters 0 to F and a dot )
( Layout of 7-segm. Display  +-01-+ )
(                            20  02 )
( Driver 74HC4094            +-40-+ )
(                            10  04 )
( Dec. dot is 80 !!          +-08-+ )
CREATE NUMBERS   ( Building characters            .gfedcba )
  bn 11000000 c, bn 11111001 c, bn 10100100 c, bn 10110000 c, ( 0, 1, 2, 3 )
  bn 10011001 c, bn 10010010 c, bn 10000010 c, bn 11111000 c, ( 4, 5, 6, 7 )
  bn 10000000 c, bn 10010000 c, bn 10001000 c, bn 10000011 c, ( 8, 9, A, b )
  bn 11000110 c, bn 10100001 c, bn 10000110 c, bn 10001110 C, ( C, d, E, F )
  bn 10111111 c, bn 01111111 c, bn 11111111 c,  align         ( -, ., and off )

: >DISPLAY          ( u -- )            ( Send number u to digits )
    12 umin  numbers   +                ( From binary to cc 7-segment )
    c@  invert >driver  show ;          ( And show inverted pattern! )

: FLASH         ( -- )                  ( Show startup: F and - )
    0F >display  150 ms
    10 >display  150 ms
    12 >display  150 ms ;


: CHARACTERS    ( -- )                  ( Show all implemented characters )
    init-spi  flash                     ( Initialise 7-segm. example )
    0                                   ( Character counter on stack )
    begin
        dup >display  1+                ( Show character and incr. counter )
        150 ms                          ( Wait a moment )
        dup 13 = if  drop  0  then      ( Count 18? start at zero )
    key? until  drop                    ( Stop or loop again )
    12 >display ;                       ( Display off )


: COUNTER       ( -- )                  ( Decimal counter )
    init-spi  flash                     ( Initialise 7-segm. example )
    begin
        0A 0 do i >display 200 ms loop  ( Count )
    key? until
    12 >display ;                       ( Display off )


value RND  chere to rnd                 ( Random seed )
: RANDOM        ( -- u )     rnd dm 31421 * dm 6927 + dup to rnd ;
: CHOOSE        ( u1 -- u2 ) random um* nip ;   ( u2 = 0 to u1-1 )
: PRESS?        ( -- f )     key?  s? 0=  or ;  ( Key pressed? )
: (DICE)        ( -- )       6 choose  1+ >display ; ( Show nr. 1 to 6 )

: DICE          ( -- )                  ( Throw a single dice )
    init-spi  10 >display  chere to rnd ( Initialise dice example )
    begin
        begin  random drop  press? until ( S2 key pressed? )
        begin
             (dice)  20 ms              ( Increase counter & show number )
        s?  key?  or until              ( Until S2 key released )
    key? until  12 >display ;           ( Display off )

shield 7segm\  freeze

( End )
