*** Settings ***
Documentation                 Testing the NXP K64F platform

*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/nxp-k6xf.repl

    Execute Command           sysbus LoadELF ${URI}/${elf}

    Create Terminal Tester    ${UART}

*** Test Cases ***
Should Run Zephyr Tests for UART
    [Documentation]           Runs Zephyr's basic uart tests
    Create Machine            nxp_k64f--zephyr_basic_uart.elf-s_618844-2d588c6899efaae76a7a27136fd8cff667bbcb6f

    Start Emulation
    Wait For Line On Uart     Please send characters to serial console    
    Write Line To Uart        The quick brown fox jumps over the lazy dog
    Wait For Line On Uart     Please send characters to serial console    
    Write Line To Uart        The quick brown fox jumps over the lazy dog
    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Run Zephyr Tests for TCP
    [Documentation]           Runs Zephyr's tests from tests/net/tcp
    Create Machine            zephyr-frdm_k64f-test-net-tcp-simple.elf-s_3198764-62e4449d27377b47e885c185ea6af673889434cd

    Start Emulation
    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL
