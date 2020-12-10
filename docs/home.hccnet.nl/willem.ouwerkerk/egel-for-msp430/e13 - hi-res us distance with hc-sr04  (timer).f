(* E13 - For noForth C&V 200202: Interfacing ultrasonic distance sensors. 
         Port input & output at P1 & P2 with MSP430G2553.

  Register addresses
020 = P1IN      - Input register
021 = P1OUT     - Output register
022 = P1DIR     - Direction register
023 = P1IFG     - Interrupt flag
024 = P1IES     - Interrupt edge select
025 = P1IE      - Interrupt enable
027 = P1REN     - Resistance on/off
FFE4            - P1 Interrupt vector

Addresses for timer-A0 and timer-A1, when TA0 is already used
and TA1 is free just change the numbers in the source!
Replace 160 by 180 and replace 170 by 190, ready.
160 = TA0CTL   - Timer A0 control
170 = TA0R     - Timer A0 register
180 = TA1CTL   - Timer A0 control
190 = TA1R     - Timer A0 register
00000010.11100100 = 02E4 - TA is nul, overflow mode, SMCLK, presc. /8

For all US-sensors:
  Echo = P1.3
  Trig = P1.4

The protocol for this sensor is:
1- Give trigger pulse of at least 10us at 'Trig'.
2- Wait for 'Echo' to go high
3- Wait for 'Echo' to go low while counting the pulselength
4- Convert the resulting number to millimeter or centimeter

This example is timed by timer-A0 with a microsecond resolution.
When timer-A0 is allready used, just change the numbers as explaned below!

Note that: activated interrupts will not influence the result.
This variant will never hang, it times out after about 65 millisec.

* The usable range of some cheap Chinese HC-SR04 modules is 2cm to 220cm.
  Other variants may have a bigger range. Some shorter...
* The RCW-0001, US-015 and US-100 will range to 350 cm, some even up to 600 cm!
* The shortest range of the RCW-0001 starts at 1 cm, for the US-100 at
  4 cm and the US-015 at 8 cm!
* Remove the jumper at the back of the US-100 when using this protocol.
  Use the file US-100.F when you use the US-100 with jumper attached.
* The HC-SR04, US-015 & need 5 Volt to function properly, the
  US-100 & RCW-0001 will do with 3 to 5 Volt.

User words: US-ON  DISTANCE  MEASURE

 *)

decimal \ Convert microseconds to millimeter or centimeter
\ : >MM       ( u -- mm )     50 291 */ ;
: >CM       ( u -- cm )     5 291 */ ;

hex
: >LEDS     ( x -- )        29 c! ;    \ P2OUT
: FLASH     ( -- )          3F >leds 200 ms  00 >leds 200 ms ;

: US-ON     ( -- )
    08 22 *bic      \ P1DIR  P1.3 Input with pullup
    08 27 *bis      \ P1REN
    08 21 *bis      \ P1OUT
    10 22 *bis      \ P1DIR  P1.4 Output
    10 21 *bic      \ P1OUT
    3F 2A *bis ;    \ P2DIR  Six leds

: TRIGGER   ( -- )      10 21 *bis  noop noop noop  10 21 *bic ; \ P1IN
: START     ( -- )      2E4 160 !  0 170 ! ; \ TA0CTL, TA0R  Start counter
: STOP      ( -- )      30 160 *bic ; \ TA0CTL  Stop counter

: DISTANCE) ( -- -1|microsec )
    trigger                         \ Activate sensor
    begin  08 20 bit* until         \ P1IN   Wait for start of echo pulse
    start                           \ Start counter
    begin
        1 160 bit* if -1 exit then  \ TA0CTL Counter overflow then ready!
    08 20 bit* 0= until             \ P1IN   Wait for echo to end
    stop  170 @ ( Pulselength ) ;   \ TA0R   Stop & read counter

: DISTANCE  ( -- distance in cm )   distance) >cm ;

: MEASURE   ( -- )              \ Show distance in steps of 2 cm
    us-on  flash  begin  distance 2/ >leds  40 ms  key? until ;

shield US\  freeze

\ End
