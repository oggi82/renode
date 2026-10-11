*** Settings ***
Resource                      ${CURDIR}/xmc4500.resource

*** Variables ***
${FLASH}                      0x0C000000
${FSR}                        0x58002010
${SECTOR7}                    0x0C01C000
${SECTOR8}                    0x0C020000
${UCB0}                       0x0C000000
${FCE_STUB}                   ${CURDIR}/flash_fce_stub.py
# FSR bits
${PROG}                       ${0x10}
${ERASE}                      ${0x20}
${PFPAGE}                     ${0x40}
${SQER}                       ${0x400}
${PROER}                      ${0x800}

*** Keywords ***
Read Word
    [Arguments]               ${address}
    ${out}=                   Execute Command  sysbus ReadDoubleWord ${address}
    ${value}=                 Evaluate  int($out.strip(), 16)
    [Return]                  ${value}

Write Word
    [Arguments]               ${address}  ${value}
    Execute Command           sysbus WriteDoubleWord ${address} ${value}

Flag Should Be Set
    [Arguments]               ${flag}
    ${fsr}=                   Read Word  ${FSR}
    Should Be True            ${fsr} & ${flag} == ${flag}  FSR=${fsr} lacks ${flag}

Flag Should Be Clear
    [Arguments]               ${flag}
    ${fsr}=                   Read Word  ${FSR}
    Should Be True            ${fsr} & ${flag} == 0  FSR=${fsr} has ${flag}

Cmd
    [Documentation]           One command cycle: write 'data' to the flash command address at offset 'off'.
    [Arguments]               ${off}  ${data}
    Write Word                ${{ hex(0x0C000000 + ${off}) }}  ${data}

Clear Status
    Cmd                       0x5554  0xF5

Erase Sector
    [Arguments]               ${address}
    Cmd  0x5554  0xAA
    Cmd  0xAAA8  0x55
    Cmd  0x5554  0x80
    Cmd  0x5554  0xAA
    Cmd  0xAAA8  0x55
    Write Word                ${address}  0x30

Program Page
    [Documentation]           Enter Page Mode, Load Page with 32 x (word, word+1), Write Page.
    [Arguments]               ${address}  ${first_word}  ${count}=32
    Cmd  0x5554  0x50
    FOR  ${i}  IN RANGE  ${count}
        Cmd  0x55F0  ${first_word}
        Cmd  0x55F4  ${first_word}
    END
    Cmd  0x5554  0xAA
    Cmd  0xAAA8  0x55
    Cmd  0x5554  0xA0
    Write Word                ${address}  0xAA

Create Flash Machine
    Create XMC4500 Machine    Empty_XMC_App

Add FCE Stub If Missing
    [Documentation]           Flash_EEPROM needs the CRC engine; use a stub only if the platform has no FCE model yet.
    ${at}=                    Execute Command  sysbus WhatPeripheralIsAt 0x50020020
    ${missing}=               Evaluate  'none' in $at.lower() or 'nothing' in $at.lower() or not $at.strip()
    IF  ${missing}
        Execute Command       machine PyDevFromFile @${FCE_STUB} 0x50020000 0x100 True "fceStub"
    END

*** Test Cases ***
Should Erase And Program A Sector In Flash_Program
    [Documentation]           The example erases sector 7, programs one page, verifies it and then blinks the LED.
    Create XMC4500 Machine    Flash_Program
    ${led}=                   Create LED Tester  sysbus.port1.led1
    Start Emulation
    Assert LED Is Blinking    testDuration=3  onDuration=0.5  offDuration=0.5  tolerance=0.15  timeout=5
    ${first}=                 Read Word  ${SECTOR7}
    ${second}=                Read Word  ${SECTOR7} + 4
    ${last}=                  Read Word  ${{ hex(0x0C01C000 + 0xFC) }}
    ${after}=                 Read Word  ${{ hex(0x0C01C000 + 0x100) }}
    Should Be Equal As Integers  ${first}   ${0x11111111}
    Should Be Equal As Integers  ${second}  ${0x22222222}
    Should Be Equal As Integers  ${last}    ${0}
    Should Be Equal As Integers  ${after}   ${0}
    Flag Should Be Set        ${PROG}
    Flag Should Be Set        ${ERASE}
    Flag Should Be Clear      ${SQER}

Should Keep Data In The Emulated EEPROM Across Resets
    [Documentation]           Flash_EEPROM increments 64 bytes stored in flash on every start; the data must survive a reset.
    Create XMC4500 Machine    Flash_EEPROM
    Add FCE Stub If Missing
    ${tester}=                Create Terminal Tester  sysbus.usic1ch1
    Execute Command           showAnalyzer sysbus.usic1ch1
    Start Emulation
    Wait For Line On Uart     New Data in EEPROM  testerId=${tester}  timeout=10
    Wait For Line On Uart     (\\s*0x01){50}\\s*  testerId=${tester}  treatAsRegex=true  timeout=5
    Execute Command           machine Reset
    Execute Command           cpu VectorTableOffset 0x08000000
    Wait For Line On Uart     Existing Data in EEPROM  testerId=${tester}  timeout=10
    Wait For Line On Uart     (\\s*0x01){50}\\s*  testerId=${tester}  treatAsRegex=true  timeout=5
    Wait For Line On Uart     (\\s*0x02){50}\\s*  testerId=${tester}  treatAsRegex=true  timeout=5

Should Not Change Flash Without A Command Sequence
    Create Flash Machine
    Write Word                ${SECTOR7}  0x12345678
    Write Word                ${SECTOR7}  0xAA
    ${v}=                     Read Word  ${SECTOR7}
    Should Be Equal As Integers  ${v}  ${0}
    Flag Should Be Set        ${SQER}
    Clear Status
    Flag Should Be Clear      ${SQER}

