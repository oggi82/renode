*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Keywords ***
Read Number
    [Arguments]               ${command}
    ${out}=                   Execute Command  ${command}
    ${value}=                 Evaluate  int($out.strip().split()[-1], 16)
    [Return]                  ${value}

*** Test Cases ***
Should Capture Timer Value At Both Edges Of The PWM Signal
    [Documentation]           CCU8_Capture: slice 1 captures its timer (prescaler 1) at the rising (CV1) and falling edge (CV3) of ST of slice 0; after shortening the PWM to PR 1000 / CR1 500 the signal is high for 501 ticks of prescaler 2048, i.e. 501*2048 modulo the capture period 65501.
    ${uart}=                  Create XMC4500 Machine With UART Tester  CCU8_Capture  uart=sysbus.usic1ch1
    # shorten the PWM (PR 1000, CR1 500) to keep the run short: stop slice 0, clear it, reload through the shadow registers, restart
    Execute Command           emulation RunFor "0.01"
    Execute Command           sysbus WriteDoubleWord 0x40020110 3
    Execute Command           sysbus WriteDoubleWord 0x40020134 1000
    Execute Command           sysbus WriteDoubleWord 0x4002013C 500
    Execute Command           sysbus WriteDoubleWord 0x40020010 1
    Execute Command           sysbus WriteDoubleWord 0x4002010C 1
    Start Emulation
    ${rise}=                  Wait For Line On Uart  Rising edge:\\d+  timeout=30  treatAsRegex=true
    ${fall}=                  Wait For Line On Uart  Falling edge:\\d+  timeout=30  treatAsRegex=true
    ${rise_value}=            Evaluate  int($rise.Line.split(':')[-1])
    ${fall_value}=            Evaluate  int($fall.Line.split(':')[-1])
    ${difference}=            Evaluate  ($fall_value - $rise_value) % 65501
    ${expected}=              Evaluate  (501 * 2048) % 65501
    Should Be True            abs(${difference} - ${expected}) <= 2  msg=capture difference ${difference} (rising ${rise_value}, falling ${fall_value})

Should Vary Duty Cycle Of Symmetric And Asymmetric PWM
    [Documentation]           CCU8_PWM: each period lasts 3.61 ms, the period match interrupt counts 50 periods (about 0.18 s) per step; compare 0 gives a permanently active ST1 (OUT21 = inverted ST1 low), the next step 2500 gives ST1 duty 1 - 2500/65001 for the center aligned slice 2 and the asymmetric slice 3.
    Create XMC4500 Machine    CCU8_PWM
    Execute Command           machine LoadPlatformDescription @${CURDIR}/ccu8_out_leds.repl
    ${symmetric}=                    Create LED Tester  sysbus.port2.out21Led
    ${asymmetric}=                    Create LED Tester  sysbus.port2.out31Led
    Assert LED Duty Cycle     testDuration=0.1  expectedDutyCycle=0  tolerance=0.01  pauseEmulation=true  testerId=${symmetric}
    Execute Command           emulation RunFor "0.3"
    Assert LED Duty Cycle     testDuration=0.05  expectedDutyCycle=0.0385  tolerance=0.005  pauseEmulation=true  testerId=${symmetric}
    Assert LED Duty Cycle     testDuration=0.05  expectedDutyCycle=0.0385  tolerance=0.005  pauseEmulation=true  testerId=${asymmetric}
    ${period}=                Read Number  sysbus.ccu80 ReadDoubleWord 0x330
    Should Be Equal As Integers  ${period}  65000

Should Generate Complementary Outputs With Dead Time
    [Documentation]           CCU8_PWM_Complementary: edge aligned, prescaler 2, PR 720, CR1 360, dead time 22 ticks on both edges: OUT20 is high for (721-360-22)/721, OUT21 (inverted) for (360-22)/721, so the outputs are never high together.
    Create XMC4500 Machine    CCU8_PWM_Complementary
    Execute Command           machine LoadPlatformDescription @${CURDIR}/ccu8_out_leds.repl
    ${high}=                    Create LED Tester  sysbus.port2.out20Led
    ${low}=                    Create LED Tester  sysbus.port2.out21Led
    Execute Command           emulation RunFor "0.001"
    Assert LED Duty Cycle     testDuration=0.01  expectedDutyCycle=0.4702  tolerance=0.003  pauseEmulation=true  testerId=${high}
    Assert LED Duty Cycle     testDuration=0.01  expectedDutyCycle=0.4688  tolerance=0.003  pauseEmulation=true  testerId=${low}
    ${dtc}=                   Read Number  sysbus.ccu80 ReadDoubleWord 0x34C
    Should Be Equal As Integers  ${dtc}  0xD
    ${dc1r}=                  Read Number  sysbus.ccu80 ReadDoubleWord 0x350
    Should Be Equal As Integers  ${dc1r}  0x1616

