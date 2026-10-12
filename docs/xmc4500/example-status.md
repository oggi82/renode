# Beispiel-Status (Integrator-Uebersicht)

Stand: Branch `xmc4500-rtos-misc` nach Merge von `xmc4500` (gemergt: platform, can, flash, vadc-dac, ccu4, ccu8, scu-wdt-rtc, gpio-eru, dma-fce, posif, usic). Jedes Beispiel wurde mit `scripts/xmc4500/build-example.sh all` gebaut (alle bauen) und mit `scripts/xmc4500/run-example.sh <Example> 2` fuer 2 virtuelle Sekunden ausgefuehrt; ausgewertet wurden `WARNING`/`ERROR`-Zeilen im Log. "Laeuft ohne Warnungen" sagt nichts darueber, ob das Verhalten stimmt (dafuer gibt es die Robot-Tests der Komponenten). Die Beispiele ohne Warnungen der vor dem usic/posif-Merge gemessenen Komponenten wurden nicht erneut gemessen, die von usic/posif betroffenen (I2C, SPI, UART, POSIF, DMA-UART/SPI) nach dem Merge.

| Beispiel | Komponente | Laeuft ohne Warnungen | Erste Warnung / fehlendes Peripheral |
|---|---|---|---|
| CAN_Loopback | can | ja | - |
| CAN_Receiver | can | ja | - |
| CAN_Transmitter | can | ja | - |
| CCU4_PWM | ccu4 | ja | - |
| CCU4_Timer | ccu4 | ja | - |
| CCU4_Timer_Concatenation | ccu4 | ja | - |
| CCU8_Capture | ccu8 | ja | - |
| CCU8_PWM | ccu8 | ja | - |
| CCU8_PWM_Complementary | ccu8 | ja | - |
| CCU8_Timer | ccu8 | ja | - |
| CCU8_Timer_Concatenation | ccu8 | ja | - |
| CCU8_Timer_Synchronous_Start | ccu8 | ja | - |
| DMA_FCE | dma-fce | ja | - |
| DMA_GPIO | dma-fce | ja | - |
| DMA_M2M | dma-fce | ja | - |
| DMA_PWM | dma-fce | ja | - |
| DMA_Ring_Buffer | dma-fce | ja | - |
| FCE_CRC | dma-fce | ja | - |
| SPI_DMA | dma-fce | ja | - |
| UART_DMA | dma-fce | ja | - |
| Flash_EEPROM | flash | ja | - |
| Flash_Program | flash | ja | - |
| ERU_EXTINT | gpio-eru | ja | - |
| ERU_HIB_IO | gpio-eru | ja | - |
| GPIO_Toggle | gpio-eru | ja | - |
| Empty_XMC_App | platform | ja | - |
| UART_Printf | platform | ja | - |
| POSIF_Hall | posif | ja | - |
| POSIF_QD | posif | ja | - |
| FreeRTOS_Blinky | rtos-misc | nein | nvic: Trying to set the priority for interrupt 16 to 0xFF (harmlos: FreeRTOS-Port ermittelt die Zahl der Prioritaetsbits) |
| emUSB-Device_HID_Generic | rtos-misc | nein | ReadDoubleWord from non existing peripheral at 0x5004003C (USB0 OTG-Kern, nicht modelliert, siehe rtos-misc.md) |
| Brownout_Detection | scu-wdt-rtc | ja | - |
| RTC_Alarm | scu-wdt-rtc | ja | - |
| SCU_Sleep | scu-wdt-rtc | ja | - |
| WDT_FEED | scu-wdt-rtc | nein | wdt: Bad service: timer value 32767 is below the window lower bound 720000000 |
| WDT_Prewarning | scu-wdt-rtc | nein | wdt: Bad service: timer value 32767 is below the window lower bound 720000000 |
| I2C_Master_and_Slave | usic | ja | - |
| SPI_EXTTRG_transmit | usic | ja | - |
| SPI_Master | usic | ja | - |
| SPI_QSPI_Flash | usic | ja | - |
| UART_Transmit | usic | ja | - |
| UART_Transmit_Receive_FIFO_Interrupts | usic | ja | - |
| CCU8_TRIGGERED_VADC_MEASUREMENT | vadc-dac | ja | - |
| DAC_Sine_Wave | vadc-dac | ja | - |
| VADC_Background | vadc-dac | ja | - |
| VADC_EMUX | vadc-dac | ja | - |
| VADC_Queue | vadc-dac | ja | - |
| VADC_Scan | vadc-dac | ja | - |

Offene Punkte:

- `emUSB-Device_HID_Generic`: USB0 (DWC_otg) nicht modelliert, Test uebersprungen (Begruendung in [rtos-misc.md](rtos-misc.md)).
- `WDT_FEED`, `WDT_Prewarning`: Warnung `Bad service` des WDT-Modells beim Fenster-Watchdog (Komponente `scu-wdt-rtc`, Window-Untergrenze 720000000 gegenueber Zaehlerstand 32767); der Integrator sollte pruefen, ob die Firmware das Fenster wirklich so konfiguriert.
