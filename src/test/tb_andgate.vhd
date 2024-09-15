library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library dcpu16_lib;

entity tb_andgate is
    generic (runner_cfg : string);
end entity;

architecture tb of tb_andgate is
    -- Define signals to talk to the device under test
    signal dut_inputs: std_logic_vector(1 downto 0);
    signal dut_output: std_logic;
begin
    
    -- Define the device under test
    dut: entity dcpu16_lib.andgate
        port map (
            inputs => dut_inputs,
            output => dut_output
        );
    
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        
        -- Loop over all the test cases
        while test_suite loop
            if run("test_00") then
                dut_inputs(0) <= '0';
                dut_inputs(1) <= '0';
                wait for 1 ns;
                check_equal(dut_output, '0', result("Two 0s produces 1"));
            elsif run("test_01") then
                dut_inputs(0) <= '0';
                dut_inputs(1) <= '1';
                wait for 1 ns;
                check_equal(dut_output, '0', result("A 0 and a 1 produces 1"));
            elsif run("test_11") then
                dut_inputs(0) <= '1';
                dut_inputs(1) <= '1';
                wait for 1 ns;
                check_equal(dut_output, '1', result("Two 1s produces 1"));
            end if;
        end loop;
        
        test_runner_cleanup(runner); -- Simulation ends here
    end process;
end architecture;
