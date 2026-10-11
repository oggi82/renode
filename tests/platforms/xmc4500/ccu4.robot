*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Test Cases ***
Should Generate 2 Hz PWM With 50 Percent Duty Cycle
    [Documentation]           CCU4_PWM: single shot slice restarted from the period match interrupt through the SCU GSC40 trigger (prescaler 1024, PR 35156, CR 17578 at 72 MHz).
    Create XMC4500 Machine    CCU4_PWM
    Execute Command           machine LoadPlatformDescription @${CURDIR}/ccu4_out0_led.repl
    Create LED Tester         sysbus.port2.pwmLed
    Assert LED Is Blinking    testDuration=3  onDuration=0.25  offDuration=0.25  tolerance=0.01  pauseEmulation=true

Should Toggle LED Once Per Second From Period Match Interrupt
    [Documentation]           CCU4_Timer: period match of CCU40 slice 0 (prescaler 2048, PR 35155) every second sets a flag, main toggles LED1.
    Create XMC4500 Machine    CCU4_Timer
    Create LED Tester         sysbus.port1.led1
    Assert LED Is Blinking    testDuration=4  onDuration=1  offDuration=1  tolerance=0.01  pauseEmulation=true

Should Count Microseconds With Concatenated 32 Bit Timer
    [Documentation]           CCU4_Timer_Concatenation: slice 2 (PR 72 at 72 MHz) clocks slices 0 and 1 (32 bit counter); LED1 is still off after 1.0 s and on at 1.02 s (1000000 counts take 73/72 s).
    Create XMC4500 Machine    CCU4_Timer_Concatenation
    Create LED Tester         sysbus.port1.led1
    Execute Command           emulation RunFor "1.0"
    Assert LED State          false  timeout=0
    Execute Command           emulation RunFor "0.02"
    Assert LED State          true  timeout=0
    ${high}=                  Execute Command  sysbus.ccu40 ReadDoubleWord 0x270
    ${low}=                   Execute Command  sysbus.ccu40 ReadDoubleWord 0x170
    ${value}=                 Evaluate  (int($high.strip(), 16) << 16) | int($low.strip(), 16)
    Should Be True            ${value} > 1000000 and ${value} < 1100000  msg=32 bit counter value ${value}
