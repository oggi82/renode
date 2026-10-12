*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Keywords ***
Read Register
    [Arguments]               ${address}
    ${value}=                 Execute Command  sysbus ReadDoubleWord ${address}
    [Return]                  ${value.strip()}

*** Test Cases ***
UART Printf
    [Documentation]           UART_Printf: ASC output of the debug UART (USIC0 channel 0), baud rate from FDR/BRG and the SCU clock.
    Create XMC4500 Machine With UART Tester  UART_Printf
    Start Emulation
    Wait For Line On Uart     Hello World!         timeout=5

UART Transmit
    [Documentation]           UART_Transmit: a greeting is sent every second from the SysTick handler on the debug UART USIC1 channel 1.
    Create XMC4500 Machine With UART Tester  UART_Transmit  uart=sysbus.usic1ch1
    Start Emulation
    Wait For Line On Uart     Hello world!!        timeout=4
    Wait For Line On Uart     Hello world!!        timeout=4

UART Receive Through RBUF And Interrupt Flags
    [Documentation]           Characters typed on the terminal arrive in RBUF paced by the baud rate and set PSR.RIF.
    Create XMC4500 Machine With UART Tester  UART_Printf
    Execute Command           emulation RunFor "0.3"
    Write Char On Uart        A
    Execute Command           emulation RunFor "0.001"
    ${psr}=                   Read Register  0x40030048
    ${rif}=  Evaluate  int(${psr}) & 0x4000
    Should Be Equal As Integers  ${rif}  0x4000
    ${data}=                  Read Register  0x40030054
    Should Be Equal As Integers  ${data}  0x41

UART Transmit Receive With FIFOs And Interrupts
    [Documentation]           UART_Transmit_Receive_FIFO_Interrupts: nine bytes go through the TX FIFO (limit interrupt, USIC0 SR0)
    ...                       and, with TX wired to RX, come back through the RX FIFO (USIC0 SR1); the LED lights up on success.
    Create XMC4500 Machine    UART_Transmit_Receive_FIFO_Interrupts
    Execute Command           sysbus.usic0ch0 Loopback true
    ${led}=                   Create LED Tester  sysbus.port1.led1
    Start Emulation
    Assert LED State          true  timeout=2

SPI Master Sends Three Words To A Slave Channel
    [Documentation]           SPI_Master: USIC1 channel 0 is the SSC master and shifts 0x84 0x0F 0x84 each second; USIC2 channel 0 is wired
    ...                       to it (ConnectPeer) and set up as SSC slave with a receive FIFO, so the words can be read back.
    Create XMC4500 Machine    SPI_Master
    Execute Command           usic1ch0 ConnectPeer usic2ch0
    # slave: CCR.MODE = SSC, 8 bit words, transfer mode 1, RX FIFO of 8 entries
    Execute Command           sysbus WriteDoubleWord 0x48024034 0x07000100
    Execute Command           sysbus WriteDoubleWord 0x4802410C 0x03000000
    Execute Command           sysbus WriteDoubleWord 0x48024040 0x00000001
    ${led}=                   Create LED Tester  sysbus.port1.led1
    Execute Command           emulation RunFor "1.1"
    ${level}=                 Read Register  0x48024114
    ${count}=                 Evaluate  (int(${level}) >> 16) & 0x7F
    Should Be Equal As Integers  ${count}  3
    ${w0}=                    Read Register  0x4802411C
    ${w1}=                    Read Register  0x4802411C
    ${w2}=                    Read Register  0x4802411C
    ${w0}=                    Evaluate  int(${w0}) & 0xFFFF
    Should Be Equal As Integers  ${w0}  0x84
    ${w1}=                    Evaluate  int(${w1}) & 0xFFFF
    Should Be Equal As Integers  ${w1}  0x0F
    ${w2}=                    Evaluate  int(${w2}) & 0xFFFF
    Should Be Equal As Integers  ${w2}  0x84
