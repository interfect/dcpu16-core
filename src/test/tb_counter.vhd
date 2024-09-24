library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library dcpu16_lib;

entity tb_counter is
    generic (runner_cfg : string);
end entity;

architecture tb of tb_counter is
    -- Define signals to talk to the device under test
    signal dut_clk: std_logic;
    signal dut_set: std_logic;
    signal dut_data_in: std_logic_vector(3 downto 0);
    signal dut_data_out: std_logic_vector(3 downto 0);
begin
    
    -- Define the device under test
    dut: entity dcpu16_lib.counter
    generic map (
        WORD_BITS => 4
    )
    port map (
        clk => dut_clk,
        set => dut_set,
        data_in => dut_data_in,
        data_out => dut_data_out
    );
    
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        
        -- Loop over all the test cases
        while test_suite loop
            if run("test_set_0") then
                dut_clk <= '0';
                wait for 1 ns;
                dut_data_in <= "0000"; 
                dut_set <= '1';
                dut_clk <= '1';
                wait for 1 ns;
                check_equal(unsigned(dut_data_out), 0, result("Counter can be set to 0"));
            elsif run("test_rollover") then
                dut_clk <= '0';
                wait for 1 ns;
                dut_data_in <= "1111"; 
                dut_set <= '1';
                dut_clk <= '1';
                wait for 1 ns;
                dut_set <= '0';
                dut_clk <= '0';
                wait for 1 ns;
                dut_clk <= '1';
                wait for 1 ns;
                check_equal(unsigned(dut_data_out), 0, result("Counter can roll over"));
            elsif run("test_increment") then
                dut_clk <= '0';
                wait for 1 ns;
                dut_data_in <= std_logic_vector(to_unsigned(9, 4));
                dut_set <= '1';
                dut_clk <= '1';
                wait for 1 ns;
                dut_set <= '0';
                dut_clk <= '0';
                wait for 1 ns;
                dut_clk <= '1';
                wait for 1 ns;
                check_equal(unsigned(dut_data_out), 10, result("Counter can count up"));
            end if;
        end loop;
        
        test_runner_cleanup(runner); -- Simulation ends here
    end process;
end architecture;
