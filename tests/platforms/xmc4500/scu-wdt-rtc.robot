*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Variables ***
${WDT_WLB}                    0x50008010
${WDT_WUB}                    0x50008014
${RTC_RAWSTAT}                0x50004A08
${SCU_TRAPRAW}                0x50004164

*** Keywords ***
LED1 Should Be
    [Arguments]               ${expected}
    ${state}=                 Execute Command  sysbus.port1.led1 State
    Should Be Equal As Strings  ${state.strip()}  ${expected}

LED2 Should Be
    [Arguments]               ${expected}
    ${state}=                 Execute Command  sysbus.port1.led2 State
    Should Be Equal As Strings  ${state.strip()}  ${expected}

Reset Count Should Be
    [Arguments]               ${expected}
    ${count}=                 Execute Command  sysbus.wdt ResetRequestCount
    Should Be Equal As Integers  ${count.strip()}  ${expected}

Prewarning Count Should Be
    [Arguments]               ${expected}
    ${count}=                 Execute Command  sysbus.wdt PreWarningCount
    Should Be Equal As Integers  ${count.strip()}  ${expected}

Read Register
    [Arguments]               ${address}
    ${value}=                 Execute Command  sysbus ReadDoubleWord ${address}
    ${number}=                Evaluate  int('${value.strip()}', 16)
    [Return]                  ${number}

Open Watchdog Window
    [Documentation]           The example windows (6 s .. 7 s at 120 MHz, but the example runs fWDT = 32.768 kHz) cannot be met by the 1 s feeding; use WLB = 0 (window off) and WUB = 5 s of fSTDBY.
    Execute Command           sysbus WriteDoubleWord ${WDT_WLB} 0
    Execute Command           sysbus WriteDoubleWord ${WDT_WUB} 0x28000

*** Test Cases ***
Should Wake Up From Sleep On Interrupt
    [Documentation]           SCU_Sleep: the CPU waits in WFI (sleep-on-exit); an ERU1 interrupt (NVIC 5, injected here since the ERU is a separate component) runs the handler that toggles LED1 twice around a delay.
    Create XMC4500 Machine
    ...                       SCU_Sleep
    Execute Command           emulation RunFor "0.2"
    LED1 Should Be            False
    Execute Command           sysbus.nvic OnGPIO 5 true
    Execute Command           emulation RunFor "0.01"
    Execute Command           sysbus.nvic OnGPIO 5 false
    LED1 Should Be            True
    Execute Command           emulation RunFor "1.5"
    LED1 Should Be            False

Should Enter NMI On Brownout
    [Documentation]           Brownout_Detection: the monitor is enabled (threshold 135 * 22.5 mV); lowering VDDP below it raises the brown-out trap, the NMI handler toggles LED1.
    Create XMC4500 Machine
    ...                       Brownout_Detection
    Execute Command           emulation RunFor "0.1"
    LED1 Should Be            True
    ${trap}=                  Read Register  ${SCU_TRAPRAW}
    Should Be Equal As Integers  ${trap}  0
    Execute Command           sysbus.scu SupplyVoltage 2.8
    Execute Command           emulation RunFor "0.1"
    ${trap}=                  Read Register  ${SCU_TRAPRAW}
    Should Be Equal As Integers  ${trap}  32
    LED1 Should Be            False

Should Not Raise Brownout At Nominal Supply
    Create XMC4500 Machine
    ...                       Brownout_Detection
    Execute Command           sysbus.scu SupplyVoltage 3.2
    Execute Command           emulation RunFor "0.2"
    ${trap}=                  Read Register  ${SCU_TRAPRAW}
    Should Be Equal As Integers  ${trap}  0

