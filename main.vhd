library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library dcpu16_lib;

-- Main entry point for dev board

entity main is
    Port ( clk : in  std_logic;
           swt : in  std_logic_vector (7 downto 0);
           led : inout  std_logic_vector (7 downto 0));
end main;

architecture Behavioral of main is
begin
    
    gate: entity dcpu16_lib.andgate
        port map (
            inputs(0) => swt(0),
            inputs(1) => swt(1),
            output => led(0)
        ); 
    
end Behavioral;
