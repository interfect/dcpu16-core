library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CPU is
    port (
        clk: in std_logic;
        -- If set, clear all registers and start executaion at 0x0000
        rst: in std_logic;
        -- If set, pause execution
        hold: in std_logic;
        -- Interface with memory
        memory_write: out std_logic;
        memory_address: out std_logic_vector(15 downto 0);
        memory_data_stored: out std_logic_vector(15 downto 0);
        memory_data_loaded: in std_logic_vector(15 downto 0)
    );
end CPU;

architecture Behavioral of CPU is
    -- We model words as logic vectors since sometimes we treat values as signed.
    subtype Word is std_logic_vector(15 downto 0);
    -- Current state of all the generic registers
    type RegisterSet is array(0 to 7) of Word;
    signal registers: RegisterSet;
    -- Special registers
    signal program_counter: Word;
    
    -- Current main instruction word being worked on
    signal instruction: Word;
    -- Decoded parts of the instruction
    -- Is this a basic instruction or a special one?
    signal instruction_is_basic: std_logic;
    
    -- If a basic instruction, it has an opcode, an a operand, and a b operand
    subtype Opcode is std_logic_vector(4 downto 0);
    -- We want to be able to initialize opcode constants succinctly, but we can't write a function to do it, because if the constant is the result of a function call then it isn't locally static and can't be used in case patterns.
    signal instruction_basic_opcode: Opcode;
    -- Operand a has 6 bits; high first bit is a literal value
    subtype LongOperand is std_logic_vector(5 downto 0);
    signal instruction_operand_a: LongOperand;
    -- Operand b can only have 5 bits, no literals.
    subtype ShortOperand is std_logic_vector(4 downto 0);
    signal instruction_operand_b: ShortOperand;
    -- If a special instruction, it has an opcode and an a operand but no b operand.
    signal instruction_special_opcode: Opcode;
    
    -- To move the operand values around we need some wires.
    -- Do we want to read from operand a?
    signal read_a: std_logic;
    -- Do we want to write to operand a?
    signal write_a: std_logic;
    -- This is the loaded operand a, when applicable.
    signal operand_a_in: Word;
    -- Do we want to read from operand b?
    signal read_b: std_logic;
    -- Do we want to write to operand b?
    signal write_b: std_logic;
    -- This is what we're going to store to operand b, when applicable.
    signal operand_b_out: Word;
    
    -- These are the supported instruction opcodes
    constant OP_SET: Opcode := 5x"01";
    
    constant OP_IFB: Opcode := 5x"10";
    constant OP_IFC: Opcode := 5x"11";
    constant OP_IFE: Opcode := 5x"12";
    constant OP_IFN: Opcode := 5x"13";
    constant OP_IFG: Opcode := 5x"14";
    constant OP_IFA: Opcode := 5x"15";
    constant OP_IFL: Opcode := 5x"16";
    constant OP_IFU: Opcode := 5x"17";
    
    constant OP_STI: Opcode := 5x"1e";
    constant OP_STD: Opcode := 5x"1f";
    
begin

    
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset the system
                instruction <= (others => '0');
                registers <= (others => (others => '0'));
                program_counter <= (others => '0');
            else
                -- Normal operation
                -- Load instruction from memory
                memory_write <= '0';
                memory_address <= program_counter;
                instruction <= memory_data_loaded;
                
                -- Decode it
                if instruction(4 downto 0) = "00000" then
                    -- Special instruction
                    instruction_is_basic <= '0';
                    -- Unpack the aaaaaaooooo00000 format
                    instruction_special_opcode <= instruction(9 downto 5);
                    instruction_operand_a <= instruction(15 downto 10);
                else
                    -- Basic instruction
                    instruction_is_basic <= '1';
                    -- Unpack the aaaaaabbbbbooooo format
                    instruction_basic_opcode <= instruction(4 downto 0);
                    instruction_operand_b <= instruction(9 downto 5);
                    instruction_operand_a <= instruction(15 downto 10);
                end if;
                
                -- Decide what directions our operands are going in
                if instruction_is_basic = '1' then
                    -- Basic instructions always read a and never write it
                    read_a <= '1';
                    write_a <= '0';
                    case instruction_basic_opcode is
                        -- Everything but set instructions needs to read from b
                        when OP_SET | OP_STI | OP_STD =>
                            read_b <= '0';
                        when others =>
                            read_b <= '1';
                    end case;
                    
                    case instruction_basic_opcode is
                        -- Everything but conditionals needs to write to B.
                        -- We could look at the conditional bit pattern but we actually want to depand on the constants.
                        when OP_IFB | OP_IFC | OP_IFE | OP_IFN | OP_IFG | OP_IFA | OP_IFL | OP_IFU =>
                            write_b <= '0';
                        when others =>
                            write_b <= '1'; 
                    end case;
                else
                    -- Special instructions have no operand b at all
                    read_b <= '0';
                    write_b <= '0';
                    
                    -- TODO: Implement
                    write_a <= '0';
                    read_a <= '0';
                end if;
                
                -- Do the reads
                if read_a = '1' then
                    if instruction_operand_a(5) = '0' then
                        -- Not a literal, so a short operand
                        if instruction_operand_a(4 downto 3) = "00" then
                            -- Top bits of short operand are 0: register value
                            operand_a_in <= registers(to_integer(unsigned(instruction_operand_a(2 downto 0))));
                        end if;
                    end if;
                end if;
                
                if instruction_is_basic = '1' then
                    -- We need to read a, possibly read b, and write to b
                    case instruction_basic_opcode is
                        when OP_SET =>
                            -- Need to take what we loaded from a and store to b
                            operand_b_out <= operand_a_in;
                        when others =>
                            -- TODO: Implement
                            operand_b_out <= (others => '0');
                    end case;
                    
                else
                    -- TODO: Special instructions
                    -- Some read a, some write a
                end if;
                
                -- Do the writes
                
                if write_b = '1' then
                    if instruction_operand_b(4 downto 3) = "00" then
                        -- Top bits of short operand are 0: register value
                        registers(to_integer(unsigned(instruction_operand_b(2 downto 0)))) <= operand_b_out;
                    end if;
                end if;
                
                -- Increment PC
                program_counter <= std_logic_vector(unsigned(program_counter) + to_unsigned(1, 16));
                
            end if;
        end if;
    end process;



end Behavioral;


