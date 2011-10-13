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
        console.log("ROM length is #{@array.length}")
    
    load: (address) -> @array[address - @base]
    store: (address, value) -> throw "Cannot write to ROM!"

class Sheila
    load: (address) ->
        console.log "Sheila read from 0x#{(address & 0xff).toString(16)}"
        0

    store: (address, value) ->
        console.log "Sheila write to 0x#{(address & 0xff).toString(16)}"

class Cpu
    constructor: (@memory_map) ->
        @reg_A = 0
        @reg_X = 0
        @reg_Y = 0
        @reg_PC = 0
        @reg_SP = 0
        @flag_Z = 0
        @flag_N = 0
        @flag_V = 0
        @flag_I = 0
        @flag_D = 0
        
    run: ->
        console.log("Starting CPU")
        @reg_PC = @loadWord(0xfffc)
        console.log("Reset vector: #{@reg_PC.toString(16)}")
        halted = false
        until halted
            try
                @execute()
            catch error
                halted = true
                alert("CPU halted: #{error}")
        null
    
    execute: ->
        op = @load(@reg_PC)
        hexOp = (if op < 16 then '0' else '') + op.toString(16)
        methodName = "op_#{hexOp}"
        if methodName of this
            console.log("PC = #{@reg_PC.toString(16)}; op #{hexOp}")
            offset = this[methodName]()
            @reg_PC += offset
        else
            throw "Opcode #{hexOp} not implemented"
    
    # Direct 8- and 16-bit loads and stores
    load: (address) -> @memory_map[address >> 8].load(address)
    store: (address, value) -> @memory_map[address >> 8].store(address, value)
    loadWord: (address) ->
        @memory_map[address >> 8].load(address) |
        @memory_map[address >> 8].load(address + 1) << 8
    storeWord: (address, value) ->
        @memory_map[address >> 8].store(address, value & 0xff) |
        @memory_map[address >> 8].store(address + 1, value >> 8) << 8
    
    # Immediate mode
    load_imm: => @load(@reg_PC + 1)
    store_imm: (value) => @store(@reg_PC + 1, value)
    
    # Absolute mode
    load_abs: => @load(@loadWord(@reg_PC + 1))
    store_abs: (value) => @store(@loadWord(@reg_PC + 1), value)
    
    # Absolute, X mode
    load_absx: => @load(@loadWord(@reg_PC + 1) + @reg_X)
    store_absx: (value) => @store(@loadWord(@reg_PC + 1) + @reg_X)
    
    # Absolute, Y mode
    load_absy: => @load(@loadWord(@reg_PC + 1) + @reg_Y)
    store_absy: (value) => @store(@loadWord(@reg_PC + 1) + @reg_Y)
    
    # Zero page mode
    load_zp: => @load(@load(@reg_PC + 1))
    store_zp: (value) => @store(@load(@reg_PC + 1), value)
    
    # Zero page, X mode
    load_zpx: => @load(@load(@reg_PC + 1) + @reg_X)
    store_zpx: (value) => @store(@load(@reg_PC + 1) + @reg_X, value)
    
    # Accumulator mode
    load_a: => @reg_A
    store_a: (value) => @reg_A = value
    
    # Pre-indexed, X mode
    load_idxx: => @load(@loadWord(@load(@reg_PC + 1) + @reg_X))
    store_idxx: => @store(@loadWord(@load(@reg_PC + 1) + @reg_X), value)
    
    # Post-indexed, Y mode
    load_idxy: => @load(@loadWord(@load(@reg_PC + 1)) + @reg_X)
    store_idxy: (value) => @store(@loadWord(@load(@reg_PC + 1)) + @reg_X, value)
    
    # Opcodes
    op_0a: -> @op_ASL(@load_a, @store_a); 1
    op_20: -> @op_JSR(); 0
    op_2a: -> @op_ROL(@load_a, @store_a); 1
    op_48: -> @op_PHA(); 1
    op_49: -> @op_EOR(@load_imm, @store_imm); 2
    op_60: -> @op_RTS(); 1
    op_78: -> @op_SEI(); 1
    op_85: -> @op_STA(@store_zp); 2
    op_86: -> @op_STX(@store_zp); 2
    op_88: -> @op_DEY(); 1
    op_8a: -> @op_TXA(); 1
    op_8c: -> @op_STY(@store_abs); 3
    op_8d: -> @op_STA(@store_abs); 3
    op_8e: -> @op_STX(@store_abs); 3
    op_90: -> @op_branch(-> not @flag_C); 0
    op_91: -> @op_STA(@store_idxy); 2
    op_95: -> @op_STA(@store_zpx); 2
    op_99: -> @op_STA(@store_absy); 3
    op_9a: -> @op_TXS(); 1
    op_9d: -> @op_STA(@store_absx); 3
    op_a0: -> @op_LDY(@load_imm); 2
    op_a2: -> @op_LDX(@load_imm); 2
    op_a5: -> @op_LDA(@load_zp); 2
    op_a8: -> @op_TAY(); 1
    op_a9: -> @op_LDA(@load_imm); 2
    op_ad: -> @op_LDA(@load_abs); 3
    op_ae: -> @op_LDX(@load_abs); 3
    op_b0: -> @op_branch(-> @flag_C); 0
    op_b9: -> @op_LDA(@load_absy); 3
    op_c5: -> @op_CMP(@load_zp); 2
    op_c8: -> @op_INY(); 1
    op_ca: -> @op_DEX(); 1
    op_d0: -> @op_branch(-> @flag_Z); 0
    op_d6: -> @op_DEC(@load_zpx, @store_zpx); 2
    op_d8: -> @op_CLD(); 1
    op_e0: -> @op_CPX(@load_imm); 2
    op_e8: -> @op_INX(); 1
    op_ee: -> @op_INC(@load_abs, @store_abs); 3
    op_f0: -> @op_branch(-> not @flag_Z); 0

    
    # Operations
    op_ASL: (load, store) ->
        value = load()
        value = value << 1
        @flag_C = if value & 0x100 then 1 else 0
        value &= 0xff
        store value
        @flag_N = if value & 0x80 then 1 else 0
        @flag_Z = if value == 0 then 1 else 0
    
    op_branch: (predicate) ->
        @reg_PC += if predicate()
            offset = @load(@reg_PC + 1)
            if offset > 0x7f
                offset = (~offset + 1)
            (offset + 2) & 0xff
        else
            2
        console.log "Branching to #{@reg_PC.toString(16)}"
    
    op_CMP: (load) ->
        value = load()
        @flag_C = if @reg_A >= value then 1 else 0
        @flag_Z = if @reg_A == value then 1 else 0
        @flag_N = if (@reg_A - value) | 0x80 then 1 else 0
    
    op_CPX: (load) ->
        value = load()
        @flag_C = if @reg_X >= value then 1 else 0
        @flag_Z = if @reg_X == value then 1 else 0
        @flag_N = if (@reg_X - value) | 0x80 then 1 else 0

    op_DEX: ->
        @reg_X = (@reg_X - 1) & 0xff
        @flag_N = if @reg_X & 0x80 then 1 else 0
        @flag_Z = if @reg_X == 0 then 1 else 0
    
    op_DEY: ->
        @reg_Y = (@reg_Y - 1) & 0xff
        @flag_N = if @reg_Y & 0x80 then 1 else 0
        @flag_Z = if @reg_Y == 0 then 1 else 0
    
    op_EOR: (load, store) ->
        @reg_A ^= load()
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A | 0x80 then 1 else 0

    op_INC: (load, store) ->
        value = (load() + 1) & 0xff
        store value
        @flag_N = if value & 0x80 then 1 else 0
        @flag_Z = if value == 0 then 1 else 0

    op_INX: ->
        @reg_X = (@reg_X + 1) & 0xff
        @flag_N = if @reg_X & 0x80 then 1 else 0
        @flag_Z = if @reg_X == 0 then 1 else 0

    op_INY: ->
        @reg_Y = (@reg_Y + 1) & 0xff
        @flag_N = if @reg_Y & 0x80 then 1 else 0
        @flag_Z = if @reg_Y == 0 then 1 else 0
    
    op_JSR: ->
        @storeWord(@reg_SP, @reg_PC)
        @reg_SP += 2
        @reg_PC = @loadWord(@reg_PC + 1)
        console.log "Jumping to subrouting at #{@reg_PC.toString(16)}"
    
    op_PHA: -> @store(0x100 + @reg_SP++, @reg_A)
    
    op_ROL: (load, store) ->
        value = load()
        value <<= 1
        value |= if value & 0x100 then 1 else 0
        value &= 0xff
        store value
        @flag_C = @value & 1
        @flag_Z = if value == 0 then 1 else 0
        @flag_N = if value & 0x80 then 1 else 0
    
    op_RTS: ->
        @reg_SP -= 2
        @reg_PC = @loadWord(@reg_SP)
    
    op_SEI: -> @flag_I = 1

    op_STA: (store) -> store @reg_A
    
    op_STX: (store) -> store @reg_X
    
    op_STY: (store) -> store @reg_Y

    op_TAY: ->
        @reg_Y = @reg_A
        @flag_Z = if @reg_Y == 0 then 1 else 0
        @flag_N = if @reg_Y | 0x80 then 1 else 0

    op_TXA: ->
        @reg_SP = @reg_X
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A | 0x80 then 1 else 0

    op_TXS: -> @reg_SP = @reg_X
    
    op_LDX: (load) ->
        @reg_X = load()
        @flag_Z = if @reg_X == 0 then 1 else 0
        @flag_N = if @reg_X | 0x80 then 1 else 0
    
    op_LDY: (load) ->
        @reg_Y = load()
        @flag_Z = if @reg_Y == 0 then 1 else 0
        @flag_N = if @reg_Y | 0x80 then 1 else 0
    
    op_LDA: (load) ->
        @reg_A = load()
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A | 0x80 then 1 else 0
    
    op_DEC: (load, store) ->
        value = load() - 1
        if value == -1
            value = 255
        store value
        @flag_Z = if value == 0 then 1 else 0
        @flag_N = if value | 0x80 then 1 else 0
    
    op_CLD: -> @flag_D = 0

class BbcMicro
    constructor: ->
        memory_devices =
            r: new Ram(0x8000)
            o: new Rom(0xc000, os_rom)
            p: new UnmappedPage("paged rom")
            f: new UnmappedPage("FRED")
            j: new UnmappedPage("JIM")
            s: new Sheila
        memory_map =
            "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr" +
            "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr" +
            "pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp" +
            "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooofjso"
        @cpu = new Cpu(memory_devices[p] for p in memory_map)
    
    start: -> @cpu.run()
        
micro = new BbcMicro
micro.start()
