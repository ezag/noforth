(* E112C - For noForth C&V 200202 or later: Control 2 x 10 servos by using 
   two timer interrupts. It trades RAM and free registers for processor cycles,
   that should be no problem because we have 2 kByte RAM on a MSP430F149. 
   Ram usage 2xx bytes, codespace 9xx bytes excluding the random test code
   and excluding MSP430 assembler!!
   
   This routine runs on the MSP430F149 robot board 
*)

hex
inside also definitions

\ Divide 8.000.000/8 = 1 MHz
\ So the timer clock input pulse is 1 microsec.
\    FEDCBA9876543210 bit-numbers
\ BN 0000001011010100 constant #CONFIG \ 02D4 TA=0, count up, SMCLK, presc /8

\ Adresses for Timer-A3
\ 160 constant TA3CTL     \ Timer A3 control
\ 162 constant TA3CCTL0   \ Timer A3 Comp/Capt. control 0
\ 172 constant TA3CCR0    \ Timer A3 Comp/Capt. 0
\ Adresses for Timer-B7
\ 180 constant TB7CTL     \ Timer B7 control
\ 182 constant TB7CCTL0   \ Timer B7 Comp/Capt. control 0
\ 192 constant TB7CCR0    \ Timer B7 Comp/Capt. 0
\
\ 021 constant P1OUT      \ P1 output register
\ 022 constant P1DIR      \ P1 direction register
\ 029 constant P2OUT      \ P2 output register
\ 02A constant P2DIR      \ P2 direction register
\ 019 constant P3OUT      \ P3 output register
\ 01A constant P3DIR      \ P3 direction register
\ 01D constant P4OUT      \ P4 output register
\ 01E constant P4DIR      \ P4 direction register
\ 031 constant P5OUT      \ P5 output register
\ 032 constant P5DIR      \ P5 direction register

: VARIABLES    create cells allot  does> @ swap cells + ;

\ Software 256 UM/ hardcoded
\ d c b a ->  c b
code 256UM/     ( plo phi -- u )
    #-1 tos .b and> \ Save lo-byte (c)
    tos swpb        \ lo -> hi
    sp )+ day mov   \ Get lo
    day swpb        \ hi -> lo
    #-1 day .b and> \ Save lo-byte (b)
    day tos bis     \ Put together (c b)
    next
end-code

\ I/O-addres and bit-nr for 20 outputs
\ Separated here over 4 bits of P1, P2 and P5
create #PORTDATA    ( -- adr )
0121 , 0221 , 4021 , 8021 , 0129 , 0229 , 0429 , 0829 , ( P1, P2 )
1029 , 2029 , 4029 , 8029 , 0131 , 0231 , 0431 , 0831 , ( P2, P5 )
1031 , 2031 , 4031 , 8031 ,  align  ( P5 )

\ The below example shows two filled locations of the workspace, each location
\ consists of 2 cells. A cell contains all the data for setting an clearing 
\ bits to generate servo pulses. The second cell contains the pulselength.
\ A double bar separates entry's a single bar separates data cells.
\ workspace: 
\ Pulses:  || Bit-data | time-1 || Bit-data | time-2 || Etc.
\ Bit-data: | port-addr | bitmap |
014 variables S'BEGIN       \ Space for 20 begin-positions
014 variables S'END         \ Space for 20 end-positions
028 variables SERVOS        \ Space for 20 times port-data & servo positions

( Tuned numbers for every MG90 servo, may be corrected )
ecreate #begin 
  029E e,  029E e,          \ Kop  
  0271 e,  02DA e,  0320 e, \ Poot4 = 1
  029E e,  028A e,  02A8 e, \ Poot5 = 2
  028A e,  028A e,  029E e, \ Poot6 = 3
  02D0 e,  02EE e,  0276 e, \ Poot1 = 4
  028A e,  02E9 e,  02EE e, \ Poot2 = 5
  02E4 e,  02BC e,  02BC e, \ Poot3 = 6
ecreate #end
  0988 e,  0988 e,          \ Kop
  08E8 e,  09E2 e,  0988 e, \ Poot4 = 1
  0924 e,  091F e,  0988 e, \ Poot5 = 2
  0942 e,  0910 e,  08FC e, \ Poot6 = 3
  0988 e,  0988 e,  0924 e, \ Poot1 = 4
  092E e,  09CE e,  09F6 e, \ Poot2 = 5
  09A6 e,  094C e,  0988 e, \ Poot3 = 6
hex

\ Fill both tables with valid start values, from EEPROM
\ so we can use all servo's full range. Then initialise
\ the SERVOS table with port-data for all 20 used outputs.
\ And finally set default servo position of 1.5 ms to SERVOS table.
: SET-SERVODATA  ( -- )
    014 0 do  i cells #begin + e@  i s'begin !  loop
    014 0 do  i cells #end + e@  i s'end !  loop 
    014 0 do  i cells #portdata + @  i 2* servos !  loop
    014 0 do  dm 1500  i 2* servos cell+ !  loop 
    ;

\ Calculate timer value t from position u for servo s
: SCALE         ( u s -- t ) \ Scale max. servo range
    >r  r@ s'end @           \ Get end position
    r> s'begin @  >r  r@ -   \ Subtract begin position from it
    um*  256um/  r> + ;      \ Scale & build timer value


\ Store a new pulselength for SERVO s
: PULSE!    ( pulse s -- )    2* servos cell+  ! ;

extra definitions
: RANGE         ( u1 s1 -- u2 s2 ) 013 umin >r  0FF umin  r> ;

\ Set servo position in steps from 0 to 255
\ Set a pulselength from s'begin MS to s'end MS
\ The data is secured to the maximal allowed range
: SERVO     ( u s -- )    range >r  r@ scale  r> pulse! ;
inside definitions

