*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${csr_script}=  SEPARATOR=
...  if request.isRead:                                                  ${\n}${SPACE}
...      cpu.DebugLog('CSR read!')                                       ${\n}
...  elif request.isWrite:                                               ${\n}${SPACE}
...      cpu.DebugLog('CSR written: {}!'.format(hex(request.value)))

*** Keywords ***
Create Machine
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { cpuType: \\"rv64imac\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"

    Execute Command                             sysbus.cpu ExecutionMode SingleStep
    Execute Command                             sysbus.cpu PC 0x0

Load Code To Memory
    # li x1, 0x147
    Execute Command                             sysbus WriteDoubleWord 0x0 0x14700093 

    # csrw 0xf0d, x1
    Execute Command                             sysbus WriteDoubleWord 0x4 0xf0d09073

    # csrr x2, 0xf0d
    Execute Command                             sysbus WriteDoubleWord 0x8 0xf0d02173

Register Should Be Equal
    [Arguments]                                 ${reg_name}     ${value}
    ${reg}=  Execute Command                    sysbus.cpu GetRegisterUnsafe ${reg_name[1:]}
    Should Be Equal                             ${value}        ${reg.replace('\n', '')}

PC Should Be Equal
    [Arguments]                                 ${value}
    Register Should Be Equal                    x32             ${value}

*** Test Cases ***
Should Install Custom 16-bit Instruction
    Create Machine
    Create Log Tester

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus WriteWord 0x0 0xb38f

    Execute Command                             log "--- start ---"
    Start Emulation
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Wait For LogEntry                           --- start ---
    Wait For LogEntry                           custom instruction executed! 
    Wait For LogEntry                           --- stop ---

Should Install Custom 32-bit Instruction
    Create Machine
    Create Log Tester

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "10110011100011110000111110000010" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0f82

    Execute Command                             log "--- start ---"
    Start Emulation
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Wait For LogEntry                           --- start ---
    Wait For LogEntry                           custom instruction executed! 
    Wait For LogEntry                           --- stop ---

Should Install Custom 64-bit Instruction
    Create Machine
    Create Log Tester

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111000011111000001010110011100011110000111110000010" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0f82
    Execute Command                             sysbus WriteDoubleWord 0x4 0xb38f0f82

    Execute Command                             log "--- start ---"
    Start Emulation
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Wait For LogEntry                           --- start ---
    Wait For LogEntry                           custom instruction executed! 
    Wait For LogEntry                           --- stop ---

Should Override An Existing 32-bit Instruction
    Create Machine
    Create Log Tester

    # normally this instruction means "li x1, 0x147"
    # but we override it with a custom implementation
    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "00010100011100000000000010010011" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus WriteDoubleWord 0x0 0x14700093

    Register Should Be Equal                    x1  0x0

    Execute Command                             log "--- start ---"
    Start Emulation
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Register Should Be Equal                    x1  0x0

    Wait For LogEntry                           --- start ---
    Wait For LogEntry                           custom instruction executed! 
    Wait For LogEntry                           --- stop ---

Should Register Simple Custom CSR
    Create Machine

    Execute Command                             sysbus.cpu CSRValidation 0
    Execute Command                             sysbus.cpu RegisterCustomCSR "test csr" 0xf0d 3

    Load Code To Memory

    Register Should Be Equal                    x1  0x0
    Register Should Be Equal                    x2  0x0

    Start Emulation
    Execute Command                             sysbus.cpu Step 3
    
    PC Should Be Equal                          0xc

    Register Should Be Equal                    x1  0x147
    Register Should Be Equal                    x2  0x147

Should Register Custom CSR
    Create Machine
    Create Log Tester

    Execute Command                             sysbus.cpu CSRValidation 0
    Execute Command                             sysbus.cpu RegisterCSRHandlerFromString 0xf0d "${csr_script}"

    Load Code To Memory

    Start Emulation
    Execute Command                             sysbus.cpu Step 3
    
    ${pc}=  Execute Command                     sysbus.cpu PC
    Should Be Equal                             0xc  ${pc.replace('\n', '')}

    Register Should Be Equal                    x1  0x147
    Register Should Be Equal                    x2  0x147

    Wait For LogEntry                           CSR written: 0x147L! 
    Wait For LogEntry                           CSR read! 