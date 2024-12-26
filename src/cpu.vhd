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
    -- We don't have a like 4 port memory so we need to sequence the reads and writes, so we need a state machine.
    -- Some operands depend on a next instruction word, which we evaluate immediately before evaluating that operand.
    -- Some operands have side effects (like moving the SP) but we only want to do that once even if the operand is being both read and written.
    -- See https://www.reddit.com/r/dcpu16/comments/suq7z/16_1_5_spec_question_sp_and_push_as_a_bvalue/ about how ADD PUSH only talks to one stack location.
    -- So we have to separate decode side effects on registers into their own states (where we also use the memory bus to get any next words).
    type State is (STATE_DECODE_INSTRUCTION, STATE_DECODE_A, STATE_READ_A, STATE_DECODE_B, STATE_READ_B, STATE_THINK, STATE_WRITE_A, STATE_WRITE_B);
    -- We can't call this state because the type is called State.
    signal sequence_state : State;

    -- We model words as logic vectors since sometimes we treat values as signed.
    subtype Word is std_logic_vector(15 downto 0);
    -- Current state of all the generic registers
    type RegisterSet is array(0 to 7) of Word;
    signal registers: RegisterSet;
    -- Special registers
    -- Program counter (PC). Also used for "next word" operations
    signal program_counter: Word;
    -- Stack pointer (SP), used for push/pop/jsr/ret
    signal stack_pointer: Word;
    -- Extended register (EX)
    signal extended: Word;

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
    -- Do we need a nextword for operand a?
    signal need_nextword_a: std_logic;
    -- And if so, what is it?
    signal nextword_a: Word;
    -- Address to read/write a at
    signal address_a: Word;
    -- This is the loaded operand a, when applicable.
    signal operand_a_in: Word;
    -- This is what we're going to store to operand a, when applicable
    signal operand_a_out: Word;
    -- Do we want to read from operand b?
    signal read_b: std_logic;
    -- Do we want to write to operand b?
    signal write_b: std_logic;
    -- Do we need a nextword for operand b?
    signal need_nextword_b: std_logic;
    -- And if so, what is it?
    signal nextword_b: Word;
    -- Address to read/write b at
    signal address_b: Word;
    -- This is the loaded operand b, when applicable.
    signal operand_b_in: Word;
    -- This is what we're going to store to operand b, when applicable.
    signal operand_b_out: Word;
    
    -- These are the supported instruction opcodes
    constant OP_SET: Opcode := 5x"01";
    constant OP_ADD: Opcode := 5x"02";
    constant OP_SUB: Opcode := 5x"03";
    
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

    -- These are the named operands (long, for a)
    constant LO_POP: LongOperand := 6x"18";
    constant LO_PEEK: LongOperand := 6x"19";
    constant LO_PICK: LongOperand := 6x"1a";
    constant LO_SP: LongOperand := 6x"1b";
    constant LO_PC: LongOperand := 6x"1c";
    constant LO_EX: LongOperand := 6x"1d";
    constant LO_DEREF: LongOperand := 6x"1e";
    constant LO_LITERAL: LongOperand := 6x"1f";

    -- These are the named operands (short, for b)
    constant SO_PUSH: ShortOperand := 5x"18";
    constant SO_PEEK: ShortOperand := 5x"19";
    constant SO_PICK: ShortOperand := 5x"1a";
    constant SO_SP: ShortOperand := 5x"1b";
    constant SO_PC: ShortOperand := 5x"1c";
    constant SO_EX: ShortOperand := 5x"1d";
    constant SO_DEREF: ShortOperand := 5x"1e";
    constant SO_LITERAL: ShortOperand := 5x"1f";

    -- These are the instruction category bit patterns (bits 4 and 3)
    constant SO_CAT_REG_VAL: std_logic_vector(1 downto 0) := "00";
    constant SO_CAT_REG_DEREF: std_logic_vector(1 downto 0) := "01";
    constant SO_CAT_REG_NEXTWORD_DEREF: std_logic_vector(1 downto 0) := "10";
    constant SO_CAT_OTHER: std_logic_vector(1 downto 0) := "11";


    
