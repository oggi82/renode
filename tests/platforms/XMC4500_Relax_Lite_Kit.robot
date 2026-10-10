*** Variables ***
${UART}                       sysbus.usic0ch0
# TODO: Upstream needs the firmware hosted at dl.antmicro.com; until then a locally built ELF is expected in the repository root.
${ELF}                        ${CURDIR}/../../xmc4500_main.elf

*** Test Cases ***
Should Print Hello World On USIC0 Channel 0
    Execute Command           set bin @${ELF}
    Execute Command           include @scripts/single-node/xmc4500_relax_lite_kit.resc

    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     hello world
