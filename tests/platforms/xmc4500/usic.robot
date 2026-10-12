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
    # FDR/BRG programmed by the XMC library (115200 baud) and the 72 MHz peripheral clock of the SCU
    ${baud}=                  Execute Command  usic0ch0 BaudRate
    ${baud}=                  Evaluate  int(${baud})
    Should Be True            115000 < ${baud} < 115400

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

SPI Transfer Starts On External Trigger
    [Documentation]           SPI_EXTTRG_transmit: USIC1 channel 1 holds each 16 bit word until a rising edge arrives at DX2 (P0.12 wired to
    ...                       the input stage); the words 0x0A0A 0x0505 0x5A5A reach a slave channel only after those edges.
    Create XMC4500 Machine    SPI_EXTTRG_transmit
    Create File               ${TEMPDIR}/usic_trigger.repl  port0:\n${SPACE}${SPACE}${SPACE}${SPACE}12 -> usic1ch1@2\n
    Execute Command           machine LoadPlatformDescription @${TEMPDIR}/usic_trigger.repl
    Execute Command           usic1ch1 ConnectPeer usic2ch0
    Execute Command           sysbus WriteDoubleWord 0x48024034 0x0F000100
    Execute Command           sysbus WriteDoubleWord 0x4802410C 0x03000000
    Execute Command           sysbus WriteDoubleWord 0x48024040 0x00000001
    Execute Command           emulation RunFor "0.5"
    ${level}=                 Read Register  0x48024114
    ${count}=                 Evaluate  (int(${level}) >> 16) & 0x7F
    Should Be Equal As Integers  ${count}  0
    Execute Command           emulation RunFor "0.7"
    ${level}=                 Read Register  0x48024114
    ${count}=                 Evaluate  (int(${level}) >> 16) & 0x7F
    Should Be Equal As Integers  ${count}  3
    ${w0}=                    Read Register  0x4802411C
    ${w1}=                    Read Register  0x4802411C
    ${w2}=                    Read Register  0x4802411C
    ${w0}=                    Evaluate  int(${w0}) & 0xFFFF
    ${w1}=                    Evaluate  int(${w1}) & 0xFFFF
    ${w2}=                    Evaluate  int(${w2}) & 0xFFFF
    Should Be Equal As Integers  ${w0}  0x0A0A
    Should Be Equal As Integers  ${w1}  0x0505
    Should Be Equal As Integers  ${w2}  0x5A5A

SPI QSPI Flash Erase Program And Read Back
    [Documentation]           SPI_QSPI_Flash: SSC master on USIC0 channel 0 talks to the S25FL032P on the board (erase sector, program page,
    ...                       read back and compare); progress is printed on the debug UART at USIC1 channel 1.
    Create XMC4500 Machine With UART Tester  SPI_QSPI_Flash  uart=sysbus.usic1ch1
    Start Emulation
    Wait For Line On Uart     SPI QSPI Flash       timeout=10
    Wait For Line On Uart     Sector erase successful!  timeout=10
    Wait For Line On Uart     Programming successful!  timeout=60
    Wait For Line On Uart     Successfully completed demo!  timeout=120

I2C Master Controls LED Through Slave Channel
    [Documentation]           I2C_Master_and_Slave: the master on USIC1 channel 0 (wired to the slave on USIC2 channel 0 via Peer) sends 0xAA / 0x55
    ...                       every 500 ms; the slave receive interrupt (USIC2 SR2) switches the LED on and off.
    Create XMC4500 Machine    I2C_Master_and_Slave
    Execute Command           usic1ch0 ConnectPeer usic2ch0
    ${led}=                   Create LED Tester  sysbus.port1.led1
    Start Emulation
    Assert LED State          true  timeout=1
    Assert LED State          false  timeout=1
    Assert LED State          true  timeout=1
