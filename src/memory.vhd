library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Memory: an abstract single-port memory meant to be inferred into block RAM when appropriate.
-- Won't be inferred into block RAM if it is very small, or if it is instantiated as large but optimized to be very small.

entity Memory is
    generic (
        WORD_BITS: integer := 16;
        ADDRESS_BITS: integer := 16
    );
    port (
        clk: in std_logic;
        write: in std_logic;
        address: in std_logic_vector(ADDRESS_BITS - 1 downto 0);
        data_in: in std_logic_vector(WORD_BITS - 1 downto 0);
        data_out: out std_logic_vector(WORD_BITS-1 downto 0)
    );
end Memory;

architecture Behavioral of Memory is
    -- Define a type for the whole memory space
    type MemoryData is array (0 to WORD_BITS ** 2 - 1) of std_logic_vector(WORD_BITS - 1 downto 0);
    signal memory_storage: MemoryData;
begin
    process(clk)
    begin
        if clk'event and clk = '1' then
            if write = '1' then
                memory_storage(to_integer(unsigned(address))) <= data_in;
            end if;
            data_out <= memory_storage(to_integer(unsigned(address)));
        end if;
    end process;
end Behavioral;
    
    
