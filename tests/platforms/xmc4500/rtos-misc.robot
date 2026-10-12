*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Keywords ***
Read Symbol Word
    [Arguments]               ${address}
    ${value}=                 Execute Command  sysbus ReadDoubleWord ${address}
    ${number}=                Evaluate  int($value.strip(), 16)
    [Return]                  ${number}

*** Test Cases ***
Should Toggle LED Every 500 ms From FreeRTOS Tasks
    [Documentation]           FreeRTOS_Blinky: Main task delays 500 ms and gives a semaphore, Blinky task toggles LED1 (PendSV context switches, SysTick at 72 MHz).
    Create XMC4500 Machine    FreeRTOS_Blinky
    Create LED Tester         sysbus.port1.led1
    Assert LED Is Blinking    testDuration=4  onDuration=0.5  offDuration=0.5  tolerance=0.01  pauseEmulation=true

Should Run FreeRTOS Tick At 1 kHz
    [Documentation]           FreeRTOS_Blinky: SystemCoreClock is 72 MHz and xTickCount advances by 1000 per virtual second (SysTick reload matches configTICK_RATE_HZ).
    Create XMC4500 Machine    FreeRTOS_Blinky
    Execute Command           emulation RunFor "0.5"
    ${clock}=                 Read Symbol Word  0x2000ffd0
    Should Be Equal As Integers  ${clock}  72000000
    ${running}=               Read Symbol Word  0x2000084c
    Should Be Equal As Integers  ${running}  1
    ${t0}=                    Read Symbol Word  0x20000854
    Execute Command           emulation RunFor "2.0"
    ${t1}=                    Read Symbol Word  0x20000854
    ${delta}=                 Evaluate  ${t1} - ${t0}
    Should Be True            1995 <= ${delta} <= 2005  msg=Tick delta ${delta} in 2 s

Should Enumerate As USB HID Device
    [Documentation]           emUSB-Device_HID_Generic needs a USB0 OTG device controller (DWC2-like) and a simulated host; not modelled, see docs/xmc4500/rtos-misc.md.
    [Tags]                    skip
    Skip                      USB0 device controller (Synopsys DWC_otg) is not modelled; analysis in docs/xmc4500/rtos-misc.md
