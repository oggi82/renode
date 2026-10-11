*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Variables ***
${MO0_STATUS}                 0x4801501C
${MO0_STATUS_TXPND}           0x2

*** Keywords ***
Create CAN Hub
    Execute Command           emulation CreateCANHub "hub"
    # Lower quantum to keep the machines close together in virtual time
    Execute Command           emulation SetGlobalQuantum "0.0001"
    Execute Command           emulation SetGlobalSerialExecution True

Create XMC4500 Machine On Hub
    [Documentation]           Creates a machine from the Relax Lite Kit platform with the given ELF and connects its MultiCAN to the hub.
    [Arguments]               ${name}  ${example}
    ${elf}=                   Build Example  ${example}
    Execute Command           mach create "${name}"
    Execute Command           machine LoadPlatformDescription @platforms/boards/xmc4500_relax_lite_kit.repl
    Execute Command           sysbus LoadELF @${elf}
    Execute Command           cpu VectorTableOffset 0x08000000
    Execute Command           connector Connect sysbus.can0 hub

*** Test Cases ***
Should Receive Looped Back Frames Between Two Nodes With Incrementing Data
    [Documentation]           CAN_Loopback: node 0 sends a frame every second over the internal bus, a message object of node 1 receives it (interrupt SR7).
    Create XMC4500 Machine With UART Tester  CAN_Loopback
    Start Emulation
    Wait For Line On Uart     CAN Loopback Example project  timeout=5
    Wait For Line On Uart     Received CAN frame  timeout=3
    Wait For Line On Uart     Data1: 10000000
    Wait For Line On Uart     Data2: 20000000
    Wait For Line On Uart     Received CAN frame  timeout=3
    Wait For Line On Uart     Data1: 10000001
    Wait For Line On Uart     Data2: 20000001

Should Transmit Frames Periodically And Toggle The LED
    [Documentation]           CAN_Transmitter alone: sends a frame every 100 ms (the LED toggles with every transmission); the transmit message object reports TXPND.
    Create XMC4500 Machine    CAN_Transmitter
    Create Terminal Tester    ${XMC_UART}
    ${led}=                   Create LED Tester  sysbus.port1.led1
    Assert LED Is Blinking    testDuration=1  onDuration=0.1  offDuration=0.1  tolerance=0.2  testerId=${led}
    ${status}=                Execute Command  sysbus ReadDoubleWord ${MO0_STATUS}
    ${txpnd}=                 Evaluate  int($status.strip(), 16) & ${MO0_STATUS_TXPND}
    Should Be Equal As Integers  ${txpnd}  ${MO0_STATUS_TXPND}

Should Follow The Transmitter Button State On The Receiver LED
    [Documentation]           CAN_Transmitter and CAN_Receiver on two machines connected by a CANHub: the button on the transmitter side changes the data byte and LED2 of the receiver follows.
    Create CAN Hub
    Create XMC4500 Machine On Hub  tx  CAN_Transmitter
    Create XMC4500 Machine On Hub  rx  CAN_Receiver
    ${uart}=                  Create Terminal Tester  ${XMC_UART}  machine=rx
    ${led}=                   Create LED Tester  sysbus.port1.led2  machine=rx  defaultTimeout=0

    Start Emulation
    Wait For Line On Uart     CAN Receiver Example project  testerId=${uart}  timeout=5
    Wait For Line On Uart     Received CAN frame  testerId=${uart}  timeout=3
    Wait For Line On Uart     Button State: 0  testerId=${uart}
    Assert LED State          false  testerId=${led}

    Execute Command           mach set "tx"
    Execute Command           sysbus.port1.button1 Press
    Wait For Line On Uart     Button State: 1  testerId=${uart}  timeout=3
    Assert LED State          true  testerId=${led}  timeout=1

    Execute Command           mach set "tx"
    Execute Command           sysbus.port1.button1 Release
    Wait For Line On Uart     Button State: 0  testerId=${uart}  timeout=3
    Assert LED State          false  testerId=${led}  timeout=1
