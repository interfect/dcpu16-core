library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library dcpu16_lib;

-- Main entry point for dev board

entity main is
    port (
        clk : in  std_logic;
        swt : in  std_logic_vector (7 downto 0);
        btn : in  std_logic_vector (3 downto 0);
        led : inout  std_logic_vector (7 downto 0)
    );
end main;

architecture Behavioral of main is
begin
    gate: entity dcpu16_lib.andgate
    port map (
        inputs(0) => swt(0),
        inputs(1) => swt(1),
        output => led(0)
    );
    
    mem: entity dcpu16_lib.Memory
    generic map (
        WORD_BITS => 4,
        ADDRESS_BITS => 4
    )
    port map (
        clk => clk,
        write => btn(0),
        data_in(3 downto 0) => swt(3 downto 0),
        address(3 downto 0) => swt(7 downto 4),
        data_out(3 downto 0) => led(7 downto 4)
    );
    
end Behavioral;
