class Ui
    constructor: ->
        @element = document.getElementById('log')
        @pc = document.getElementById('pc')
        @a = document.getElementById('a')
        @x = document.getElementById('x')
        @y = document.getElementById('y')
        @sp = document.getElementById('sp')
        @output = document.getElementById('output')
    
    log: (message) ->
        @element.appendChild document.createTextNode(message)
        @element.appendChild document.createElement("br")
    
    updateRegisters: (pc, a, x, y, sp) ->
        @pc.innerText = pc.toString(16)
        @a.innerText = "#{a.toString(16)} (#{a})"
        @x.innerText = "#{x.toString(16)} (#{x})"
        @y.innerText = "#{y.toString(16)} (#{y})"
        @sp.innerText = sp.toString(16)
    
    writeChar: (char) ->
        console.log "OSWRCH: #{char.toString()}"
        @output.innerText += String.fromCharCode(char)

ui = new Ui('log')

class UnmappedPage
    constructor: (@name) ->
    
    load: (address) -> throw "Unmapped memory page (#{@name}) at #{address.toString(16)}"
    store: (address, value) -> throw "Unmapped memory page (#{@name}) at #{address.toString(16)}"

class Ram
    constructor: (size) ->
        @array = new Uint8Array(size)
    
    load: (address) -> @array[address]
    store: (address, value) -> @array[address] = value

class Rom
    constructor: (@base, @array) ->
    
    load: (address) -> @array[address - @base]
    store: (address, value) -> throw "Cannot write to ROM!"

class PagedRom
    constructor: (@ui, @base, @roms) ->
        @rom = 0
    
    load: (address) -> if @rom of @roms then @roms[@rom][address - @base] else 0
    
    store: (address, value) -> throw "Cannot write to ROM!"

    select: (rom) ->
        @ui.log "[PagedRom] Switching to rom #{rom}"
        @rom = rom

class Sheila
    constructor: (@ui, @callbacks) ->
    
    storers:
        0xfe30: (value) -> @callbacks['selectRom']?(value)
    
    load: (address) ->
        @ui.log "Sheila read from 0x#{address.toString(16)}"
        0

    store: (address, value) ->
        @ui.log "Sheila write to 0x#{address.toString(16)}"
        @storers[address]?.call(this, value)

