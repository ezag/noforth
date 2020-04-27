(* Change DCO frequency and or baudrate for MSP430G2553

NOTE THIS WORKS ONLY FROM NOFORTH VERSIONS FROM 2018 AND LATER!!!

This table is stored in info FLASH at address FROZEN2
The documented table is the default table!
A few examples are shown below, just fiddle with the backslashes

The address of FROZEN2 is at ' FROZEN 2 cells + @
It is stored right behind the value of FROZEN, but without header!

Address  Offset     Function
----------------------------------------------------------
10B2     00     Milliseconds tuning value, see table below
10B4     02     FCTL2, Flash controller clock divider
10B6     04     DCOCTL & BCSCTL1, Low byte of 8 MHz DCO settings address
                Add 1000 to it and we get the real address
10B7     05     Port bit mask for switch S?
10B8     06     PxIN, Port address for S?
10BA     08     UCA0BR0, low byte Baud rate
10BB     09     UCA0BR1, high byte Baud rate
10BC     0A     UA0MCTL, Baudrate tuning
10BD     0B     Empty
10BE     0C     Empty
10BF     0D     Empty

MS is built into noForth and uses the value from the first
parameter cell stored at FROZEN2, The value /MS may be used
for a word that delays 1/10 millisec each step. The value at
//MS may be used for a word that delays 1/100 millisec. each
step! Note that you may use the value from the table divided
by 10 for defining /MS or 100 for //MS
All these values are in decimal!

            MS      /MS     //MS
    Clock   MOON    moon    moon
    20 mhz  4999    499     49
    16 mhz  3999    399     39
    8 mhz   1999    199     19
    4 mhz   999     99      9
    2 mhz   499     49      4
    1 mhz   249     24      -
    8 khz   1       -       -

*)

create BUFFER
\    ms,   flash,  DCO, Bitmask,  Port,     Baud,        ... for MSP-EXP430G
\ Baudrate = 9600, P1.3 = switch,
\   00F9 ,  A542 ,  FE c,  08 c,  0020 ,  0068 ,  02 c,  FF c,  FFFF ,  \ 1 MHz
\   07CF ,  A550 ,  FC c,  08 c,  0020 ,  0341 ,  04 c,  FF c,  FFFF ,  \ 8 MHz
    0F9F ,  A562 ,  F8 c,  08 c,  0020 ,  0682 ,  06 c,  FF c,  FFFF ,  \ 16 MHz

\ Parameter data for Egel kit & Micro Launchpad: Baudrate = 38K4, P1.3 = switch
\   00F9 ,  A542 ,  FE c,  08 c,  0020 ,  001A ,  00 c,  FF c,  FFFF ,  \ 1 MHz
\   07CF ,  A550 ,  FC c,  08 c,  0020 ,  00D0 ,  06 c,  FF c,  FFFF ,  \ 8 MHz
\   0F9F ,  A562 ,  F8 c,  08 c,  0020 ,  01A0 ,  0C c,  FF c,  FFFF ,  \ 16 MHz

v: inside
: PATCH     ( -- )
    frozen  here  [ 40 0E - ] literal  tidy)
    buffer  [ ' frozen >body cell+ @ ] literal  0E rommove ;
v: forth

patch

\ End
