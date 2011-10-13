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
    load: (address) -> throw "Sheila ain't done yet, yo"
    store: (address, value) -> throw "Sheila ain't done yet, yo"

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
        methodName = "op_#{op}"
        if methodName of this
            console.log("PC = #{@reg_PC.toString(16)}; op #{op}")
            @reg_PC += this[methodName]()
        else
            throw "Opcode #{op} (#{op.toString(16)}) not implemented"
    
    # Direct 8- and 16-bit loads and stores
    load: (address) -> @memory_map[address >> 8].load(address)
    store: (address, value) -> @memory_map[address >> 8].store(address, value)
    loadWord: (address) ->
        @memory_map[address >> 8].load(address) |
        @memory_map[address >> 8].load(address + 1) << 8
    storeWord: (address, value) ->
        @memory_map[address >> 8].store(address, value & 0xff) |
        @memory_map[address >> 8].store(address + 1, value >> 8) << 8
    
    # Addressing modes
    load_imm: => @load(@reg_PC + 1)
    store_imm: (value) => @store(@reg_PC + 1, value)
    load_abs: => @load(@loadWord(@reg_PC + 1))
    store_abs: (value) => @store(@loadWord(@reg_PC + 1), value)
    load_zpx: => @load(@load(@reg_PC + 1) + @reg_X)
    store_zpx: (value) => @store(@load(@reg_PC + 1) + @reg_X, value)
    load_a: => @reg_A
    store_a: (value) => @reg_A = value

    # Opcodes
    op_10: -> @op_ASL(@load_a, @store_a); 1
    op_72: -> @op_PHA(); 1
    op_120: -> @op_SEI(); 1
    op_141: -> @op_STA(@store_abs); 3
    op_154: -> @op_TXS(); 1
    op_162: -> @op_LDX(@load_imm); 2
    op_169: -> @op_LDA(@load_imm); 2
    op_173: -> @op_LDA(@load_abs); 3
    op_214: -> @op_DEC(@load_zpx, @store_zpx); 2
    op_216: -> @op_CLD(); 1
    op_240: -> @op_BEQ(); 0
    
    # Operations
    op_ASL: (load, store) ->
        value = load()
        console.log("ASL input is #{value}")
        value = value << 1
        @flag_C = if value & 0x100 then 1 else 0
        value &= 0xff
        store(value)
        @flag_N = if value & 0x80 then 1 else 0
        @flag_Z = if value == 0 then 1 else 0
    
    op_BEQ: ->
        offset = @load(@reg_PC + 1)
        if offset > 0x7f
            offset = (~offset + 1) & 0xff
        @reg_PC += if @flag_Z then offset else 2
        console.log(@reg_PC.toString(16))
        throw "STOP!"
    
    op_PHA: -> @store(0x100 + @reg_SP++, @reg_A)
    
    op_SEI: -> @flag_I = 1

    op_STA: (store) -> store(@reg_A)

    op_TXS: -> @reg_SP = @reg_X
    
    op_LDX: (load) ->
        @reg_X = load()
        @flag_Z = if @reg_X == 0 then 1 else 0
        @flag_N = if @reg_X | 0x80 then 1 else 0
    
    op_LDA: (load) ->
        @reg_A = load()
        @flag_Z = if @reg_A == 0 then 1 else 0
        @flag_N = if @reg_A | 0x80 then 1 else 0
    
    op_DEC: (load, store) ->
        value = load() - 1
        if value == -1
            value = 255
        store(value)
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
