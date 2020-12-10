(* E112B - For noForth C&V 200202 or later:  I2C for use with MSP430F149 
   and 24C64, 8 kByte EEPROM
   
   The MSP430F149 has no build in resistors they have to be added externally
   DO and LOOP are the main slowing down factors in this implementation
   The SDA is at P1.4, SCL is at P1.5
   
   Optional new words are: EVARIABLE and EVARIABLES
   Preset now: EC! EC@  E! E+! E@ EHERE EALLOT EC, E, and ECREATE
*)

inside also  definitions  hex
code WAIT       ( -- )  next  end-code
code SET-SDA    ( -- )  10 # 22 & bic  10 # 21 & bis  next  end-code
code CLR-SDA    ( -- )  10 # 21 & bic  10 # 22 & bis  next  end-code
code SET-SCL    ( -- )  20 # 22 & bic  20 # 21 & bis  next  end-code
code CLR-SCL    ( -- )  20 # 21 & bic  20 # 22 & bis  next  end-code

code READ-SDA   ( -- f )
    tos sp -) mov  #-1 tos mov  
    10 # 20 & bit  cs? if, #0 tos mov then,  next
end-code

\ Read bit from SDA and add to byte1 forming byte2
code BIT-IN     ( byte1 -- byte2 )
    tos tos add  10 # 20 & bit  cs? if, #1 tos bis then,  next
end-code

\ Write highest bit from byte to SDA line
code WRITE-SDA  ( byte -- )
    80 # tos bit cs? if,
        10 # 22 & bic  10 # 21 & bis
    else,
        10 # 21 & bic  10 # 22 & bis
    then,
    tos tos add
    next
end-code

: START-BIT ( -- )      set-scl wait  clr-sda ;
: STOP-BIT  ( -- )      clr-scl clr-sda wait  set-scl wait  set-sda ;
: ACK-BIT   ( -- )      clr-scl clr-sda  set-scl wait wait  clr-scl ;
: NACK-BIT  ( -- )      clr-scl set-sda  set-scl wait wait  clr-scl ;
: SKIP-ACK  ( -- )      clr-scl set-sda  set-scl wait wait  clr-scl ;
: INIT-IO   ( -- )      ( 03 206 *bis )  30 22 *bic  30 21 *bis ;
: SETUP-I2C ( -- )      init-io  set-sda set-scl ;

( Test incoming ackbit, flag is true if an ack is received. )
: ACK?      ( -- fl )
    clr-scl ( wait ) set-sda  set-scl ( wait ) read-sda  clr-scl ;

: (BYTE-OUT)    ( byte -- )                \ Send byte
    8 0 do
        clr-scl write-sda ( wait ) set-scl ( wait )
    loop
    drop ;
    
: BYTE-OUT      ( byte -- )
    (byte-out)  skip-ack ;              \ Ignore (No)Ack

: BYTE-IN       ( -- byte )             \ Receive byte
    0  8 0 do
        clr-scl ( wait ) set-sda  set-scl ( wait )  bit-in
    loop
    nack-bit
    ;

\ Reading and writing in 24C64 EEPROM
A0 constant EEPROM-ID                   \ EEPROM I2C-chip address

extra definitions

\ Prints -1 if device with address 'addr' is present on I2C-bus otherwise 0.
: I2C?          ( addr -- )
    start-bit  fe and (byte-out)  ack?  stop-bit .
    ;

\ Read next byte from 24C64 EEPROM like COUNT but without address
: NEC@          ( -- b )
    start-bit                           \ Repeated start condition
    eeprom-id 1+ byte-out               \ I2C-chip address for read
    byte-in  stop-bit ;                 \ action from EEPROM

\ Read data x from 24C64 EEPROM byte-address addr. 
: EC@           ( addr -- b )
    begin
        start-bit  eeprom-id (byte-out) \ I2C-chip address for write
    ack? until                          \ Wait for ackbit
    dup >< byte-out                     \ EEPROM address high
    byte-out  nec@ ;                    \ EEPROM address low and read

\ Write data x to 24C64 EEPROM byte-address addr.
: EC!           ( b addr -- )
    begin
        start-bit  eeprom-id (byte-out) \ I2C-chip address for write
    ack? until                          \ Wait for ackbit
    dup >< byte-out  byte-out  byte-out \ Send address and databyte
    stop-bit ;

\ Cell wide read and store operators for EEPROM
: E@            ( addr -- x )   ec@  nec@ ><  or ;
: E!            ( x addr -- )   >r  dup r@ ec!  >< r> 1+ ec! ;
: E+!           ( n addr -- )   >r  r@ e@ +  r> e! ;

\ First cell in EEPROM is used as EHERE, this way it is always up to date
\ We have to take care manually of the forget action on this address pointer
\ Note that EHERE is initialised at address 2 right behind itself!!
\ The error message shows an error in EALLOT !!
0 constant EDP   2 edp e!  ( Define and init. EHERE )
: EHERE         ( -- ea )       edp e@ ;
: .FREE         ( -- )          2000 ehere - . ;
: EALLOT        ( +n -- )       dup ehere + 1FFF u> ?abort  edp e+! ;
: EC,           ( b -- )        ehere  1 eallot  ec! ;
: E,            ( x -- )        ehere  2 eallot  e! ;
: ECREATE       ( -- eaddr )    ehere  constant ;

previous forth definitions
shield eeprom\
freeze
