*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Variables ***
${NVIC_ISER0}                 0xE000E100
${ERU0_EXICON1}               0x50004814
# ERU0 input A1 of channel 1 (ERU0.1A1) is SCU.HIB_SR0, numbered channel*8 + 1
${ERU0_1A1}                   9

*** Keywords ***
Run For
    [Arguments]               ${seconds}
    Execute Command           emulation RunFor "${seconds}"

Read Word
    [Arguments]               ${address}
    ${value}=                 Execute Command  sysbus ReadDoubleWord ${address}
    [Return]                  ${value.strip()}

Symbol Value
    [Documentation]           Reads the 32 bit variable with the given name from the firmware.
    [Arguments]               ${symbol}
    ${address}=               Execute Command  sysbus GetSymbolAddress "${symbol}"
    ${value}=                 Read Word  ${address.strip()}
    ${number}=                Convert To Integer  ${value}
    [Return]                  ${number}

Wait For NVIC Interrupt Enabled
    [Documentation]           The examples enable their interrupt last, right before the endless loop. Needs a running emulation.
    [Arguments]               ${irq}
    Wait Until Keyword Succeeds  20x  0.2s  NVIC Interrupt Is Enabled  ${irq}

NVIC Interrupt Is Enabled
    [Arguments]               ${irq}
    ${enabled}=               Read Word  ${NVIC_ISER0}
    ${set}=                   Evaluate  (int($enabled, 16) >> ${irq}) & 1
    Should Be Equal As Integers  ${set}  1

*** Test Cases ***
GPIO Toggle Blinks LED1 With 0.5 Hz
    [Documentation]           GPIO_Toggle: P1.1 is configured as output and toggled with XMC_GPIO_ToggleOutput (Pn_OMR) once a second from SysTick.
    Create XMC4500 Machine    GPIO_Toggle
    Create LED Tester         sysbus.port1.led1  defaultTimeout=2
    Start Emulation
    Assert LED Is Blinking    testDuration=6  onDuration=1  offDuration=1  tolerance=0.1  pauseEmulation=true

GPIO Port Registers Behave Like The Reference Manual
    [Documentation]           Reset values, pull devices, Pn_OMR set/reset/toggle and the pad levels seen by the peripherals, checked with plain register accesses.
    Create XMC4500 Machine    Empty_XMC_App
    # reset values: HWSEL of P0 (debug pins), PDR, PDISC (pads of pins that are not bonded out are disabled)
    ${v}=                     Read Word  0x48028074
    Should Be Equal As Integers  ${v}  0x00014000  base=16
    ${v}=                     Read Word  0x48028040
    Should Be Equal As Integers  ${v}  0x22222222  base=16
    ${v}=                     Read Word  0x48028060
    Should Be Equal As Integers  ${v}  0x0000E000  base=16
    ${v}=                     Read Word  0x48028E60
    Should Be Equal As Integers  ${v}  0x0000FFFF  base=16
    # P3.0 as push-pull output: OUT is mirrored to IN, OMR sets, resets and toggles
    Execute Command           sysbus WriteDoubleWord 0x48028310 0x80
    Execute Command           sysbus WriteDoubleWord 0x48028304 0x1
    ${v}=                     Read Word  0x48028324
    Should Be Equal As Integers  ${v}  0x1  base=16
    Execute Command           sysbus WriteDoubleWord 0x48028304 0x10000
    ${v}=                     Read Word  0x48028324
    Should Be Equal As Integers  ${v}  0x0  base=16
    Execute Command           sysbus WriteDoubleWord 0x48028304 0x10001
    ${v}=                     Read Word  0x48028300
    Should Be Equal As Integers  ${v}  0x1  base=16
    Execute Command           sysbus WriteDoubleWord 0x48028304 0x10000
    # P3.1 as input: pull-up reads 1, pull-down and no pull device read 0 while nothing drives the pad, a driven pad wins over the pull device
    Execute Command           sysbus WriteDoubleWord 0x48028310 0x1080
    ${v}=                     Read Word  0x48028324
    Should Be Equal As Integers  ${v}  0x2  base=16
    Execute Command           sysbus WriteDoubleWord 0x48028310 0x0880
    ${v}=                     Read Word  0x48028324
    Should Be Equal As Integers  ${v}  0x0  base=16
    Execute Command           sysbus WriteDoubleWord 0x48028310 0x0080
    ${v}=                     Read Word  0x48028324
    Should Be Equal As Integers  ${v}  0x0  base=16
    Execute Command           sysbus.port3 OnGPIO 1 true
    Execute Command           sysbus WriteDoubleWord 0x48028310 0x0880
    ${v}=                     Read Word  0x48028324
    Should Be Equal As Integers  ${v}  0x2  base=16
    # P14 is an analog port: the digital pad input is only active once PDISC is cleared; the pad is driven from the outside
    Execute Command           sysbus.port14 OnGPIO 2 true
    ${v}=                     Read Word  0x48028E24
    Should Be Equal As Integers  ${v}  0x0  base=16
    Execute Command           sysbus WriteDoubleWord 0x48028E60 0xFFFB
    ${v}=                     Read Word  0x48028E24
    Should Be Equal As Integers  ${v}  0x4  base=16

