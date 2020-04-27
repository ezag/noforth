(* E08 - For noForth C2553 lp.0, C&V version: Interfacing HC-SR04 ultrasonic 
  distance sensor. Port input & output at P1 & P2 with MSP430G2553.

  Address 020 = P1IN    - port-1 input register
  Address 021 = P1OUT   - port-1 output register
  Address 022 = P1DIR   - port-1 direction register
  Address 027 = P1REN   - port-1 resistor enable
  Address 029 = P2OUT   - port-2 output register
  Address 02A = P2DIR   - port-2 direction register

HC-SR04
  Echo = P1.3
  Trig = P1.4

The protocol for this sensor is:
1- Give trigger pulse of at least 10us at 'Trig'.
2- Wait for 'Echo' to go high
3- Wait for 'Echo' to go low while counting the pulselength
4- Convert the resulting number to centimeter

This example is software timed so very much dependant of the
clock frequency and the Forth implementation. Note that:
activated interrupts will influence the result.

The usable range of some Chinese HC-SR04 is only 2cm to 220cm.
 *)

hex
: US-ON     ( -- )
    08 022 *bic     \ P1DIR  P1.3 Input with pullup
    08 027 *bis     \ P1REN
    08 021 *bis     \ P1OUT
    10 022 *bis     \ P1DIR  P1.4 Output
    10 021 *bic     \ P1OUT
    3F 02A *bis ;   \ P2DIR  Six leds

: DISTANCE  ( -- distance in cm )
    10 021 *bis  noop noop noop  10 021 *bic    \ P1OUT  Trigger
    begin  08 020 bit* until                    \ P1IN   Wait for echo
    0  begin  1+  08 020 bit* 0= until          \ P1IN   Measure echo
    dm 20 dm 93 */ ;    ( Scale result to centimeter )

: FLASH     ( -- )  3F 0029 *bis 200 ms  3F 0029 *bic 200 ms ;  \ P2OUT

: MEASURE   ( -- )              \ Show distance in 2 cm steps
    us-on  flash  begin  distance 2/ 29 c!  40 ms  key? until ; \ P2OUT

shield US\  freeze

\ End
