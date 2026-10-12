*** Settings ***
Library                       OperatingSystem
Library                       Process

*** Variables ***
# Directory with the Infineon example projects; override with the XMC_EXAMPLES_DIR environment variable
${XMC_EXAMPLES_DIR}           %{XMC_EXAMPLES_DIR=%{HOME}/mtw}
${XMC_TARGET}                 APP_KIT_XMC45_RELAX_V1
${XMC_RESC}                   scripts/single-node/xmc4500_relax_lite_kit.resc
${XMC_UART}                   sysbus.usic0ch0

*** Keywords ***
Build Example
    [Documentation]           Builds the example with 'make all' and returns the path of the resulting ELF.
    [Arguments]               ${example}
    ${dir}=                   Set Variable  ${XMC_EXAMPLES_DIR}/${example}
    Directory Should Exist    ${dir}  msg=Example ${example} not found in ${XMC_EXAMPLES_DIR}
    ${result}=                Run Process  make  all  -j8  cwd=${dir}
    Should Be Equal As Integers  ${result.rc}  0  msg=Building ${example} failed:\n${result.stdout}\n${result.stderr}
    @{elfs}=                  List Files In Directory  ${dir}/build/${XMC_TARGET}/Debug  pattern=*.elf  absolute=True
    Should Not Be Empty       ${elfs}  msg=No ELF produced by ${example}
    [Return]                  ${elfs}[0]

Create XMC4500 Machine
    [Documentation]           Builds the example, creates the Relax Lite Kit machine and loads the example ELF.
    [Arguments]               ${example}
    ${elf}=                   Build Example  ${example}
    Execute Command           set bin @${elf}
    Execute Command           include @${XMC_RESC}

Create XMC4500 Machine With UART Tester
    [Documentation]           As above, plus a terminal tester on USIC0 channel 0 (the on-board debugger UART).
    [Arguments]               ${example}  ${uart}=${XMC_UART}
    Create XMC4500 Machine    ${example}
    ${tester}=                Create Terminal Tester  ${uart}
    [Return]                  ${tester}
