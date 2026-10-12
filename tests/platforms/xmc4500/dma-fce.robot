*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Keywords ***
Read Word
    [Arguments]               ${address}
    ${out}=                   Execute Command  sysbus ReadDoubleWord ${address}
    ${value}=                 Evaluate  int($out.strip(), 16)
    [Return]                  ${value}

Read Symbol Word
    [Arguments]               ${symbol}  ${index}=0
    ${address}=               Execute Command  sysbus GetSymbolAddress "${symbol}"
    ${value}=                 Read Word  ${{ int($address.strip(), 0) + 4 * ${index} }}
    [Return]                  ${value}


*** Test Cases ***
Should Copy Memory To Memory With GPDMA In DMA_M2M
    [Documentation]           DMA_M2M: GPDMA0 channel 0 copies 10 words from flash to RAM, the transfer complete interrupt sets the flag, LED1 lights if the buffers are equal.
    Create XMC4500 Machine    DMA_M2M
    Create LED Tester         sysbus.port1.led1
    Start Emulation
    Assert LED State          true  timeout=1
    FOR  ${i}  IN RANGE  10
        ${v}=                 Read Symbol Word  destination_data  ${i}
        Should Be Equal As Integers  ${v}  ${i}
    END
    ${enabled}=               Read Word  0x500143A0
    Should Be Equal As Integers  ${enabled}  0
    ${raw}=                   Read Word  0x500142C0
    Should Be Equal As Integers  ${raw}  0

Should Drive The LEDs With A GPDMA Pattern In DMA_GPIO
    [Documentation]           DMA_GPIO: an endless auto-reload transfer writes 8 words to P1.OMR; LED1 is on for 4 of 8 steps, LED2 for 2 of 8.
    Create XMC4500 Machine    DMA_GPIO
    ${led1}=                  Create LED Tester  sysbus.port1.led1
    ${led2}=                  Create LED Tester  sysbus.port1.led2
    Execute Command           emulation RunFor "0.001"
    Assert LED Duty Cycle     testDuration=0.002  expectedDutyCycle=0.5  tolerance=0.02  pauseEmulation=true  testerId=${led1}
    Assert LED Duty Cycle     testDuration=0.002  expectedDutyCycle=0.25  tolerance=0.02  pauseEmulation=true  testerId=${led2}
    ${enabled}=               Read Word  0x500143A0
    Should Be Equal As Integers  ${enabled}  1

Should Compute The CRC32 With DMA In DMA_FCE
    [Documentation]           DMA_FCE: GPDMA0 feeds 256 words into FCE kernel 0 (IR); the CRC matches 0x99F69CD9 so LED1 lights, and RES is the expected value.
    Create XMC4500 Machine    DMA_FCE
    Create LED Tester         sysbus.port1.led1
    Start Emulation
    Assert LED State          true  timeout=1
    ${res}=                   Read Word  0x50020024
    Should Be Equal As Integers  ${res}  ${0x99F69CD9}
    ${sts}=                   Read Word  0x5002002C
    Should Be Equal As Integers  ${sts}  0

Should Print Reference CRCs In FCE_CRC
    [Documentation]           FCE_CRC: output equals the real hardware output (screenshot in the example README); the last step raises the forced mismatch and turns LED1 on.
    ${tester}=                Create XMC4500 Machine With UART Tester  FCE_CRC
    Create LED Tester         sysbus.port1.led1
    Start Emulation
    Wait For Line On Uart     RES = 0xdf65a96d  testerId=${tester}  timeout=5
    Wait For Line On Uart     RES = 0x209a5692  testerId=${tester}  timeout=5
    Wait For Line On Uart     Length error occurred  testerId=${tester}  timeout=5
    Wait For Line On Uart     RES = 0x6a9255b2  testerId=${tester}  timeout=5
    Wait For Line On Uart     RES = 0xadf8  testerId=${tester}  timeout=5
    Wait For Line On Uart     RES = 0x7a  testerId=${tester}  timeout=5
    Wait For Line On Uart     Mismatch flag is triggered: Step 6  testerId=${tester}  timeout=5
    Assert LED State          true  timeout=1

