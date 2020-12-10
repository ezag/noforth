(* E112A - For noForth C&V 200202 or later:  RS232 via USB or Bluetooth in-
   and output.
   Use Bluetooth instead of USB serial connection... for MSP430F149 version-D. 
   Switch KEY? KEY and EMIT between Bluetooth and USB, note that the code is for 
   noForth version-D, uart0 is USB and uart1 is used for Bluetooth

  29 - P2OUT    - Port-2 with 8 leds
  2A - P2DIR    - Port-2 direction
  1B - P3SEL    - Port-3 function select
  00 - IE1      - Interrupt enable 1
  03 - IFG2     - Interupt Flag register 2
  04 - ME1      - Module enable 0
  05 - ME2      - Module Enable 2
** All uart-0 registers are on addresses 8 below uart-1 **
  78 - U1CTL    - Uart-1 control
  79 - 1TCTL   - Uart-1 transmit control
  7B - U1MCTL   - Uart-1 modulation control
  7C - U1BR0    - Uart-1 baudrate 0
  7D - U1BR1    - Uart-1 baudrate 1
  7E - U1RXBUF  - Uart-1 receive buffer
  7F - U1TXBUF  - Uart-1 transmit buffer
 *)

hex
\ UART0 version A
: 19K2A       ( -- )    A0 74 c!  01 75 c!  5B 73 c!  01 70 *bic ;
: 38K4A       ( -- )    D0 74 c!  00 75 c!  11 73 c!  01 70 *bic ;
: 115K2A      ( -- )    45 74 c!  00 75 c!  AA 73 c!  01 70 *bic ;
\ UART1 version B
: 19K2B       ( -- )    A0 7C c!  01 7D c!  5B 7B c!  01 78 *bic ;
: 38K4B       ( -- )    D0 7C c!  00 7D c!  11 7B c!  01 78 *bic ;
: 115K2B      ( -- )    45 7C c!  00 7D c!  AA 7B c!  01 78 *bic ;

(* CODE USB-SETUP      ( -- )
    30 # 01B & .b bis     \ Use Uart-0
    C0 # 004 & .b mov     \ Uart-0 on
    10 # 070 & .b bis     \ 8-bit characters
    20 # 071 & .b bis     \ Uclk = SMclk
    D0 # 074 & .b mov     \ 8 MHz: baudrate 38400
    00 # 075 & .b mov
    11 # 073 & .b mov     \ Adjust modulation
    #1 070 & .b bic       \ Init. UART
    #0 000 & .b mov       \ Erase interrupt flags
    next
end-code
 *)

CODE USB-SETUP      ( -- )
    C0 # 01B & .b bis     \ Use Uart-1
    30 # 005 & .b mov     \ Uart-1 on
    10 # 078 & .b bis     \ 8-bit characters
    20 # 071 & .b bis     \ Uclk = SMclk
\   41 # 07C & .b mov     \ 8 MHz: baudrate 9600
\   03 # 07D & .b mov
\   09 # 07B & .b mov     \ Adjust modulation
    D0 # 07C & .b mov     \ 8 MHz: baudrate 38400
    00 # 07D & .b mov
    11 # 07B & .b mov     \ Adjust modulation
    #1 078 & .b bic       \ Init. UART
    next
end-code

CODE EMIT}          ( c -- )
    begin,  20 # 003 & .b bit  cs? until,
    tos 07F & .b mov  sp )+ tos mov  next
end-code

CODE KEY}           ( -- c )
    begin,  10 # 003 & .b bit  cs? until,
    tos sp -) mov  07E & tos .b mov  next
end-code

CODE KEY?}          ( -- f )
    tos sp -) mov  10 #  003 & .b bit
    #0 tos mov  cs? if,  #-1 tos mov  then,  next
end-code

inside
: BLUETOOTH         ( -- )      \ Use uart-0 for Bluetooth 9600B
    ['] emit)  to 'emit
    ['] key?) to 'key?
    ['] key) to 'key
    ;

: USB               ( -- )      \ Use uart-1 for USB 38400B
    usb-setup
    ['] emit} to 'emit
    ['] key?} to 'key?
    ['] key} to 'key
    ;

\ ' usb  to app                   \ Startup in 38K4 USB mode
usb  forth  freeze

\ End