ERU Extint Toggles LED1 On Every Falling Edge Of Button2
    [Documentation]           ERU_EXTINT: button 2 (P1.15) feeds ERU1 input ERU1.1A0, the falling edge (release of the active-high button) raises OGU0 and ERU1_0_IRQHandler toggles LED1.
    Create XMC4500 Machine    ERU_EXTINT
    Create LED Tester         sysbus.port1.led1  defaultTimeout=2
    Start Emulation
    Wait For NVIC Interrupt Enabled  5
    Assert LED State          false  timeout=0.1
    Execute Command           sysbus.port1.button2 Press
    # the handler runs on the falling edge only
    ${count}=                 Symbol Value  interrupt_event_count
    Should Be Equal As Integers  ${count}  0
    Execute Command           sysbus.port1.button2 Release
    Assert LED State          true  timeout=1
    ${count}=                 Symbol Value  interrupt_event_count
    Should Be Equal As Integers  ${count}  1
    Execute Command           sysbus.port1.button2 PressAndRelease
    Assert LED State          false  timeout=1
    ${count}=                 Symbol Value  interrupt_event_count
    Should Be Equal As Integers  ${count}  2

ERU Extint Ignores Button1
    [Documentation]           P1.14 (button 1) is not an input of the ERU in the LQFP-100 package, so pressing it must not cause an interrupt.
    Create XMC4500 Machine    ERU_EXTINT
    Create LED Tester         sysbus.port1.led1  defaultTimeout=2
    Start Emulation
    Wait For NVIC Interrupt Enabled  5
    Execute Command           sysbus.port1.button1 PressAndRelease
    Sleep                     0.5s  reason=negative check: no interrupt may arrive
    ${count}=                 Symbol Value  interrupt_event_count
    Should Be Equal As Integers  ${count}  0

ERU HIB IO Stops Blinking On Falling Edge At ERU0 Input 1A1
    [Documentation]           ERU_HIB_IO: LED1 blinks until the ERU0 status flag FL of channel 1 is set by a falling edge of ERU0.1A1 (SCU.HIB_SR0).
    ...                       The hibernate domain (HIB_IO_1 pin to HIB_SR0) belongs to the scu-wdt-rtc component, the edge is injected at the ERU input instead.
    Create XMC4500 Machine    ERU_HIB_IO
    Create LED Tester         sysbus.port1.led1  defaultTimeout=2
    Start Emulation
    Assert LED Is Blinking    testDuration=4  onDuration=0.5  offDuration=0.5  tolerance=0.1  pauseEmulation=true
    ${flag}=                  Read Word  ${ERU0_EXICON1}
    ${fl}=                    Evaluate  int($flag, 16) & 0x80
    Should Be Equal As Integers  ${fl}  0
    # a rising edge alone does not set the flag (falling edge detection), the falling edge does
    Execute Command           sysbus.eru0 OnGPIO ${ERU0_1A1} true
    ${flag}=                  Read Word  ${ERU0_EXICON1}
    ${fl}=                    Evaluate  int($flag, 16) & 0x80
    Should Be Equal As Integers  ${fl}  0
    Execute Command           sysbus.eru0 OnGPIO ${ERU0_1A1} false
    ${flag}=                  Read Word  ${ERU0_EXICON1}
    ${fl}=                    Evaluate  int($flag, 16) & 0x80
    Should Be Equal As Integers  ${fl}  128
    # the main loop stops toggling: LED1 keeps its level
    ${before}=                Execute Command  sysbus.port1.led1 State
    Run For                   1.2
    ${after}=                 Execute Command  sysbus.port1.led1 State
    Should Be Equal           ${after}  ${before}

ERU HIB IO Detects HIB_IO_1 Through The Hibernate Domain
    [Documentation]           Needs the SCU hibernate domain (HDCR.HIBIO1 pin mode, SR0 input selection to ERU0.1A1) of the scu-wdt-rtc component.
    [Tags]                    skip
    Skip                      The HIB_IO_1 pin and the SCU.HIB_SR0 routing belong to scu-wdt-rtc; only the ERU side (input 1A1) is tested above.
