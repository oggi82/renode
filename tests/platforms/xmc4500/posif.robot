*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Variables ***
${HALL_INPUTS}                ${CURDIR}/posif_hall_inputs.repl
${QD_INPUTS}                  ${CURDIR}/posif_qd_inputs.repl
${HALL_INTERVAL_REGEX}        Time interval between two correct hall events: (\\d+)ns

*** Keywords ***
Wait For Hall Interval Of
    [Documentation]           Waits for the interval line whose value is within the given range (earlier lines belong to earlier events).
    [Arguments]               ${min}  ${max}
    FOR  ${i}  IN RANGE  4
        ${line}=              Wait For Line On Uart  ${HALL_INTERVAL_REGEX}  timeout=2  treatAsRegex=true
        ${value}=             Evaluate  int($line.Groups[0])
        Return From Keyword If  ${min} <= ${value} <= ${max}  ${value}
    END
    Fail                      No hall interval line between ${min} and ${max}

*** Test Cases ***
Should Report Time Between Correct Hall Events And Wrong Hall Event
    [Documentation]           POSIF_Hall: hall patterns 001 -> 011 -> 010 -> 110 are the expected sequence (CCU40 slice 1 measures the time between the events, 20 ms apart here). 101 after 110 is a wrong hall event. The CCU80 timers that normally generate the hall signals are replaced by a stub that reports their period match flag.
    Create XMC4500 Machine With UART Tester  POSIF_Hall
    Execute Command           machine LoadPlatformDescription @${HALL_INPUTS}
    Execute Command           sysbus.port14.hall1 Press
    Execute Command           emulation RunFor "0.1"
    Execute Command           sysbus.port14.hall2 Press
    Execute Command           emulation RunFor "0.12"
    Wait For Line On Uart     Time interval between two correct hall events:  timeout=2
    Execute Command           sysbus.port14.hall1 Release
    Execute Command           emulation RunFor "0.02"
    Execute Command           sysbus.port14.hall3 Press
    Execute Command           emulation RunFor "0.15"
    # 7111 ns per count of the speed timer (prescaler 512, 72 MHz): 20 ms are 2812 counts
    ${interval}=              Wait For Hall Interval Of  19500000  20500000
    Execute Command           sysbus.port14.hall1 Press
    Execute Command           sysbus.port14.hall2 Release
    Execute Command           emulation RunFor "0.15"
    Wait For Line On Uart     Wrong hall event  timeout=2

Should Show Rotation Direction And Position From Quadrature Encoder
    [Documentation]           POSIF_QD: phase A leading phase B turns clockwise (LED1, position counts up), phase B leading turns anti-clockwise (LED2, position counts down). The CCU81 timers that normally generate the phase signals are replaced by a stub that paces the output lines.
    Create XMC4500 Machine With UART Tester  POSIF_QD
    Execute Command           machine LoadPlatformDescription @${QD_INPUTS}
    Create LED Tester         sysbus.port1.led1
    Execute Command           emulation RunFor "0.02"
    # clockwise: A rises, B rises, A falls, B falls (4 quadrature clocks), 0.5 ms apart
    Execute Command           sysbus.port14.phaseA Press
    Execute Command           emulation RunFor "0.0005"
    Execute Command           sysbus.port14.phaseB Press
    Execute Command           emulation RunFor "0.0005"
    Execute Command           sysbus.port14.phaseA Release
    Execute Command           emulation RunFor "0.0005"
    Execute Command           sysbus.port14.phaseB Release
    Execute Command           emulation RunFor "0.01"
    ${line}=                  Wait For Line On Uart  POSITION:\\s+4 INTERVAL: (\\d+)  timeout=2  treatAsRegex=true
    ${interval}=              Evaluate  int($line.Groups[0])
    # time between two period clocks: 0.5 ms (33 ns per count)
    Should Be True            450000 <= ${interval} <= 550000  msg=interval ${interval}
    Assert LED State          true  timeout=0
    # anti-clockwise: B rises, A rises, B falls, A falls
    Execute Command           sysbus.port14.phaseB Press
    Execute Command           emulation RunFor "0.0005"
    Execute Command           sysbus.port14.phaseA Press
    Execute Command           emulation RunFor "0.0005"
    Execute Command           sysbus.port14.phaseB Release
    Execute Command           emulation RunFor "0.0005"
    Execute Command           sysbus.port14.phaseA Release
    Execute Command           emulation RunFor "0.01"
    Wait For Line On Uart     POSITION:\\s+0 INTERVAL:  timeout=2  treatAsRegex=true
    Assert LED State          false  timeout=0
    ${direction}=             Execute Command  sysbus.posif0 ReadDoubleWord 0x60
    Should Be Equal As Integers  ${direction}  0