Should Match Known CRC Check Values
    [Documentation]           Direct register access: CRC-8/SAE-J1850 of "123456789" is 0x4B; CRC-32 of "12345678" is the zlib value; unlock key for CHECK/LENGTH.
    Create XMC4500 Machine    Empty_XMC_App
    Execute Command           sysbus WriteDoubleWord 0x50020000 0
    # kernel 3 (CRC8): init 0xFF, XOR with all ones
    Execute Command           sysbus WriteDoubleWord 0x50020088 0x400
    Execute Command           sysbus WriteDoubleWord 0x50020098 0xFF
    FOR  ${c}  IN  @{{ list(b"123456789") }}
        Execute Command       sysbus WriteDoubleWord 0x50020080 ${c}
    END
    ${r8}=                    Read Word  0x50020084
    Should Be Equal As Integers  ${r8}  ${0x4B}
    # kernel 0 (CRC32): reflected in/out, seed and XOR all ones = zlib CRC32 when the bytes are written as big endian words
    Execute Command           sysbus WriteDoubleWord 0x50020038 0xFFFFFFFF
    Execute Command           sysbus WriteDoubleWord 0x50020028 0x700
    Execute Command           sysbus WriteDoubleWord 0x50020020 ${{ int.from_bytes(b"1234", "big") }}
    Execute Command           sysbus WriteDoubleWord 0x50020020 ${{ int.from_bytes(b"5678", "big") }}
    ${r32}=                   Read Word  0x50020024
    ${expected}=              Evaluate  __import__('zlib').crc32(b"12345678")
    Should Be Equal As Integers  ${r32}  ${expected}
    # reset value of RES with the reset CFG
    Execute Command           sysbus WriteDoubleWord 0x50020038 0
    ${res}=                   Read Word  0x50020024
    Should Be Equal As Integers  ${res}  ${0xFFFFFFFF}

Should Check The Signature And Flag Errors
    [Documentation]           CCE with LENGTH 2: matching CHECK gives no flag, a wrong CHECK gives CMF, a third write gives LEF; FCM forces CMF.
    Create XMC4500 Machine    Empty_XMC_App
    Execute Command           sysbus WriteDoubleWord 0x50020000 0
    Execute Command           sysbus WriteDoubleWord 0x50020028 0x710
    Execute Command           sysbus WriteDoubleWord 0x50020038 0xFFFFFFFF
    ${expected}=              Evaluate  __import__('zlib').crc32(b"12345678")
    Execute Command           sysbus WriteDoubleWord 0x50020034 0xFACECAFE
    Execute Command           sysbus WriteDoubleWord 0x50020034 ${expected}
    Execute Command           sysbus WriteDoubleWord 0x50020030 0xFACECAFE
    Execute Command           sysbus WriteDoubleWord 0x50020030 2
    Execute Command           sysbus WriteDoubleWord 0x50020020 ${{ int.from_bytes(b"1234", "big") }}
    Execute Command           sysbus WriteDoubleWord 0x50020020 ${{ int.from_bytes(b"5678", "big") }}
    ${sts}=                   Read Word  0x5002002C
    Should Be Equal As Integers  ${sts}  0
    ${len}=                   Read Word  0x50020030
    Should Be Equal As Integers  ${len}  0
    Execute Command           sysbus WriteDoubleWord 0x50020020 0
    ${sts}=                   Read Word  0x5002002C
    Should Be Equal As Integers  ${sts}  4
    Execute Command           sysbus WriteDoubleWord 0x5002002C 4
    # a write without the key is ignored
    Execute Command           sysbus WriteDoubleWord 0x50020030 5
    ${len}=                   Read Word  0x50020030
    Should Be Equal As Integers  ${len}  0xFFFF
    Execute Command           sysbus WriteDoubleWord 0x5002003C 1
    ${sts}=                   Read Word  0x5002002C
    Should Be Equal As Integers  ${sts}  1

