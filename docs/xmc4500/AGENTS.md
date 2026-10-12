# Arbeitsauftrag für Komponenten-Agents (XMC4500 in Renode)

Du entwickelst **eine Komponente** (slug im Auftrag) der Renode-Plattform für den XMC4500 / Relax Lite Kit.
Lies zuerst: `docs/xmc4500/README.md` (Ablauf, Konventionen, Testaufbau), `docs/xmc4500/platform.md` (was es schon gibt),
`docs/xmc4500/TEMPLATE.md` (Doku-Vorlage), `.claude/skills/renode-add-mcu/SKILL.md` (Renode-Erfahrungen).

## Arbeitsverzeichnis und Regeln

- Arbeite **ausschließlich** in deinem Workspace `/home/oggi/src/renode-xmc-<slug>` (Branch `xmc4500-<slug>` im Repo **und** im Submodul `src/Infrastructure`). Das Hauptverzeichnis `/home/oggi/src/renode` fasst du nicht an.
- Skripte immer aus deinem Workspace aufrufen (`scripts/xmc4500/...`, `./build.sh --net --skip-fetch`, `./renode`); sie ermitteln den Root selbst.
- **Nicht ändern**: `~/mtw` (Beispiele, Handbücher), Dateien anderer Komponenten, `tests/tests.yaml`. Gemeinsame Dateien (`platforms/cpus/xmc4500.repl`, `Infrastructure.csproj`) nur **additiv** (eigener Block, kurze Kommentarzeile, nichts umformatieren).
- Commits: klein und thematisch, Submodul zuerst, dann Hauptrepo; englische Messages im Stil der vorhandenen, Zeile am Ende: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Gezielt `git add <Pfade>`, kein `-A`. **Kein Push.**
- Builds seriell halten (nicht mehrere `build.sh` gleichzeitig in deinem Workspace); Ausgabe in eine Datei umleiten und mit `grep -E " error |Error\(s\)"` auswerten.
- Immer `timeout` und begrenzte `RunFor`-Zeiten verwenden. ELFs nie mit dem Read-Tool öffnen (`arm-none-eabi-readelf/nm/objdump`).

## Quellen (in dieser Reihenfolge verwenden)

1. **XMC-Lib und CMSIS-Header** in `~/mtw/mtb_shared/mtb-xmclib-cat3/release-v4.7.0/`:
   `CMSIS/Infineon/COMPONENT_XMC4500/Include/XMC4500.h` (Registerstrukturen, Bitpositionen `*_Pos/*_Msk`, `IRQn_Type`-Nummern, Basisadressen)
   und `XMCLib/src/xmc_*.c`, `XMCLib/inc/xmc_*.h` (so benutzt die Firmware die Hardware – daraus ergibt sich, was das Modell können muss).
2. **Reference Manual** (`~/mtw/docs/infineon-xmc4500-rm-v1.6-2016-um-en.pdf`); als Text bereits vorhanden: `/tmp/claude-1000/-home-oggi-src-renode/ffccb438-11bf-4690-8c8d-d6558e03b0fd/scratchpad/docs/rm.txt` (nur lesen; `grep -n` nach Registernamen/Kapiteln; die PDF-Seiten notfalls mit `pdftotext -f N -l M -layout`). Kit-Beschreibung: `.../docs/kit.txt`.
3. Die Beispiele selbst: `~/mtw/<Example>/main.c`, `README.md`, `bsps/.../config/GeneratedSource/*.c` (Konfiguration der Peripherals).

Das Reference Manual und der Header haben Vorrang vor dem Gedächtnis. Die bereits vorhandenen Modelle (`XMC4XXX_SCU`, `XMC4XXX_GPIOPort`, `XMC4XXX_UART`) wurden aus Disassembly und Erinnerung gebaut – wenn du Abweichungen zum Header findest, korrigiere sie in deinem Bereich (und melde sie im Report).

## Ziele

1. **Alle Beispiele deiner Komponente** bauen (`scripts/xmc4500/build-example.sh <Example>`) und in Renode **sinnvoll** zum Laufen bringen: Das Verhalten, das `main.c`/`README.md` beschreiben (UART-Ausgabe, LED, Registerwerte, Interrupts), muss beobachtbar eintreten. Iteriere nach dem Ablauf in der README (`run-example.sh`, Warnungen `non existing peripheral` / `Unhandled …` abarbeiten).
2. **Tests**: `tests/platforms/xmc4500/<slug>.robot` mit mindestens einem Test-Case je Beispiel (Kopf: `Resource    ${CURDIR}/xmc4500.resource`). Kriterien müssen aus dem Verhalten der Firmware folgen (UART-Text, LED-Blinken/-Zustand, Symbol-/Registerwerte, Zähler), keine blinden Sleeps. Grün mit `scripts/xmc4500/test.sh <slug>`. Geht ein Beispiel nicht (fehlende Fremd-Komponente, Hardware nicht simulierbar), dann dokumentiere den Grund und markiere den Test mit `[Tags]  skip` + `Skip  <Grund>` statt etwas vorzutäuschen.
3. **Doku**: `docs/xmc4500/<slug>.md` nach `TEMPLATE.md`, mit korrekten Mermaid-Diagrammen (Use Cases, Klassen, Sequenz, Aktivität/Zustand), Registertabelle, Vereinfachungen, manuelle Schritte, Testtabelle. Kein Text, der nicht zum implementierten Stand passt.
4. **Report** (kurz, ehrlich): je Beispiel Status (läuft / teilweise / geht nicht + Grund), Testergebnis (Ausgabe von `test.sh`), Commit-Hashes (Submodul + Repo), offene Punkte und Abweichungen zum Plan, ggf. Befunde zu anderen Komponenten (z. B. falsche IRQ-Nummer im Basismodell).

## Hinweise

- C#-Stil: wie die Nachbardateien (4 Leerzeichen, Allman, `Registers`-Enum, `Define(...)`), Dateiname = Klassenname `XMC4XXX_<Name>`; neue Dateien in `Infrastructure.csproj` eintragen.
- Zeitverhalten dort genau, wo ein Test es beobachtet (Timer-Perioden, PWM, Baudrate); Hardware-Statusbits ohne Beobachter dürfen sofort fertig sein.
- Eingänge für Tests stimulieren: `sysbus.port1.button1 Press/Release`, GPIO-Verbindungen im Monitor, Werte per `sysbus WriteDoubleWord`, oder kleine Test-Hilfsperipherals (z. B. einstellbare ADC-Spannung als Monitor-Property).
- Wenn du am Basismodell (SCU, PORT, UART/USIC, NVIC-Verdrahtung) etwas brauchst, das nicht deine Komponente ist: kleinste mögliche additive Änderung, und im Report nennen.