Should Toggle LED Once Per Period Match Interrupt
    [Documentation]           CCU8_Timer: period match of CCU80 slice 1 (prescaler 1024, PR 58592, 0.833 s) raises SR1 (IRQ 61); main toggles LED1.
    Create XMC4500 Machine    CCU8_Timer
    Create LED Tester         sysbus.port1.led1
    Assert LED Is Blinking    testDuration=4  onDuration=0.8333  offDuration=0.8333  tolerance=0.01  pauseEmulation=true

Should Count With Concatenated 32 Bit Timer
    [Documentation]           CCU8_Timer_Concatenation: slice 2 (PR 72, 72 MHz) clocks slices 0 and 1 (32 bit counter). The count rate and the carry into the high slice are checked, the counter is moved close to one million counts to keep the run short.
    Create XMC4500 Machine    CCU8_Timer_Concatenation
    Create LED Tester         sysbus.port1.led1
    Execute Command           emulation RunFor "0.005"
    ${low}=                   Read Number  sysbus.ccu80 ReadDoubleWord 0x170
    Should Be True            ${low} > 4000 and ${low} < 5000  msg=low slice ${low} after 5 ms
    Assert LED State          false  timeout=0
    # stop both slices, move the counter to 0xFFF0 and let it run over the 16 bit boundary
    Execute Command           sysbus WriteDoubleWord 0x40020110 1
    Execute Command           sysbus WriteDoubleWord 0x40020210 1
    Execute Command           sysbus WriteDoubleWord 0x40020170 0xFFF0
    Execute Command           sysbus WriteDoubleWord 0x40020270 0
    Execute Command           sysbus WriteDoubleWord 0x4002010C 1
    Execute Command           sysbus WriteDoubleWord 0x4002020C 1
    Execute Command           emulation RunFor "0.001"
    ${high}=                  Read Number  sysbus.ccu80 ReadDoubleWord 0x270
    ${low}=                   Read Number  sysbus.ccu80 ReadDoubleWord 0x170
    Should Be Equal As Integers  ${high}  1
    # 1 ms = 986 counts of 73 / 72 us
    Should Be True            ${low} > 0xFFF0 + 984 - 65536 - 4 and ${low} < 0xFFF0 + 988 - 65536 + 4  msg=low slice ${low}
    Assert LED State          false  timeout=0
    # jump above reference + 1000000: the firmware sees the elapsed time and toggles the LED
    Execute Command           sysbus WriteDoubleWord 0x40020110 1
    Execute Command           sysbus WriteDoubleWord 0x40020210 1
    Execute Command           sysbus WriteDoubleWord 0x40020170 0x4240
    Execute Command           sysbus WriteDoubleWord 0x40020270 0x10
    Execute Command           sysbus WriteDoubleWord 0x4002010C 1
    Execute Command           sysbus WriteDoubleWord 0x4002020C 1
    Execute Command           emulation RunFor "0.001"
    Assert LED State          true  timeout=0

Should Start Both Units When The ERU Trigger Arrives
    [Documentation]           CCU8_Timer_Synchronous_Start: CCU80 and CCU81 slice 0 (prescaler 4096, 2.0 s) run from the start, but their interrupts (IRQ 61 and 65) are only enabled by the ERU1 interrupt after BUTTON2; the pending period matches then toggle LED1 and LED2 together (both from on to off), and again 2.0 s later.
    Create XMC4500 Machine    CCU8_Timer_Synchronous_Start
    ${led1}=                    Create LED Tester  sysbus.port1.led1
    ${led2}=                    Create LED Tester  sysbus.port1.led2
    Execute Command           emulation RunFor "3"
    # both timers ran for more than one period, but their interrupts are still disabled in the NVIC
    Assert LED State          true  timeout=0  testerId=${led1}
    Assert LED State          true  timeout=0  testerId=${led2}
    Execute Command           sysbus.port1.button2 PressAndRelease
    Execute Command           emulation RunFor "0.1"
    Assert LED State          false  timeout=0  testerId=${led1}
    Assert LED State          false  timeout=0  testerId=${led2}
    Execute Command           emulation RunFor "2.0"
    Assert LED State          true  timeout=0  testerId=${led1}
    Assert LED State          true  timeout=0  testerId=${led2}

Should Print VADC Result Triggered By The CCU8 Period Match
    [Documentation]           CCU8_TRIGGERED_VADC_MEASUREMENT: CCU80 SR0 (period match every 0.5 s) is VADC gating input M, selected as trigger of the queue; the result is printed and drives LED1 (on for results >= 2047).
    Create XMC4500 Machine With UART Tester  CCU8_TRIGGERED_VADC_MEASUREMENT
    Create LED Tester         sysbus.port1.led1
    Execute Command           sysbus.vadc SetVoltage 0 0 3.0
    Start Emulation
    Wait For Line On Uart     ADC VALUE: 3723  timeout=5
    Assert LED State          true  timeout=1
    Execute Command           sysbus.vadc SetVoltage 0 0 0.5
    Wait For Line On Uart     ADC VALUE: 620  timeout=5
    Assert LED State          false  timeout=1
