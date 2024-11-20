.PHONY: test-setup test build run

# To run a single test, do something like:
# make test tests=dcpu16_test_lib.tb_cpu.test_load_addr_0
# Or to run a whole set of tests:
# make test tests=dcpu16_test_lib.tb_cpu.*
# By default we run all tests
tests=

test-setup:
	pip install --user -r requirements.txt

test:
	./run.py $(tests)

build: main.bit
	
main.bit: main.vhd src/*.vhd
	./build.sh
	
run: build
	openocd -f board/digilent_anvyl.cfg -c "init; virtex2 refresh xc6s.pld; pld load xc6s.pld main.bit ; exit"