Should Fill The Ring Buffer From UART Receive Requests In DMA_Ring_Buffer
    [Documentation]           DMA_Ring_Buffer: GPDMA0 channel 2 moves received bytes (hardware handshake on DLR line 5, source USIC0.SR0) into the ring buffer; the SysTick handler echoes them. The USIC receive service request is injected into the DLR input 46 by hand until the USIC model pulses it.
    ${tester}=                Create XMC4500 Machine With UART Tester  DMA_Ring_Buffer
    Start Emulation
    Wait For Line On Uart     Just start typing. What you type will be echoed below:  testerId=${tester}  timeout=5
    Execute Command           sysbus.usic0ch0 WriteChar 0x41
    Execute Command           sysbus.dlr OnGPIO 46 true
    Execute Command           sysbus.dlr OnGPIO 46 false
    Execute Command           sysbus.usic0ch0 WriteChar 0x42
    Execute Command           sysbus.dlr OnGPIO 46 true
    Execute Command           sysbus.dlr OnGPIO 46 false
    Wait For Prompt On Uart   AB  testerId=${tester}  timeout=5
    ${dlr}=                   Read Word  0x50004900
    Should Be Equal As Integers  ${dlr}  0

Should Send Two Buffers From UART Transmit Requests In UART_DMA
    [Documentation]           UART_DMA: GPDMA0 channel 2 writes one byte to TBUF per request (DLR line 5, USIC0.SR0). The requests are injected into the DLR by hand (the initial SIO0 trigger and the transmit buffer event of the USIC are not available yet); two buffers of 256 characters A-Z, a-z are sent.
    ${tester}=                Create XMC4500 Machine With UART Tester  UART_DMA
    Execute Command           emulation RunFor "0.01"
    FOR  ${i}  IN RANGE  256
        Execute Command       sysbus.dlr OnGPIO 46 true
        Execute Command      emulation RunFor "0.0001"
    END
    Wait For Prompt On Uart   ${{ ''.join(chr(65 + i % 26) for i in range(256)) }}  testerId=${tester}  timeout=5
    FOR  ${i}  IN RANGE  256
        Execute Command       sysbus.dlr OnGPIO 46 true
        Execute Command      emulation RunFor "0.0001"
    END
    Wait For Prompt On Uart   ${{ ''.join(chr(97 + i % 26) for i in range(1, 256)) }}  testerId=${tester}  timeout=5

Should Change The PWM Compare Value From Linked List DMA In DMA_PWM
    [Documentation]           DMA_PWM: channel 0 (linked list of two blocks of 48 words) writes the next duty cycle into CCU40 CC40 CRS on every compare match request (DLR line 1), channel 1 triggers the shadow transfer. CR rises in steps of 1365 during the first block and falls in the second.
    Create XMC4500 Machine    DMA_PWM
    Execute Command           emulation RunFor "0.02"
    ${a}=                     Read Word  0x4000C138
    Execute Command           emulation RunFor "0.01"
    ${b}=                     Read Word  0x4000C138
    Execute Command           emulation RunFor "0.025"
    ${c}=                     Read Word  0x4000C138
    Execute Command           emulation RunFor "0.01"
    ${d}=                     Read Word  0x4000C138
    Should Be True            ${a} > 0 and ${a} % 1365 == 0  msg=CR ${a}
    Should Be True            ${b} > ${a} and ${b} % 1365 == 0  msg=CR ${b}
    Should Be True            ${c} > ${b} and ${c} % 1365 == 0  msg=CR ${c}: the second block starts with a high value, not 0
    Should Be True            ${d} < ${c} and ${d} % 1365 == 0  msg=CR ${d} must fall in the second block (c=${c})

Should Transfer SPI Data With Two DMA Channels In SPI_DMA
    [Tags]                    skip
    Skip                      SPI_DMA needs USIC1 channel 0 in SPI mode (SSC) with DMA service requests (USIC1.SR0/SR1 -> DLR lines 5 and 7); the USIC component has no SPI yet. The DMA side (DLR routing, request inputs) is in place.
