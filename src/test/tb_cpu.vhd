library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library dcpu16_lib;

entity tb_cpu is
    generic (runner_cfg : string);
end entity;

architecture tb of tb_cpu is
    -- Define signals to talk to the device under test
    signal dut_clk: std_logic;
    signal dut_rst: std_logic;
    signal dut_hold: std_logic;

    signal dut_memory_write: std_logic;
    signal dut_memory_address: std_logic_vector(15 downto 0);
    signal dut_memory_data_stored: std_logic_vector(15 downto 0);
    signal dut_memory_data_loaded: std_logic_vector(15 downto 0);
begin
    
    -- Define the device under test
    dut: entity dcpu16_lib.CPU
    port map (
        clk => dut_clk,
        rst => dut_rst,
        hold => dut_hold,
        memory_write => dut_memory_write,
        memory_address => dut_memory_address,
        memory_data_stored => dut_memory_data_stored,
        memory_data_loaded => dut_memory_data_loaded
    );
    
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        
        -- Loop over all the test cases
        while test_suite loop
            if run("test_load_addr_0") then
                dut_memory_data_loaded <= "0000000000000000";
                dut_hold <= '0';
                dut_clk <= '0';
                dut_rst <= '1';
                wait for 1 ns;
                dut_clk <= '0';
                wait for 1 ns;
                dut_rst <= '0';
                dut_clk <= '1';
                wait for 1 ns;
                check_equal(dut_memory_write, '0', result("Does not write on reset"));
            end if;
        end loop;
        
        test_runner_cleanup(runner); -- Simulation ends here
    end process;
end architecture;
