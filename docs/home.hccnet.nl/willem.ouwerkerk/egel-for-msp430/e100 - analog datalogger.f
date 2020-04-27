(* E100 - Datalogger, analog to digital conversion with onboard ADC, storage of the
  data and on an MSP430 Launchpad, then sending the data wireless to a PC
  for noForth C&V2553 lp.0, Port output with MSP430G2553 at port-2.
  The datalogger takes every second a sample and after 20 samples the
  data is sent thru Bluetooth to a receiving computer

  * Port-2 must be wired to 8 leds, placed on the launchpad experimenters kit.
  Wire P2.0 to P2.7 to the anode of eight 3mm leds placed on the breadboard 
  the pinlayout can be found in the hardwaredoc of the launchpad. Connect
  all kathodes to each other, and connect them to ground using a 100 Ohm 
  resistor.

  * P1.7 is used as analog input, it is wired to an LDR and resistor to 3,3V
  and ground )
  
  For Bluetooth two jumpers need to be removed, the TX and RX jumpers at J3 
  Connect the power for the HC06 {pin12+13} with Launchpad J6 {VCC+GND}, 
  TX & RX from HC06 {pin1+2} with Launchpad J1 {pin3+4}

  0029 = P2OUT      - port-2 output with 8 leds
  002A = P2DIR      - port-2 direction register
  002E = P2SEL      - port-2 selection register
  004A = ADC10AE0   - ADC analog enable 0
  01B0 = ADC10CTL0  - ADC controle register 0
  01B2 = ADC10CTL1  - ADC controle register 1
  01B4 = ADC10MEM   - ADC memory
 *)

hex
\ Print number u with 4 digits and two spaces behind it
: .DATA     ( u -- )    0 <# # # # # #>  type space space ;
: >LEDS     ( b -- )    029 c! ; \ P2OUT
: BOP       ( -- )      041 021 *bis  5 ms  041 021 *bic ; \ P1OUT

\ ADC on and sample time at 64 clocks
: ADC-SETUP ( -- )
    02 1B0 *bic               \ ADC10CTL0  Clear ENC
    80 04A c!                 \ ADC10AE0   P1.7 = ADC in
    1810 1B0 ! ;              \ ADC10CTL0  Sampletime 64 clocks, ADC on
   
\ We need to clear the ENC bit before setting a new input channel
: ADC       ( +n -- u )
    02 1B0 *bic               \ ADC10CTL0  Clear ENC
    F000 and 80 or 1B2 !      \ ADC10CTL1  Select input, MCLK/5
    03 1B0 *bis               \ ADC10CTL0  Set ENC & ADC10SC
    begin 1 1B2 bit* 0= until \ ADC10CTL1  ADC10 busy?
    1B4 @  ;                  \ Read result

: FLASH       ( -- )          \ Visualise startup
    -1 >leds  100 ms          \ All leds on
    00 >leds  100 ms ;        \ All leds off

: SHOW 		( u -- )          \ Show with VU- or thermometer scale
    080 /mod                  \ Scale value for 8 leds
    swap 3F >  -              \ Round to next higher value
    dup if                    \ Result greater than zero?
        1 swap 1- lshift      \ Yes, make led position
        dup 1-  or            \ Fill lower bits
    then
    >leds ;                   \ Data to leds

: SAMPLE-ADC    ( -- u )      \ Every tenth AD-conversion is placed on stack
    0                         \ Dummy result 
    0A 0 do                   \ Show ten samples on the leds
        drop                  \ Remove previous AD-conversion
        7000 adc  dup show    \ Read ADC input 7 and show on leds
        bop  095 ms           \ Flash led & wait 1/10 sec.
    loop ;

create DATA  14 cells allot   \ Space for 20 samples

\ Send samples back in two lines of each 10 samples
: SEND-SAMPLES      ( -- )
    2 0 do
        cr  0A 0 do
            j 0A *  i 2* +    \ Calc. position
            data + @ .data    \ To cell, fetch data and send
        loop
    loop ;

: DATALOGGER    ( -- )              \ Single channel analog datalogger
    -1 02A c!  0 02E c!             \ P2DIR, P2SEL  Make P2 all outputs
    adc-setup  flash  decimal
    cr ." ADC to RS232 data logger" \ Startup message
    flash 
    begin
        cr  14 0 do                 \ Save 20 samples
            sample-adc              \ Read ADC and show on LEDS
            I 2* data + !           \ Save sample I
        loop
        send-samples
    key? until
    0 >leds ;                       \ Leds off

' datalogger to app  freeze

						( End )
