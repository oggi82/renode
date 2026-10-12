*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Variables ***
${VADC}                       sysbus.vadc
${DAC}                        sysbus.dac
${DAC_SINE}                   0,6,12,17,22,26,29,30,31

*** Keywords ***
Read Number
    [Arguments]               ${command}
    ${out}=                   Execute Command  ${command}
    ${value}=                 Evaluate  int($out.strip().split()[-1], 16)
    [Return]                  ${value}

*** Test Cases ***
Should Convert Continuously With Background Source
    [Documentation]           VADC_Background: group 0 channel 6 is converted permanently, the LED is on for results >= 2000.
    Create XMC4500 Machine With UART Tester  VADC_Background
    Create LED Tester         sysbus.port1.led1
    Execute Command           ${VADC} SetVoltage 0 6 1.0
    Start Emulation
    Wait For Line On Uart     ADC Conversion starts  timeout=5
    Wait For Line On Uart     ADC Result value is 4d9  timeout=5
    Assert LED State          false  timeout=1
    Execute Command           ${VADC} SetVoltage 0 6 2.5
    Wait For Line On Uart     ADC Result value is c1f  timeout=5
    Assert LED State          true  timeout=1

Should Report Scan Result In Interrupt Handler
    [Documentation]           VADC_Scan: the background scan end event is routed to shared service request 2 and the handler sets the LED.
    Create XMC4500 Machine With UART Tester  VADC_Scan
    Create LED Tester         sysbus.port1.led1
    Execute Command           ${VADC} SetVoltage 0 0 0.5
    Start Emulation
    Wait For Line On Uart     ADC Result value is 26c  timeout=5
    Assert LED State          false  timeout=1
    Execute Command           ${VADC} SetVoltage 0 0 3.0
    Wait For Line On Uart     ADC Result value is e8b  timeout=5
    Assert LED State          true  timeout=1

Should Convert Queue Entries After External Trigger
    [Documentation]           VADC_Queue: channel 1 waits for the trigger, channels 5 and 3 follow; results land in result registers 1, 3 and 5.
    Create XMC4500 Machine With UART Tester  VADC_Queue
    Execute Command           ${VADC} SetVoltage 0 1 1.0
    Execute Command           ${VADC} SetVoltage 0 3 2.0
    Execute Command           ${VADC} SetVoltage 0 5 3.0
    Start Emulation
    Wait For Line On Uart     ADC Conversion starts  timeout=5
    Wait For Line On Uart     channel 1: 0, channel 3: 0 and channel 5: 0  timeout=5
    # the trigger input is the one the firmware selected in QCTRL0.XTSEL (normally driven by CCU40)
    ${qctrl}=                 Read Number  sysbus ReadDoubleWord 0x40004500
    ${line}=                  Evaluate  ($qctrl >> 8) & 0xF
    Execute Command           ${VADC} PulseTrigger ${line}
    Wait For Line On Uart     channel 1: 4d9, channel 3: 9b2 and channel 5: e8b  timeout=5

Should Convert External Multiplexer Channels In Sequence Mode
    [Documentation]           VADC_EMUX: each trigger converts channel 1 for the external multiplexer settings 7 down to 0.
    Create XMC4500 Machine With UART Tester  VADC_EMUX
    Execute Command           ${VADC} SetEmuxVoltage 0 7 0.1
    Execute Command           ${VADC} SetEmuxVoltage 0 6 0.2
    Execute Command           ${VADC} SetEmuxVoltage 0 5 0.3
    Execute Command           ${VADC} SetEmuxVoltage 0 0 1.0
    Start Emulation
    Wait For Line On Uart     Initialization done  timeout=5
    Wait For Line On Uart     124  timeout=5
    Wait For Line On Uart     248  timeout=5
    Wait For Line On Uart     372  timeout=5
    Wait For Line On Uart     1241  timeout=5
    ${select}=                Read Number  ${VADC} GetEmuxSelect 0
    Should Be True            ${select} <= 7

Should Output Sine Wave On DAC Channel 0
    [Documentation]           DAC_Sine_Wave: channel 0 runs the pattern generator (signed, scale 64) and the melody changes its frequency, channel 1 is static 0.
    Create XMC4500 Machine With UART Tester  DAC_Sine_Wave
    Execute Command           emulation RunFor "0.0153"
    ${samples}=               Read Number  ${DAC} GetSampleNumber 0
    ${code}=                  Read Number  ${DAC} GetOutputCode 0
    Should Be True            ${samples} > 100
    ${expected}=              Evaluate  2048 + (-1 if (($samples - 1) % 32) >= 16 else 1) * [${DAC_SINE}][min(($samples - 1) % 16, 16 - ($samples - 1) % 16)] * 64
    Should Be Equal As Integers  ${code}  ${expected}
    ${code1}=                 Read Number  ${DAC} GetOutputCode 1
    Should Be Equal As Integers  ${code1}  2048
    # 500 Hz * 32 samples at fPB = 72 MHz
    ${cfg0}=                  Read Number  sysbus ReadDoubleWord 0x48018004
    Should Be Equal As Integers  ${cfg0 & 0xFFFFF}  4500
    # after the first beat (100 ms) the melody switches to 20 kHz
    Execute Command           emulation RunFor "0.15"
    ${cfg0}=                  Read Number  sysbus ReadDoubleWord 0x48018004
    Should Be Equal As Integers  ${cfg0 & 0xFFFFF}  112