begin

    
    process (clk)
        -- Here's a 1-bit-wider result for carries
        variable computation_result: std_logic_vector(16 downto 0);
    begin
        if rst = '1' then
            -- Reset the system regardless of clock
            instruction <= (others => '0');
            registers <= (others => (others => '0'));
            program_counter <= (others => '0');
            stack_pointer <= (others => '0');
            extended <= (others => '0');
            sequence_state <= STATE_DECODE_INSTRUCTION;
        elsif rising_edge(clk) and hold = '0' then
            -- Clock is ticking and we are not stopped
            if sequence_state = STATE_DECODE_INSTRUCTION then
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
                        -- We could look at the conditional bit pattern but we actually want to depend on the constants.
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

                -- Decide if we need to get nextword values for a or b
                if instruction_operand_a(4 downto 3) = SO_CAT_REG_NEXTWORD_DEREF or
                    instruction_operand_a = LO_PICK or
                    instruction_operand_a = LO_DEREF or
                    instruction_operand_a = LO_LITERAL then

                    need_nextword_a <= '1';
                else
                    need_nextword_a <= '0';
                end if;
                if instruction_operand_b(4 downto 3) = SO_CAT_REG_NEXTWORD_DEREF or
                    instruction_operand_b = SO_PICK or
                    instruction_operand_b = SO_DEREF or
                    instruction_operand_b = SO_LITERAL then

                    need_nextword_b <= '1';
                else
                    need_nextword_b <= '0';
                end if;


                -- Always go to A decode state
                -- TODO: Do it all now if we don't need a memory read somehow
                sequence_state <= STATE_DECODE_A;

                -- Increment PC
                program_counter <= std_logic_vector(unsigned(program_counter) + to_unsigned(1, 16));

            elsif sequence_state = STATE_DECODE_A then
                --  If we need a next word, get it now
                if need_nextword_a then
                    -- Read word at PC for use by a
                    memory_write <= '0';
                    memory_address <= program_counter;
                    nextword_a <= memory_data_loaded;
                    -- Increment PC
                    program_counter <= std_logic_vector(unsigned(program_counter) + to_unsigned(1, 16));
                end if;

                if instruction_operand_a(5) = '0' then
                    -- Not a literal, so a short operand
                    if instruction_operand_a(4 downto 3) = SO_CAT_REG_DEREF then
                        -- Low top bit is set: register dereference
                        address_a <= registers(to_integer(unsigned(instruction_operand_a(2 downto 0))));
                    elsif instruction_operand_a(4 downto 3) = SO_CAT_REG_NEXTWORD_DEREF then
                        -- Dereference register plus next word
                        -- Already reading nextword but we can't pull it from there yet.
                        -- Unless we manually convert back to std_logic_vector, we can't resolve unsigned + unsigned.
                        address_a <= std_logic_vector(unsigned(registers(to_integer(unsigned(instruction_operand_a(2 downto 0))))) + unsigned(memory_data_loaded));
                    elsif instruction_operand_a(4 downto 3) = SO_CAT_OTHER then
                        case instruction_operand_a is
                            when LO_POP | LO_PEEK =>
                                -- USe memory at SP
                                address_a <= stack_pointer;
                                if instruction_operand_a = LO_POP then
                                    -- Increment SP
                                    stack_pointer <= std_logic_vector(unsigned(stack_pointer) + to_unsigned(1, 16));
                                end if;
                            when LO_PICK =>
                                -- Use memory address at SP offset
                                address_a <= std_logic_vector(unsigned(stack_pointer) + unsigned(memory_data_loaded));
                            when LO_DEREF =>
                                -- Use memory at address from next word
                                address_a <= memory_data_loaded;
                            when others =>
                                -- No need for an address
                        end case;
                    end if;
                end if;


                -- Figure out next state
                if read_a = '1' then
                    sequence_state <= STATE_READ_A;
                else
                    sequence_state <= STATE_DECODE_B;
                end if;

            elsif sequence_state = STATE_READ_A then
                -- Get A; might need a memory read
                -- TODO: skip the cycle if it doesn't
                -- Assumes read_a is 1 and address_a is set

                if instruction_operand_a(5) = '0' then
                    -- Not a literal, so a short operand
                    if instruction_operand_a(4 downto 3) = SO_CAT_REG_VAL then
                        -- Top bits of short operand are 0: register value
                        operand_a_in <= registers(to_integer(unsigned(instruction_operand_a(2 downto 0))));
                    elsif instruction_operand_a(4 downto 3) = SO_CAT_REG_DEREF then
                        -- Low top bit is set: register dereference
                        memory_write <= '0';
                        memory_address <= address_a;
                        operand_a_in <= memory_data_loaded;
                    elsif instruction_operand_a(4 downto 3) = SO_CAT_REG_NEXTWORD_DEREF then
                        -- Dereference register plus next word
                        -- Already calculated address
                        memory_write <= '0';
                        -- Unless we manually convert back to std_logic_vector, we can't resolve unsigned + unsigned.
                        memory_address <= address_a;
                        operand_a_in <= memory_data_loaded;
                    elsif instruction_operand_a(4 downto 3) = SO_CAT_OTHER then
                        case instruction_operand_a is
                            when LO_POP | LO_PEEK | LO_PICK | LO_DEREF =>
                                -- Read memory at loaded address
                                memory_write <= '0';
                                memory_address <= address_a;
                                operand_a_in <= memory_data_loaded;
                            when LO_SP =>
                                operand_a_in <= stack_pointer;
                            when LO_PC =>
                                operand_a_in <= program_counter;
                            when LO_EX =>
                                operand_a_in <= extended;
                            when LO_LITERAL =>
                                operand_a_in <= nextword_a;
                            when others =>
                                -- TODO: This should never happen
                                operand_a_in <= x"bada";
                        end case;
                    end if;
                else
                    -- Inline literal
                    operand_a_in <= std_logic_vector(x"ffff" + unsigned(instruction_operand_a(4 downto 0)));
                end if;

                sequence_state <= STATE_DECODE_B;

            elsif sequence_state = STATE_DECODE_B then

                if need_nextword_b then
                    -- Read word at PC for use by b
                    memory_write <= '0';
                    memory_address <= program_counter;
                    nextword_b <= memory_data_loaded;
                end if;

                if instruction_operand_b(4 downto 3) = SO_CAT_REG_DEREF then
                    -- Low top bit is set: register dereference
                    address_b <= registers(to_integer(unsigned(instruction_operand_b(2 downto 0))));
                elsif instruction_operand_b(4 downto 3) = SO_CAT_REG_NEXTWORD_DEREF then
                    -- Dereference register plus next word
                    -- Already reading nextword but we can't pull it from there yet.
                    -- Unless we manually convert back to std_logic_vector, we can't resolve unsigned + unsigned.
                    address_b <= std_logic_vector(unsigned(registers(to_integer(unsigned(instruction_operand_b(2 downto 0))))) + unsigned(memory_data_loaded));
                elsif instruction_operand_b(4 downto 3) = SO_CAT_OTHER then
                    case instruction_operand_b is
                        when SO_PUSH | SO_PEEK =>
                            -- Use memory before SP
                            address_b <= std_logic_vector(unsigned(stack_pointer) - to_unsigned(1, 16));
                            if instruction_operand_b = SO_PUSH then
                                -- Decrement SP
                                stack_pointer <= std_logic_vector(unsigned(stack_pointer) - to_unsigned(1, 16));
                            end if;
                        when SO_PICK =>
                            -- Use memory address at SP offset
                            address_b <= std_logic_vector(unsigned(stack_pointer) + unsigned(memory_data_loaded));
                        when SO_DEREF =>
                            -- Use memory at address from next word
                            address_b <= memory_data_loaded;
                        when others =>
                            -- No need for an address
                    end case;
                end if;

                -- Determine next state
                if read_b = '1' then
                    sequence_state <= STATE_READ_B;
                else
                    sequence_state <= STATE_THINK;
                end if;

                -- Increment PC
                program_counter <= std_logic_vector(unsigned(program_counter) + to_unsigned(1, 16));

            elsif sequence_state = STATE_READ_B then

                -- TODO: Unify short operand code with a
                if instruction_operand_b(4 downto 3) = SO_CAT_REG_VAL then
                    -- Top bits of short operand are 0: register value
                    operand_b_in <= registers(to_integer(unsigned(instruction_operand_b(2 downto 0))));
                elsif instruction_operand_b(4 downto 3) = SO_CAT_REG_DEREF then
                    -- Low top bit is set: register dereference
                    memory_write <= '0';
                    memory_address <= address_b;
                    operand_b_in <= memory_data_loaded;
                elsif instruction_operand_b(4 downto 3) = SO_CAT_REG_NEXTWORD_DEREF then
                    -- Dereference register plus next word
                    -- Already read next word
                    memory_write <= '0';
                    memory_address <= address_b;
                    operand_b_in <= memory_data_loaded;
                elsif instruction_operand_b(4 downto 3) = SO_CAT_OTHER then
                    case instruction_operand_b is
                        when SO_PUSH | SO_PEEK | SO_PICK | SO_DEREF =>
                            -- Read memory address determined earlier
                            memory_write <= '0';
                            memory_address <= address_b;
                            operand_b_in <= memory_data_loaded;
                        when SO_SP =>
                            operand_b_in <= stack_pointer;
                        when SO_PC =>
                            operand_b_in <= program_counter;
                        when SO_EX =>
                            operand_b_in <= extended;
                        when SO_LITERAL =>
                            operand_b_in <= nextword_b;
                        when others =>
                            -- TODO: This should never happen
                            operand_b_in <= x"badb";
                    end case;
                end if;

                sequence_state <= STATE_THINK;

            elsif sequence_state = STATE_THINK then
                -- Do the actual operations on operand_a_in, operand_b_in, operand_a_out, operand_b_out

                if instruction_is_basic = '1' then
                    case instruction_basic_opcode is
                        when OP_SET =>
                            -- Need to take what we loaded from a and store to b
                            operand_b_out <= operand_a_in;
                        when OP_ADD =>
                            computation_result := std_logic_vector(resize(unsigned(operand_a_in), 17) + resize(unsigned(operand_b_in), 17));
                            operand_b_out <= computation_result(15 downto 0);
                            if computation_result(16) = '1' then
                                extended <= x"0001";
                            else
                                extended <= x"0000";
                            end if;
                        when OP_SUB =>
                            computation_result := std_logic_vector(resize(unsigned(operand_a_in), 17) - resize(unsigned(operand_b_in), 17));
                            operand_b_out <= computation_result(15 downto 0);
                            if computation_result(16) = '1' then
                                extended <= x"ffff";
                            else
                                extended <= x"0000";
                            end if;
                            -- TODO: set EX
                        when others =>
                            -- TODO: Implement
                            operand_b_out <= (others => '0');
                    end case;
                else
                    -- TODO: Special instructions
                end if;

                if write_a = '1' then
                    sequence_state <= STATE_WRITE_A;
                elsif write_b = '1' then
                    sequence_state <= STATE_WRITE_B;
                else
                    sequence_state <= STATE_DECODE_INSTRUCTION;
                end if;

            elsif sequence_state = STATE_WRITE_A then
                -- Do the write to A

                if instruction_operand_a(5) = '0' then
                    -- Not a literal, so a short operand
                    if instruction_operand_a(4 downto 3) = SO_CAT_REG_VAL then
                        -- Top bits of short operand are 0: register value
                        registers(to_integer(unsigned(instruction_operand_a(2 downto 0)))) <= operand_a_out;
                    elsif instruction_operand_a(4 downto 3) = SO_CAT_REG_DEREF then
                        -- Low top bit is set: register dereference
                        memory_write <= '1';
                        memory_address <= address_a;
                        memory_data_stored <= operand_a_out;
                    elsif instruction_operand_a(4 downto 3) = SO_CAT_REG_NEXTWORD_DEREF then
                        -- Dereference register plus next word
                        -- Already read next word
                        memory_write <= '1';
                        memory_address <= address_a;
                        memory_data_stored <= operand_a_out;
                    elsif instruction_operand_a(4 downto 3) = SO_CAT_OTHER then
                        case instruction_operand_a is
                            when LO_POP | LO_PEEK | LO_PICK | LO_DEREF =>
                                -- Write memory at address determined previously
                                memory_write <= '1';
                                memory_address <= address_a;
                                memory_data_stored <= operand_a_out;
                            when LO_SP =>
                                stack_pointer <= operand_a_out;
                            when LO_PC =>
                                program_counter <= operand_a_out;
                            when LO_EX =>
                                extended <= operand_a_out;
                            when LO_LITERAL =>
                                -- "Attempting to write a literal value fails silently"
                            when others =>
                                -- TODO: This should never happen
                        end case;
                    end if;
                else
                    -- Inline literal
                    -- "Attempting to write a literal value fails silently"
                end if;

                if write_b = '1' then
                    sequence_state <= STATE_WRITE_B;
                else
                    sequence_state <= STATE_DECODE_INSTRUCTION;
                end if;

            elsif sequence_state = STATE_WRITE_B then
                -- Do the write to B
                -- Assumes write_b actually is 1.
                if instruction_operand_b(4 downto 3) = SO_CAT_REG_VAL then
                    -- Top bits of short operand are 0: register value
                    registers(to_integer(unsigned(instruction_operand_b(2 downto 0)))) <= operand_b_out;
                elsif instruction_operand_b(4 downto 3) = SO_CAT_REG_DEREF then
                    -- Low top bit is set: register dereference
                    memory_write <= '1';
                    memory_address <= address_b;
                    memory_data_stored <= operand_b_out;
                elsif instruction_operand_b(4 downto 3) = SO_CAT_REG_NEXTWORD_DEREF then
                    -- Dereference register plus next word
                    -- Already read next word
                    memory_write <= '1';
                    memory_address <= address_b;
                    memory_data_stored <= operand_b_out;
                elsif instruction_operand_b(4 downto 3) = SO_CAT_OTHER then
                    case instruction_operand_b is
                        when SO_PUSH | SO_PEEK | SO_PICK | SO_DEREF =>
                            -- Write memory at address determined previously
                            memory_write <= '1';
                            memory_address <= address_b;
                            memory_data_stored <= operand_b_out;
                        when SO_SP =>
                            stack_pointer <= operand_b_out;
                        when SO_PC =>
                            program_counter <= operand_b_out;
                        when SO_EX =>
                            extended <= operand_b_out;
                        when SO_LITERAL =>
                            -- "Attempting to write a literal value fails silently"
                        when others =>
                            -- TODO: This should never happen
                    end case;
                end if;
                sequence_state <= STATE_DECODE_INSTRUCTION;
            end if;
        end if;
    end process;



end Behavioral;


