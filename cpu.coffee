class Memory
    constructor: ->
        @ram = new Uint8Array(0x8000)
        @rom = os_rom
    
    read: (address) ->
        if address < 0x8000
            @ram[address]
        else if 0xc000 <= address <= 0xffff
            @rom[address - 0xc000]
        else
            throw "Invalid read address (#{address.toString(16)})"
    
    write: (address, value) ->
        if address < 0x8000
            @ram[address] = value
        else
            throw "Invalid write address (#{address.toString(16)})"

class Cpu
    constructor: ->
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
        
        @memory = new Memory
    
    run: ->
        console.log("Starting CPU")
        @reg_PC = @memory.read(0xfffc) | @memory.read(0xfffd) << 8
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
        op = @memory.read(@reg_PC)
        methodName = "op_#{op}"
        if methodName of this
            console.log("PC = #{@reg_PC.toString(16)}; op #{op}")
            @reg_PC += this[methodName]()
        else
            throw "Opcode #{op} (#{op.toString(16)}) not implemented"
    
    immediate_addr: -> @reg_PC + 1
    absolute_addr: -> @memory.read(@reg_PC + 1) | @memory.read(@reg_PC + 2) << 8
    zp_x_addr: -> @memory.read(@reg_PC + 1) + @reg_X

    immediate_load: => @memory.read(@immediate_addr())
    immediate_store: (value) => @memory.write(@immediate_addr(), value)

    absolute_load: => @memory.read(@absolute_addr())
    absolute_store: (value) => @memory.write(@absolute_addr(), value)

    zp_x_load: => @memory.read(@zp_x_addr())
    zp_x_store: (value) => @memory.write(@zp_x_addr(), value)

    reg_a_load: => @reg_A
    reg_a_store: (value) => @reg_A = value
    
    op_120: -> @op_SEI(); 1
    op_141: -> @op_STA(@absolute_store); 3
    op_154: -> @op_TXS(); 1
    op_162: -> @op_LDX(@immediate_load); 2
    op_169: -> @op_LDA(@immediate_load); 2
    op_173: -> @op_LDA(@absolute_load); 3
    op_214: -> @op_DEC(@zp_x_load, @zp_x_store); 2
    op_216: -> @op_CLD(); 1
    
    op_SEI: -> @flag_I = 1

    op_STA: (store) -> store(@reg_A)

    op_TXS: -> @reg_SP = @reg_X
    
    op_LDX: (load) ->
        @reg_X = load()
        @flag_Z = 1 if @reg_X == 0
        @flag_N = 1 if @reg_X | 0x80
    
    op_LDA: (load) ->
        @reg_A = load()
        @flag_Z = 1 if @reg_A == 0
        @flag_N = 1 if @reg_A | 0x80
    
    op_DEC: (load, store) ->
        value = load() - 1
        if value == -1
            value = 255
        store(value)
        @flag_Z = 1 if value == 0
        @flag_N = 1 if value | 0x80
    
    op_CLD: -> @flag_D = 0

cpu = new Cpu
cpu.run()
