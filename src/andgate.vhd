library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity andgate is
    Port (
        inputs : in  std_logic_vector (1 downto 0);
        output : out  std_logic
    );
end andgate;

architecture Behavioral of andgate is
begin
    
    output <= inputs(0) and inputs(1);
    
end Behavioral;