: ZERO-SERVOS   ( -- )  14 0 do  80 i servo  16 ms  loop ;

\ Set new begin and end values for servo 'servo-nr'
: LIMITS        ( begin end servo-nr -- )
    2* >r  r@ #end + e!  r> #begin + e!  
    set-servodata  zero-servos ;

\ Show content of record +n in the SERVOS table and the whole table
: X.        ( x -- )    base @ hex  swap 0 <# # # # # #> type space  base ! ;
: W.        ( +n -- )   2* servos  @+ x.  @ x. ;
: T.        ( -- )      14 0 do  cr i x. space   i w.  loop  cr ;

: L.        ( -- )      \ Show stored servo limits
    14 0 do
        cr i .  
        i cells #begin + e@ u.
        i cells #end + e@ u.
    loop ;

\ The error margin in the generated pulses is maximal 4.5 microseconds
\ Exclusive registers: XX=addr pointer and ZZ=workregister
\ Code needs 36 cycles and uses 32 bytes code.
\ The CPU overhead is about 0.8% to 0.25% using pulses from .6 to 2 ms.
\ The servo repeat frequency changes from 45 Hz to 170 Hz, average 70 Hz.
\ This routine handles the pulses for the first ten servomotors.
code PULSEGEN1  ( -- )          \ 6 for timer-interrupt
    xx )+ zz .b mov             \ 2 - 1 Load previous port-addr
    xx )+ zz ) .b bic           \ 5 - 2 Clear previous servo bit
    #2 xx add                   \ 1 - 1 Skip pulse time
    014 servos # xx cmp         \ 2 - 2 Yes, halfway table check
    =? if,                      \ 2 - 1 Pointer after halfway SERVOS?
        0 servos # xx mov       \ 2 - 2 Yes, pointer to start of SERVOS
    then,
    xx )+  zz .b mov            \ 2 - 1 Load current port-addr
    xx )+ zz ) .b bis           \ 5 - 2 Set current servo bit
    xx )+ 0172 & mov            \ 5 - 2 Set current pulse time
    #4 xx sub                   \ 1 - 1 Correct pointer
    reti                        \ 5 - 1
end-code

\ Exclusive registers: YY=addr pointer and ZZ=workregister
\ Code needs 36 cycles and uses 32 bytes code.
\ The CPU overhead is about 0.8% to 0.25% using pulses from .6 to 2 ms.
\ The servo repeat frequency changes from 45 Hz to 170 Hz, average 70 Hz.
\ This routine handles the pulses for the second ten servomotors.
code PULSEGEN2  ( -- )      \ 6 for timer-interrupt
    yy )+ zz .b mov             \ 2 - 1 Load previous port-addr
    yy )+ zz ) .b bic           \ 5 - 2 Clear previous servo bit
    #2 yy add                   \ 1 - 1 Skip pulse time
    028 servos # yy cmp         \ 3 - 2 Yes, end of table check
    =? if,                      \ 2 - 1 Pointer after SERVOS?
        014 servos # yy mov     \ 2 - 2 Yes, pointer to middle of SERVOS
    then,
    yy )+ zz .b mov             \ 2 - 1 Load current port-addr
    yy )+ zz ) .b bis           \ 5 - 3 Set current servo bit
    yy )+ 0192 & mov            \ 5 - 3 Set current pulse time
    #4 yy sub                   \ 1 - 1 Correct pointer
    reti                        \ 5 - 1
end-code

\ Load the workregister XX and YY for the servo interrupt to start properly
code SERVO-SETUP    ( -- )
    00 servos # xx mov          \ 2 - 2 Load servos pointer 1
    14 servos # yy mov          \ 2 - 2 Load servos pointer 2
    next                        \ x - 1 and interrupt ready.
end-code

code INTERRUPT-ON      #8 sr bis  next  end-code
code INTERRUPT-OFF     #8 sr bic  next  end-code

forth definitions
\ First timer-A3
: TA-ON         ( -- )
    000  0160 !             \ Stop timer-A3
    DM 1000  0172 !         \ First interrupt after 1 ms
    02D4  0160 !            \ Start timer
    010  0162 ! ;

\ Second timer-B7
: TB-ON         ( -- )
    000  0180 !             \ Stop timer-B7
    DM 0500  0192 !         \ First interrupt after .5 ms
    02D4  0180 !            \ Start timer
    010  0182 ! ;           \ Set compare 0 interrupt on

\ Configure SERVO's at the ports Px,y etc.
: SERVO-ON      ( -- )
( ) 0FF  022 *bis           \ Bit P1.0 & P1.7 outputs
    00F  01A *bis           \ Bit P3.0 t/m P3.3 outputs
    0FF  02A *bis           \ Bit P2.0 t/m P2.7 outputs
    0FF  032 *bis           \ Bit P5.0 t/m P5.7 outputs
    servo-setup  set-servodata \ Set all default servo values
\   TA-ON  2000 MS          \ First timer-A3
\   TB-ON                   \ Second timer-B7
    usb-setup               \ Activate uart-1 too
    interrupt-on ;          \ Activate

: SERVO-OFF     ( -- )
    000  0160 !             \ Stop timer-A3
    010  0162 **bic         \ Interrupts off
    000  0180 !             \ Stop timer-B7
    010  0182 **bic         \ Interrupts off
    interrupt-off           \ Deactivate
    ;

' pulsegen1 >body  FFEC vec!  \ Install vectors
' pulsegen2 >body  FFFA vec!  \ Install vectors
previous forth definitions
decimal  ( ' servo-on to app )  
shield servos\  freeze

\ End
 