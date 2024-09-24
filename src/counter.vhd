library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Counter: a counter that counts up.

entity Counter is
    generic (
        WORD_BITS: integer := 16
    );
    port (
        clk: in std_logic;
        set: in std_logic;
        data_in: in std_logic_vector(WORD_BITS-1 downto 0);
        data_out: out std_logic_vector(WORD_BITS-1 downto 0)
    );
end Counter;

architecture Behavioral of Counter is
    signal counter_storage: unsigned(WORD_BITS-1 downto 0);
begin
    process(clk)
    begin
        if clk'event and clk = '1' then
            if set = '1' then
                counter_storage <= unsigned(data_in);
            else
                counter_storage <= counter_storage + to_unsigned(1, WORD_BITS);
            end if;
        end if;
    end process;
    data_out <= std_logic_vector(counter_storage);
end Behavioral;
    
    