Should Only Turn Bits To One When Programming
    Create Flash Machine
    Program Page              ${SECTOR7}  0x0F0F0F00
    Flag Should Be Set        ${PROG}
    Flag Should Be Clear      ${PFPAGE}
    Flag Should Be Clear      ${SQER}
    ${v}=                     Read Word  ${SECTOR7}
    Should Be Equal As Integers  ${v}  ${0x0F0F0F00}
    Clear Status
    Program Page              ${SECTOR7}  0x00FF00F0
    ${v}=                     Read Word  ${SECTOR7}
    Should Be Equal As Integers  ${v}  ${0x0FFF0FF0}
    # an erase sets everything back to 0
    Clear Status
    Erase Sector              ${SECTOR7}
    Flag Should Be Set        ${ERASE}
    ${v}=                     Read Word  ${SECTOR7}
    Should Be Equal As Integers  ${v}  ${0}

Should Report Sequence Errors
    Create Flash Machine
    # Load Page without Enter Page Mode
    Cmd  0x55F0  0x1
    Flag Should Be Set        ${SQER}
    Clear Status
    # Write Page without page mode
    Cmd  0x5554  0xAA
    Cmd  0xAAA8  0x55
    Cmd  0x5554  0xA0
    Write Word                ${SECTOR7}  0xAA
    Flag Should Be Set        ${SQER}
    Clear Status
    # Erase with an address that is no sector start
    Program Page              ${SECTOR7}  0xFFFFFFFF
    Clear Status
    Erase Sector              ${{ hex(0x0C01C100) }}
    Flag Should Be Set        ${SQER}
    ${v}=                     Read Word  ${SECTOR7}
    Should Be Equal As Integers  ${v}  ${0xFFFFFFFF}
    # Reset to Read aborts a sequence without error
    Clear Status
    Cmd  0x5554  0xAA
    Cmd  0x5554  0xF0
    Flag Should Be Clear      ${SQER}

Should Enter And Leave Page Mode
    Create Flash Machine
    Cmd  0x5554  0x50
    Flag Should Be Set        ${PFPAGE}
    Cmd  0x5554  0xF0
    Flag Should Be Clear      ${PFPAGE}

Should Erase A Physical Sector
    Create Flash Machine
    Program Page              ${SECTOR7}  0x1
    Program Page              ${FLASH} + 0x0C000  0x2
    Cmd  0x5554  0xAA
    Cmd  0xAAA8  0x55
    Cmd  0x5554  0x80
    Cmd  0x5554  0xAA
    Cmd  0xAAA8  0x55
    Write Word                ${{ hex(0x0C010000) }}  0x40
    ${v}=                     Read Word  ${SECTOR7}
    Should Be Equal As Integers  ${v}  ${0}

Should Enforce Sector Write Protection
    [Documentation]           Install write protection for sector 7 in UCB0 (mask, passwords, confirmation), reset, then
    ...                       check PROER on erase, the password handshake and Resume Protection.
    Create Flash Machine
    # UCB page 0: protection mask S7, passwords 0x11 0x22 (and the copies)
    Cmd  0x5554  0x50
    Cmd  0x55F0  0x80
    Cmd  0x55F4  0x0
    Cmd  0x55F0  0x80
    Cmd  0x55F4  0x0
    Cmd  0x55F0  0x11
    Cmd  0x55F4  0x22
    Cmd  0x55F0  0x11
    Cmd  0x55F4  0x22
    FOR  ${i}  IN RANGE  24
        Cmd  0x55F0  0x0
        Cmd  0x55F4  0x0
    END
    Cmd  0x5554  0xAA
    Cmd  0xAAA8  0x55
    Cmd  0x5554  0xC0
    Write Word                ${UCB0}  0xAA
    Flag Should Be Clear      ${SQER}
    Flag Should Be Clear      ${PROER}
    # the protection is read at start-up only
    Erase Sector              ${SECTOR7}
    Flag Should Be Clear      ${PROER}
    Execute Command           sysbus.flashController Reset
    ${procon}=                Read Word  0x58002020
    Should Be Equal As Integers  ${procon}  ${0x80}
    Program Page              ${SECTOR7}  0xFFFFFFFF
    Flag Should Be Set        ${PROER}
    ${v}=                     Read Word  ${SECTOR7}
    Should Be Equal As Integers  ${v}  ${0}
    Clear Status
    # unprotected sector 8 is still writable
    Program Page              ${SECTOR8}  0xFFFFFFFF
    Flag Should Be Clear      ${PROER}
    Clear Status
    # Disable Sector Write Protection with the correct password
    Cmd  0x5554  0xAA
    Cmd  0xAAA8  0x55
    Cmd  0x553C  0x0
    Cmd  0xAAA8  0x11
    Cmd  0xAAA8  0x22
    Cmd  0x5558  0x05
    Flag Should Be Clear      ${PROER}
    Flag Should Be Set        ${0x2000000}
    Program Page              ${SECTOR7}  0xFFFFFFFF
    Flag Should Be Clear      ${PROER}
    ${v}=                     Read Word  ${SECTOR7}
    Should Be Equal As Integers  ${v}  ${0xFFFFFFFF}
    # Resume Protection (UCB0 is not confirmed, so WPRODIS0 stays set), a wrong password gives PROER
    Cmd  0x5554  0xAA
    Cmd  0xAAA8  0x55
    Cmd  0x553C  0x0
    Cmd  0xAAA8  0x99
    Cmd  0xAAA8  0x99
    Cmd  0x5558  0x05
    Flag Should Be Set        ${PROER}
