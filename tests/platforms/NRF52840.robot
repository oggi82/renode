*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

${NO_DMA}=  SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...  uart0:                                  ${\n}
...  ${SPACE*4}easyDMA: false                ${\n}
...  uart1:                                  ${\n}
...  ${SPACE*4}easyDMA: false                ${\n}
...  """

${DMA}=     SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...  uart0:                                  ${\n}
...  ${SPACE*4}easyDMA: true                 ${\n}
...  uart1:                                  ${\n}
...  ${SPACE*4}easyDMA: true                 ${\n}
...  """

${ADXL_SPI}=     SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...                                          ${\n}
...  adxl372: Sensors.ADXL372 @ spi2         ${\n}
...                                          ${\n}
...  gpio0:                                  ${\n}
...  ${SPACE*4}22 -> adxl372@0 // CS         ${\n}
...  """

${ADXL_I2C}=     SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...                                          ${\n}
...  adxl372: Sensors.ADXL372 @ twi1 0x11    ${\n}
...  """

${BUTTON_LED}=     SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...                                          ${\n}
...  gpio0:                                  ${\n}
...  ${SPACE*4}13 -> led@0                   ${\n}
...                                          ${\n}
...  button: Miscellaneous.Button @ gpio0 11 ${\n} 
...  ${SPACE*4}-> gpio0@11                   ${\n}
...                                          ${\n}
...  led: Miscellaneous.LED @ gpio0 13       ${\n}
...  """

*** Keywords ***
Create Machine
    [Arguments]              ${platform}  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString ${platform}

    Execute Command          sysbus LoadELF ${URI}/${elf}

Run ZephyrRTOS Shell
    [Arguments]               ${platform}  ${elf}

    Create Machine            ${platform}  ${elf}
    Create Terminal Tester    ${UART}

    Execute Command           showAnalyzer ${UART}

    Start Emulation
    Wait For Prompt On Uart   uart:~$
    Write Line To Uart        demo ping
    Wait For Line On Uart     pong

*** Test Cases ***
Should Run ZephyrRTOS Shell On UART
    Run ZephyrRTOS Shell      ${NO_DMA}  zephyr_shell_nrf52840.elf-s_1110556-9653ab7fffe1427c50fa6b837e55edab38925681

Should Run ZephyrRTOS Shell On UARTE
    Run ZephyrRTOS Shell      ${DMA}     renode-nrf52840-zephyr_shell_module.elf-gf8d05cf-s_1310072-c00fbffd6b65c6238877c4fe52e8228c2a38bf1f


Should Run Alarm Sample
    Create Machine            ${NO_DMA}  zephyr_alarm_nRF52840.elf-s_489392-49a2ec3fda2f0337fe72521f08e51ecb0fd8d616
    Create Terminal Tester    ${UART}

    Execute Command           showAnalyzer ${UART}

    Start Emulation

    Wait For Line On Uart     !!! Alarm !!!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:02

    Wait For Line On Uart     !!! Alarm !!!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:06

Should Handle LED and Button
    Create Machine            ${BUTTON_LED}  nrf52840--zephyr_button.elf-s_660440-50c3b674193c8105624dae389420904e2036f9c0
    Create Terminal Tester    ${UART}

    Execute Command           emulation CreateLEDTester "lt" sysbus.gpio0.led

    Start Emulation
    Wait For Line On Uart     Booting Zephyr OS
    Wait For Line On Uart     Press the button

    Execute Command           lt AssertState False 0
    Execute Command           sysbus.gpio0.button Press
    Sleep           1s
    Execute Command           lt AssertState True 0
    Execute Command           sysbus.gpio0.button Release
    Sleep           1s
    # TODO: those sleeps shouldn't be necessary!
    Execute Command           lt AssertState False 0

Should Handle SPI
    Create Machine            ${ADXL_SPI}  nrf52840--zephyr_adxl372_spi.elf-s_993780-1dedb945dae92c07f1b4d955719bfb1f1e604173
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.spi2.adxl372 AccelerationX 0
    Execute Command           sysbus.spi2.adxl372 AccelerationY 0
    Execute Command           sysbus.spi2.adxl372 AccelerationZ 0 

    Start Emulation
    Wait For Line On Uart     Booting Zephyr OS
    Wait For Line On Uart     0.00 g

    Execute Command           sysbus.spi2.adxl372 AccelerationX 1
    Execute Command           sysbus.spi2.adxl372 AccelerationY 0
    Execute Command           sysbus.spi2.adxl372 AccelerationZ 0 

    Wait For Line On Uart     1.00 g

    Execute Command           sysbus.spi2.adxl372 AccelerationX 2
    Execute Command           sysbus.spi2.adxl372 AccelerationY 2
    Execute Command           sysbus.spi2.adxl372 AccelerationZ 0 

    Wait For Line On Uart     2.83 g

    Execute Command           sysbus.spi2.adxl372 AccelerationX 3
    Execute Command           sysbus.spi2.adxl372 AccelerationY 3
    Execute Command           sysbus.spi2.adxl372 AccelerationZ 3

    Wait For Line On Uart     5.20 g

Should Handle I2C
    Create Machine            ${ADXL_I2C}  nrf52840--zephyr_adxl372_i2c.elf-s_944004-aacf7d772ebcc5a26c156f78ebdef2e03f803cc3
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.twi1.adxl372 AccelerationX 0
    Execute Command           sysbus.twi1.adxl372 AccelerationY 0
    Execute Command           sysbus.twi1.adxl372 AccelerationZ 0 

    Start Emulation
    Wait For Line On Uart     Booting Zephyr OS
    Wait For Line On Uart     0.00 g

    Execute Command           sysbus.twi1.adxl372 AccelerationX 1
    Execute Command           sysbus.twi1.adxl372 AccelerationY 0
    Execute Command           sysbus.twi1.adxl372 AccelerationZ 0 

    Wait For Line On Uart     1.00 g

    Execute Command           sysbus.twi1.adxl372 AccelerationX 2
    Execute Command           sysbus.twi1.adxl372 AccelerationY 2
    Execute Command           sysbus.twi1.adxl372 AccelerationZ 0 

    Wait For Line On Uart     2.83 g

    Execute Command           sysbus.twi1.adxl372 AccelerationX 3
    Execute Command           sysbus.twi1.adxl372 AccelerationY 3
    Execute Command           sysbus.twi1.adxl372 AccelerationZ 3

    Wait For Line On Uart     5.20 g