Should Reset On Bad Watchdog Service
    [Documentation]           WDT_FEED unmodified: fWDT is the 32.768 kHz standby clock, so the first feeding after 1 s lies far below the window lower bound (WLB = 720e6). The WDT requests a reset, the firmware sees the WDT reset cause and blinks LED1 fast.
    Create XMC4500 Machine    WDT_FEED
    Execute Command           emulation RunFor "1.1"
    Reset Count Should Be     1
    ${seen_on}=               Set Variable  ${False}
    ${seen_off}=              Set Variable  ${False}
    FOR    ${i}    IN RANGE    20
        Execute Command       emulation RunFor "0.02"
        ${state}=             Execute Command  sysbus.port1.led1 State
        ${seen_on}=           Evaluate  ${seen_on} or '${state.strip()}' == 'True'
        ${seen_off}=          Evaluate  ${seen_off} or '${state.strip()}' == 'False'
    END
    Should Be True            ${seen_on} and ${seen_off}  msg=LED1 does not blink after the watchdog reset

Should Keep Running When Watchdog Is Fed And Reset When Feeding Stops
    [Documentation]           WDT_FEED with an open window: ten feedings (LED1 toggles once per second) keep the system alive; after the last one the 5 s timeout expires and the WDT resets the system.
    Create XMC4500 Machine    WDT_FEED
    Execute Command           emulation RunFor "0.2"
    Open Watchdog Window
    Execute Command           emulation RunFor "9.5"
    Reset Count Should Be     0
    ${before}=                Execute Command  sysbus.port1.led1 State
    Execute Command           emulation RunFor "1"
    ${after}=                 Execute Command  sysbus.port1.led1 State
    Should Not Be Equal       ${before.strip()}  ${after.strip()}
    Execute Command           emulation RunFor "4.0"
    Reset Count Should Be     0
    Execute Command           emulation RunFor "2.0"
    Reset Count Should Be     1

Should Raise Watchdog Prewarning Before Reset
    [Documentation]           WDT_Prewarning with an open window: after the last feeding the first upper bound crossing sets WDTSTS.ALMS and (NMI promoted) calls Watchdog_Handler, which toggles LED2; the second crossing resets.
    Create XMC4500 Machine    WDT_Prewarning
    Execute Command           emulation RunFor "0.2"
    Open Watchdog Window
    Execute Command           emulation RunFor "10.5"
    LED2 Should Be           False
    Prewarning Count Should Be  0
    Execute Command           emulation RunFor "4.8"
    Prewarning Count Should Be  1
    LED2 Should Be            True
    ${status}=                Read Register  0x50008018
    Should Be Equal As Integers  ${status}  1
    Reset Count Should Be     0
    Execute Command           emulation RunFor "5"
    Reset Count Should Be     1

Should Trigger RTC Alarm After One Minute
    [Documentation]           RTC_Alarm: RTC starts at 1970-02-02 00:00:00 with the alarm at 00:01:00. LED1 blinks every 500 ms until the alarm interrupt (SCU_0) stops SysTick and drives LED1 high.
    Create XMC4500 Machine    RTC_Alarm
    Execute Command           emulation RunFor "59"
    ${raw}=                   Read Register  ${RTC_RAWSTAT}
    ${alarm}=                 Evaluate  ${raw} & 0x100
    Should Be Equal As Integers  ${alarm}  0
    ${tim0}=                  Read Register  0x50004A20
    Should Be Equal As Integers  ${tim0}  16777274
    Execute Command           emulation RunFor "1.2"
    ${raw}=                   Read Register  ${RTC_RAWSTAT}
    ${alarm}=                 Evaluate  ${raw} & 0x100
    Should Be Equal As Integers  ${alarm}  256
    LED1 Should Be            True
    Execute Command           emulation RunFor "0.6"
    LED1 Should Be            True

Should Boot Empty Application Without Unhandled SCU Accesses
    [Documentation]           The start-up code writes TRAPCLR; the SCU must handle it.
    Create XMC4500 Machine    Empty_XMC_App
    Create Log Tester         1
    Execute Command           emulation RunFor "0.2"
    Should Not Be In Log      non existing peripheral
    Should Not Be In Log      Unhandled
