(* E03 - For noForth C&V2553 lp.0, Port output with MSP430G2553 at port-2.
  Analog to digital conversion with onboard ADC on MSP430 Launchpad.

  * Port-2 must be wired to 8 leds, placed on the launchpad experimenters kit.
  Wire P2.0 to P2.7 to the anode of eight 3mm leds placed on the breadboard
  the pinlayout can be found in the hardwaredoc of the launchpad. Connect
  all kathodes to each other, and connect them to ground using a 100 Ohm
  resistor.

  * P1.5 and P1.7 are used as analog input, it is wired to a 4k7 potmeter or
    joystick to 3,3 Volt and ground. For the joystick P1.3 is switch input.

  * More info about the ADC10, in SLAU144J.PDF on page 533 and beyond.
    Short documentation about ADC10:

  This a rewritten version of ADC10 single conversion implementation.
  It has to be tested if this version is more robust!

  Note that to do a correct conversion and/or improve the speed,
  the correct sample time must be selected. The formula is:

  tsample > (RS + 2000) x 7.625 x 27 pF

  Example with RS = 10 kOhm:
   (10000 + 2000) x 7.625 x 27*10-9 = 2.47µsec.

  With DCO = 8 MHz and ADC clock divider = 3
  The ADC clock source is 8000000/3 = 2.67 MHz
  One ADC clock tick = 1000000/2666666=0.375 µsec.
  With a calculated minimum sample time of 2.47 µsec the minimal
  sample & hold time should be set to: 2.47/.375 = 6.59 ADC10CLKs
  We may select 00 = 04 ADC10 clocks
                01 = 08 ADC10 clocks  (this one satisfies)
                10 = 16 ADC10 clocks
                11 = 64 ADC10 clocks

  When we change the ADC10 clock, the sample and hold selection
  must be change too. Note that the ADC10 clock is maximal 6.3 MHz
  with ADC10SR=0 and 1.5 MHz with ADC10SR=1

  Address 020 = P1IN, port-1 input register
  Address 021 = P1OUT, port-1 output register
  Address 022 = P1DIR, port-1 direction register
  Address 027 = P1REN, port-1 resistor enable register
  Address 029 - P2OUT, port-2 output with 8 leds
  Address 02A - P2DIR, port-2 direction register
  Address 02E - P2SEL, port-2 selection register
  Address 04A - ADC10AE0, ADC analog enable 0
  Address 1B0 - ADC10CTL0, ADC controle register 0
  Address 1B2 - ADC10CTL1, ADC controle register 1
  Address 1B4 - ADC10MEM, ADC memory
 *)

hex
: >LEDS  ( b -- )  029 c! ;   ( P20UT )

\ ADC on and sample & hold time at 8 ADC10 clocks
: SETUP-ADC ( -- )
    12 1B0 **bic                \ ADC10CTL0  Deactivate ADC & clear ENC
    10 1B0 **bis                \ ADC10CTL0  Activate ADC
    A0 04A c!                   \ ADC10AE0   P1.5 & P1.7 are ADC in
    1010 1B0 ! ;                \ ADC10CTL0  T-sample 8 ADC10 clocks,
                                \            ADC on & Vref = VCC

\ We need to clear the ENC bit before setting a new input channel
: ADC       ( +n -- u )
    02 1B0 **bic                \ ADC10CTL0  Clear ENC
    F000 and 40 or 1B2 !        \ ADC10CTL1  Select input, MCLK/3
    03 1B0 **bis                \ ADC10CTL0  Set ENC & ADC10SC
    begin 4 1B0 bit** until     \ ADC10CTL0  ADC10 ready?
    1B4 @                       \ ADC10MEM   Read result
    4 1B0 **bic ;               \ ADC10CTL0  Mark conversion done

: POTMETER      7000 adc ;    ( Read level at P1.7 )

: SHOW      ( u -- )          ( Show with VU- or thermometer scale )
    80 /mod                   ( Scale value for 8 leds )
    swap 3F >  -              ( Round to next higher value )
    dup if                    ( Result greater than zero? )
        1 swap 1- lshift      ( Yes, make led position )
        dup 1-  or            ( Fill lower bits )
    then
    >leds ;                   ( Data to leds )

: FLASH       ( -- )          ( Visualise startup )
    -1 >leds  100 ms          ( All leds 250 ms on )
    00 >leds  100 ms          ( All leds 250 ms off )
    ;

: SHOW-ADC1   ( -- )          ( Show conversion on leds )
    -1 02A c!  0 02E c!       ( P2DIR, P2SEL Make P2 all outputs )
    setup-adc  flash
    begin
        potmeter 10 / >leds   ( Read ADC and show binary result )
    key? until
    00 >leds ;                ( Leds off )

: SHOW-ADC2      ( -- )       ( Show conversion on leds )
    -1 02A C!  0 02E C!       ( P2DIR, P2SEL Make P2 all outputs )
    setup-adc  flash
    begin
        potmeter show         ( Read ADC and show VU-result )
    key? until
    00 >leds ;                ( Leds off )

: SHOW-ADC3      ( -- )       ( P2DIR, P2SEL Show conversion on leds )
    setup-adc
    begin
        potmeter .            ( Read ADC and show result on screen )
    key? until ;

: JOYSTICK      ( -- )        ( Toggle between two potmeters using a switch )
    setup-adc
    08 22 *bic  08 27 *bis    ( P1.3 is input with pullup resistor )
    08 21 *bis
    begin
        5000                  ( P1.5 ADC address )
        08 20 bit* if         ( Switch pressed? )
            2000 +            ( Yes, convert to P1.7 ADC address )
        then
        adc .                 ( Read selected ADC and show result on screen )
    key? until ;

freeze
                        ( End )
