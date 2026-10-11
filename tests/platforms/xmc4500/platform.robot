*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Test Cases ***
Should Boot And Print With Printf Retargeted To USIC0 Channel 0
    [Documentation]           Boots the UART_Printf example: exercises memory map, vector table, SCU clock set-up (PLL lock) and the USIC UART.
    Create XMC4500 Machine With UART Tester  UART_Printf
    Start Emulation
    Wait For Line On Uart     Initialization done  timeout=5
    Wait For Line On Uart     Hello World!         timeout=5

Should Boot Empty Application Without Unhandled Accesses
    [Documentation]           The template application only runs the common start-up code; no access may hit a missing peripheral.
    Create XMC4500 Machine    Empty_XMC_App
    Create Log Tester         1
    Execute Command           emulation RunFor "0.2"
    Should Not Be In Log      non existing peripheral