class Cpu
    constructor: (@ui, @memory_map) ->
        @reg_A = 0
        @reg_X = 0
        @reg_Y = 0
        @reg_PC = @loadWord(0xfffc)
        @reg_SP = 0xff

        @flag_C = 0
        @flag_Z = 0
        @flag_I = 0
        @flag_D = 0
        @flag_B = 0
        @flag_V = 0
        @flag_N = 0
        
        @halted = false
        
    run: =>
        for i in [1..1000] by 1
            @step()
            if @halted
                break
        unless @halted then window.setTimeout(@run, 0)
        null
    
    step: ->
        if @reg_PC == 0xe0a4
            @ui.writeChar(@reg_A)
            @op_RTS()
        else
            @execute()
    
    execute: ->
        if @reg_PC == 0xdb6e then console.log "Should have written 'BBC Computer'"
        op = @load(@reg_PC)
        hexOp = (if op < 16 then '0' else '') + op.toString(16)
        methodName = "op_#{hexOp}"
        @log("Opcode #{hexOp}")
        try
            if methodName of this
                offset = this[methodName]()
                @reg_PC += offset
            else
                throw "Opcode #{hexOp} not implemented"
        catch error
            @halted = true
            alert("CPU halted at #{@reg_PC.toString(16)}: #{error}")
        @ui.updateRegisters(@reg_PC, @reg_A, @reg_X, @reg_Y, @reg_SP)
    
    halt: -> @halted = true
    
    # Direct 8- and 16-bit loads and stores
    load: (address) ->
        address &= 0xffff
        @memory_map[address >> 8].load(address)

    store: (address, value) ->
        address &= 0xffff
        @memory_map[address >> 8].store(address, value)

    loadWord: (address) ->
        address &= 0xffff
        @memory_map[address >> 8].load(address) |
        @memory_map[address >> 8].load(address + 1) << 8

    storeWord: (address, value) ->
        address &= 0xffff
        @memory_map[address >> 8].store(address, value & 0xff)
        @memory_map[address >> 8].store(address + 1, value >> 8)
    
    push: (value) ->
        @store(0x100 + @reg_SP--, value)
        @log "push #{value.toString(16)} -> reg_SP=#{@reg_SP.toString(16)}" 

    pull: ->
        value = @load(0x100 + ++@reg_SP)
        @log "pull -> #{value.toString(16)}, reg_SP=#{@reg_SP.toString(16)}" 
        value
    
    pushWord: (value) ->
        @storeWord(0x100 + @reg_SP - 1, value)
        @reg_SP -= 2
        @log "pushWord #{value.toString(16)} -> reg_SP=#{@reg_SP.toString(16)}" 

    pullWord: ->
        @reg_SP += 2
        value = @loadWord(0x100 + @reg_SP - 1)
        @log "pullWord -> #{value.toString(16)}, reg_SP=#{@reg_SP.toString(16)}" 
        value
    
    # Immediate mode
    load_imm: => @load(@reg_PC + 1)
    store_imm: (value) => @store(@reg_PC + 1, value)
    
    # Absolute mode
    load_abs: => @load(@loadWord(@reg_PC + 1))
    store_abs: (value) => @store(@loadWord(@reg_PC + 1), value)
    load_abs_addr: => @loadWord(@reg_PC + 1)
    
    # Absolute, X mode
    load_absx: => @load(@loadWord(@reg_PC + 1) + @reg_X)
    store_absx: (value) => @store(@loadWord(@reg_PC + 1) + @reg_X, value)
    
    # Absolute, Y mode
    load_absy: => @load(@loadWord(@reg_PC + 1) + @reg_Y)
    store_absy: (value) => @store(@loadWord(@reg_PC + 1) + @reg_Y, value)
    
    # Indirect mode
    load_ind_addr: => @loadWord(@loadWord(@reg_PC + 1))
    
    # Zero page mode
    load_zp: => @load(@load(@reg_PC + 1))
    store_zp: (value) => @store(@load(@reg_PC + 1), value)
    
    # Zero page, X mode
    load_zpx: => @load(@load(@reg_PC + 1) + @reg_X)
    store_zpx: (value) => @store(@load(@reg_PC + 1) + @reg_X, value)
    
    # Accumulator mode
    load_acc: => @reg_A
    store_acc: (value) => @reg_A = value
    
    # Pre-indexed, X mode
    load_idxx: => @load(@loadWord(@load(@reg_PC + 1) + @reg_X))
    store_idxx: (value) => @store(@loadWord(@load(@reg_PC + 1) + @reg_X), value)
    
    # Post-indexed, Y mode
    load_idxy: => @load(@loadWord(@load(@reg_PC + 1)) + @reg_Y)
    store_idxy: (value) => @store(@loadWord(@load(@reg_PC + 1)) + @reg_Y, value)
    
    # Opcodes
    op_00: -> @op_BRK(); 0
    op_01: -> @op_ORA(@load_idxx); 2
    op_05: -> @op_ORA(@load_zp); 2
    op_06: -> @op_ASL(@load_zp, @store_zp); 2
    op_08: -> @op_PHP(); 1
    op_09: -> @op_ORA(@load_imm); 2
    op_0a: -> @op_ASL(@load_acc, @store_acc); 1
    op_0d: -> @op_ORA(@load_abs); 3
    op_0e: -> @op_ASL(@load_abs, @store_abs); 3
    op_10: -> @branch(-> not @flag_N); 0
    op_11: -> @op_ORA(@load_idxy); 2
    op_15: -> @op_ORA(@load_zpx); 2
    op_16: -> @op_ASL(@load_zpx, @store_zpx); 2
    op_18: -> @op_CLC(); 1
    op_19: -> @op_ORA(@load_absy); 3
    op_1d: -> @op_ORA(@load_absx); 3
    op_1e: -> @op_ASL(@load_absx, @store_absx); 3
    op_20: -> @op_JSR(); 0
    op_21: -> @op_AND(@load_idxx); 2
    op_24: -> @op_BIT(@load_zp); 2
    op_25: -> @op_AND(@load_zp); 2
    op_26: -> @op_ROL(@load_zp, @store_zp); 2
    op_28: -> @op_PLP(); 1
    op_29: -> @op_AND(@load_imm); 2
    op_2a: -> @op_ROL(@load_acc, @store_acc); 1
    op_2c: -> @op_BIT(@load_abs); 3
    op_2d: -> @op_AND(@load_abs); 3
    op_2e: -> @op_ROL(@load_abs, @store_abs); 3
    op_30: -> @branch(-> @flag_N); 0
    op_31: -> @op_AND(@load_idxy); 2
    op_35: -> @op_AND(@load_zpx); 2
    op_36: -> @op_ROL(@load_zpx, @store_zpx); 2
    op_38: -> @op_SEC(); 1
    op_39: -> @op_AND(@load_absy); 3
    op_3d: -> @op_AND(@load_absx); 3
    op_3e: -> @op_ROL(@load_absx, @store_absx); 3
    op_40: -> @op_RTI(); 0
    op_41: -> @op_EOR(@load_idxx, @store_idxx); 2
    op_45: -> @op_EOR(@load_zp, @store_zp); 2
    op_46: -> @op_LSR(@load_zp, @store_zp); 2
    op_48: -> @op_PHA(); 1
    op_49: -> @op_EOR(@load_imm, @store_imm); 2
    op_4a: -> @op_LSR(@load_acc, @store_acc); 1
    op_4b: -> @op_ASR(@load_imm, @store_imm); 2
    op_4c: -> @op_JMP(@load_abs_addr); 0
    op_4d: -> @op_EOR(@load_abs, @store_abs); 3
    op_4e: -> @op_LSR(@load_abs, @store_abs); 3
    op_50: -> @branch(-> not @flag_V); 0
    op_51: -> @op_EOR(@load_idxy, @store_idxy); 2
    op_55: -> @op_EOR(@load_zpx, @store_zpx); 2
    op_56: -> @op_LSR(@load_zpx, @store_zpx); 2
    op_58: -> @op_CLI(); 1
    op_59: -> @op_EOR(@load_absy, @store_absy); 3
    op_5d: -> @op_EOR(@load_absx, @store_absx); 3
    op_5e: -> @op_LSR(@load_absx, @store_absx); 3
    op_60: -> @op_RTS(); 0
    op_61: -> @op_ADC(@load_idxx); 2
    op_65: -> @op_ADC(@load_zp); 2
    op_66: -> @op_ROR(@load_zp, @store_zp); 2
    op_68: -> @op_PLA(); 1
    op_69: -> @op_ADC(@load_imm); 2
    op_6a: -> @op_ROR(@load_acc, @store_acc); 1
    op_6c: -> @op_JMP(@load_ind_addr); 0
    op_6d: -> @op_ADC(@load_abs); 3
    op_6e: -> @op_ROR(@load_abs, @store_abs); 3
    op_70: -> @branch(-> @flag_V); 0
    op_71: -> @op_ADC(@load_idxy); 2
    op_75: -> @op_ADC(@load_zpx); 2
    op_76: -> @op_ROR(@load_zpx, @store_zpx); 2
    op_78: -> @op_SEI(); 1
    op_79: -> @op_ADC(@load_absy); 3
    op_7d: -> @op_ADC(@load_absx); 3
    op_7e: -> @op_ROR(@load_absx, @store_absx); 3
    op_81: -> @op_STA(@store_idxx); 2
    op_84: -> @op_STY(@store_zp); 2
    op_85: -> @op_STA(@store_zp); 2
    op_86: -> @op_STX(@store_zp); 2
    op_88: -> @op_DEY(); 1
    op_8a: -> @op_TXA(); 1
    op_8c: -> @op_STY(@store_abs); 3
    op_8d: -> @op_STA(@store_abs); 3
    op_8e: -> @op_STX(@store_abs); 3
    op_90: -> @branch(-> not @flag_C); 0
    op_91: -> @op_STA(@store_idxy); 2
    op_94: -> @op_STY(@store_zpx); 2
    op_95: -> @op_STA(@store_zpx); 2
    op_96: -> @op_STX(@store_zpy); 2
    op_98: -> @op_TYA(); 1
    op_99: -> @op_STA(@store_absy); 3
    op_9a: -> @op_TXS(); 1
    op_9d: -> @op_STA(@store_absx); 3
    op_a0: -> @op_LDY(@load_imm); 2
    op_a1: -> @op_LDA(@load_idxx); 2
    op_a2: -> @op_LDX(@load_imm); 2
    op_a4: -> @op_LDY(@load_zp); 2
    op_a5: -> @op_LDA(@load_zp); 2
    op_a6: -> @op_LDX(@load_zp); 2
    op_a8: -> @op_TAY(); 1
    op_a9: -> @op_LDA(@load_imm); 2
    op_aa: -> @op_TAX(); 1
    op_ac: -> @op_LDY(@load_abs); 3
    op_ad: -> @op_LDA(@load_abs); 3
    op_ae: -> @op_LDX(@load_abs); 3
    op_b0: -> @branch(-> @flag_C); 0
    op_b1: -> @op_LDA(@load_idxy); 2
    op_b4: -> @op_LDY(@load_zpx); 2
    op_b5: -> @op_LDA(@load_zpx); 2
    op_b6: -> @op_LDX(@load_zpy); 2
    op_b8: -> @op_CLV(); 1
    op_b9: -> @op_LDA(@load_absy); 3
    op_ba: -> @op_TSX(); 1
    op_bc: -> @op_LDY(@load_absx); 3
    op_bd: -> @op_LDA(@load_absx); 3
    op_be: -> @op_LDX(@load_absy); 3
    op_c0: -> @op_CPY(@load_imm); 2
    op_c1: -> @op_CMP(@load_idxx); 2
    op_c4: -> @op_CPY(@load_zp); 2
    op_c5: -> @op_CMP(@load_zp); 2
    op_c6: -> @op_DEC(@load_zp, @store_zp); 2
    op_c8: -> @op_INY(); 1
    op_c9: -> @op_CMP(@load_imm); 2
    op_ca: -> @op_DEX(); 1
    op_cc: -> @op_CPY(@load_abs); 3
    op_cd: -> @op_CMP(@load_abs); 3
    op_ce: -> @op_DEC(@load_abs, @store_abs); 3
    op_d0: -> @branch(-> not @flag_Z); 0
    op_d1: -> @op_CMP(@load_idxy); 2
    op_d5: -> @op_CMP(@load_zpx); 2
    op_d6: -> @op_DEC(@load_zpx, @store_zpx); 2
    op_d8: -> @op_CLD(); 1
    op_d9: -> @op_CMP(@load_absy); 3
    op_dd: -> @op_CMP(@load_absx); 3
    op_de: -> @op_DEC(@load_absx, @store_absx); 3
    op_e0: -> @op_CPX(@load_imm); 2
    op_e1: -> @op_SBC(@load_idxx); 2
    op_e4: -> @op_CPX(@load_zp); 2
    op_e5: -> @op_SBC(@load_zp); 2
    op_e6: -> @op_INC(@load_zp, @store_zp); 2
    op_e8: -> @op_INX(); 1
    op_e9: -> @op_SBC(@load_imm); 2
    op_ea: -> @op_NOP(); 1
    op_ec: -> @op_CPX(@load_abs); 3
    op_ed: -> @op_SBC(@load_abs); 3
    op_ee: -> @op_INC(@load_abs, @store_abs); 3
    op_f0: -> @branch(-> @flag_Z); 0
    op_f1: -> @op_SBC(@load_idxy); 2
    op_f5: -> @op_SBC(@load_zpx); 2
    op_f6: -> @op_INC(@load_zpx, @store_zpx); 2
    op_f8: -> @op_SED(); 1
    op_f9: -> @op_SBC(@load_absy); 3
    op_fd: -> @op_SBC(@load_absx); 3
    op_fe: -> @op_INC(@load_absx, @store_absx); 3

    # Operations
    op_ADC: (load) ->
        value = @reg_A + load() + @flag_C
        @flag_C = if value & 0x100 then 1 else 0
        @reg_A = value & 0xff
        @flag_Z = if value == 0 then 1 else 0
        @flag_N = if value & 0x80 then 1 else 0
        @flag_V = if value & 0x80 != @reg_A & 0x80 then 1 else 0
    
    op_AND: (load) ->
        @reg_A &= load()
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A & 0x80 then 1 else 0
    
    op_ASL: (load, store) ->
        value = load()
        value = value << 1
        @flag_C = if value & 0x100 then 1 else 0
        value &= 0xff
        store value
        @flag_N = if value & 0x80 then 1 else 0
        @flag_Z = if value == 0 then 1 else 0
    
    op_BIT: (load) ->
        value = @reg_A & load()
        @flag_Z = if value == 0 then 1 else 0
        @flag_V = if value & 0x40 then 1 else 0
        @flag_N = if value & 0x80 then 1 else 0
    
    op_BRK: ->
        @log "BRK"
        @pushWord(@reg_PC + 2)
        @flag_B = 1
        @push(@getStatusRegister())
        @flag_I = 1
        @reg_PC = @loadWord(0xfffe)
    
    op_CLC: -> @flag_C = 0
    
    op_CLD: -> @flag_D = 0
    
    op_CLI: -> @flag_I = 0
    
    op_CLV: -> @flag_V = 0
    
    op_CMP: (load) ->
        value = load()
        @flag_C = if @reg_A >= value then 1 else 0
        @flag_Z = if @reg_A == value then 1 else 0
        @flag_N = if (@reg_A - value) & 0x80 then 1 else 0
    
    op_CPX: (load) ->
        value = load()
        @flag_C = if @reg_X >= value then 1 else 0
        @flag_Z = if @reg_X == value then 1 else 0
        @flag_N = if (@reg_X - value) & 0x80 then 1 else 0
    
    op_CPY: (load) ->
        value = load()
        @flag_C = if @reg_Y >= value then 1 else 0
        @flag_Z = if @reg_Y == value then 1 else 0
        @flag_N = if (@reg_Y - value) & 0x80 then 1 else 0
    
    op_DEC: (load, store) ->
        value = load() - 1
        if value == -1
            value = 255
        store value
        @flag_Z = if value == 0 then 1 else 0
        @flag_N = if value & 0x80 then 1 else 0
    
    op_DEX: ->
        @reg_X = (@reg_X - 1) & 0xff
        @flag_Z = if @reg_X == 0 then 1 else 0
        @flag_N = if @reg_X & 0x80 then 1 else 0
    
    op_DEY: ->
        @reg_Y = (@reg_Y - 1) & 0xff
        @flag_Z = if @reg_Y == 0 then 1 else 0
        @flag_N = if @reg_Y & 0x80 then 1 else 0
    
    op_EOR: (load, store) ->
        @reg_A ^= load()
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A & 0x80 then 1 else 0

    op_INC: (load, store) ->
        value = (load() + 1) & 0xff
        store value
        @flag_Z = if value == 0 then 1 else 0
        @flag_N = if value & 0x80 then 1 else 0

    op_INX: ->
        @reg_X = (@reg_X + 1) & 0xff
        @flag_Z = if @reg_X == 0 then 1 else 0
        @flag_N = if @reg_X & 0x80 then 1 else 0

    op_INY: ->
        @reg_Y = (@reg_Y + 1) & 0xff
        @flag_Z = if @reg_Y == 0 then 1 else 0
        @flag_N = if @reg_Y & 0x80 then 1 else 0
    
    op_JMP: (load) ->
        addr = load()
        @log "JMP to #{addr.toString(16)}"
        @reg_PC = addr
    
    op_JSR: ->
        @pushWord(@reg_PC + 2)
        @reg_PC = @loadWord(@reg_PC + 1)
        @log "Jumping to subroutine at #{@reg_PC.toString(16)}"
    
    op_LDA: (load) ->
        @reg_A = load()
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A & 0x80 then 1 else 0
    
    op_LDX: (load) ->
        @reg_X = load()
        @flag_Z = if @reg_X == 0 then 1 else 0
        @flag_N = if @reg_X & 0x80 then 1 else 0
    
    op_LDY: (load) ->
        @reg_Y = load()
        @flag_Z = if @reg_Y == 0 then 1 else 0
        @flag_N = if @reg_Y & 0x80 then 1 else 0
    
    op_LSR: (load, store) ->
        value = load()
        @flag_C = value & 1
        value = (value >> 1) & 0x7f
        store value
        @flag_Z = if value == 0 then 1 else 0
        @flag_N = 0
    
    op_ORA: (load) ->
        @reg_A |= load()
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A & 0x80 then 1 else 0
    
    op_PHA: -> @push(@reg_A)
    
    op_PHP: -> @push(@getStatusRegister())
    
    op_PLA: ->
        @reg_A = @pull()
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A & 0x80 then 1 else 0
    
    op_PLP: ->
        @setStatusRegister(@pull())
    
    op_ROL: (load, store) ->
        value = load()
        value <<= 1
        value |= if value & 0x100 then 1 else 0
        value &= 0xff
        store value
        @flag_C = value & 1
        @flag_Z = if value == 0 then 1 else 0
        @flag_N = if value & 0x80 then 1 else 0
    
    op_ROR: (load, store) ->
        value = load()
        value |= if @flag_C then 0x100 else 0
        @flag_C = value & 1
        value >>= 1
        store value
        @flag_Z = if value == 0 then 1 else 0
        @flag_N = if value & 0x80 then 1 else 0
    
    op_RTI: ->
        @setStatusRegister(@pull())
        @reg_PC = @pullWord()
        @log "Returning to #{@reg_PC.toString(16)} from interrupt"
    
    op_RTS: ->
        @reg_PC = @pullWord() + 1
        @log "Returning to #{@reg_PC.toString(16)}"
    
    op_SBC: (load) ->
        @reg_A -= load() + if @flag_C then 0 else 1
        @flag_V = if -128 <= @reg_A <= 127 then 0 else 1
        @flag_C = if @reg_A >= 0 then 1 else 0
        @flag_N = if @reg_A & 0x80 then 1 else 0
        @flag_Z = if @reg_A == 0 then 1 else 0
        @reg_A &= 0xff
    
    op_SEC: -> @flag_C = 1
    
    op_SED: -> throw "BCD mode not supported"
    
    op_SEI: -> @flag_I = 1

    op_STA: (store) -> store @reg_A
    
    op_STX: (store) -> store @reg_X
    
    op_STY: (store) -> store @reg_Y

    op_TAX: ->
        @reg_X = @reg_A
        @flag_Z = if @reg_X == 0 then 1 else 0
        @flag_N = if @reg_X & 0x80 then 1 else 0

    op_TAY: ->
        @reg_Y = @reg_A
        @flag_Z = if @reg_Y == 0 then 1 else 0
        @flag_N = if @reg_Y & 0x80 then 1 else 0
    
    op_TSX: ->
        @reg_X = @reg_SP
        @flag_Z = if @reg_X == 0 then 1 else 0
        @flag_N = if @reg_X & 0x80 then 1 else 0

    op_TXA: ->
        @reg_A = @reg_X
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A & 0x80 then 1 else 0

    op_TXS: -> @reg_SP = @reg_X
    
    op_TYA: ->
        @reg_A = @reg_Y
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A & 0x80 then 1 else 0
    
    branch: (predicate) ->
        offset =
            if predicate.call(this)
                offset = @load(@reg_PC + 1)
                if offset < 0x80 then offset else offset - 256
            else
                0
        # unless offset == 0 then @log "Branching to #{(@reg_PC + offset + 2).toString(16)}"
        if offset == -2 then throw "Infinitely looping branch"
        @reg_PC += offset + 2
    
    getStatusRegister: ->
        @flag_C | @flag_Z << 1 | @flag_I << 2 | @flag_D << 3 | @flag_B << 4 |
            @flag_V << 6 | @flag_N << 7
    
    setStatusRegister: (value) ->
        @flag_C = (value & 0x01)
        @flag_Z = (value & 0x02) >> 1
        @flag_I = (value & 0x04) >> 2
        @flag_D = (value & 0x08) >> 3
        @flag_B = (value & 0x10) >> 4
        @flag_V = (value & 0x40) >> 6
        @flag_N = (value & 0x80) >> 7
    
    log: (message) ->
        @ui.log("[#{@reg_PC.toString(16)}] #{message}")
    
class BbcMicro
    constructor: (ui) ->
        @pagedRom = new PagedRom(ui, 0x8000, {15: basic_rom})
        memoryDevices =
            r: new Ram(0x8000)
            o: new Rom(0xc000, os_rom)
            p: @pagedRom
            f: new UnmappedPage("FRED")
            j: new UnmappedPage("JIM")
            s: new Sheila(ui, {selectRom: (rom) => @pagedRom.select(rom)})
        memoryMap =
            "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr" +
            "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr" +
            "pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp" +
            "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooofjso"
        @cpu = new Cpu(ui, memoryDevices[p] for p in memoryMap)
    
    start: -> @cpu.run()

ui = new Ui
micro = new BbcMicro(ui)
micro.start()
