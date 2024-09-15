.PHONY: test-setup test build run

test-setup:
	pip install --user -r requirements.txt

test:
	./run.py

build: main.bit
	
main.bit: main.vhd src/*.vhd
	./build.sh
	
run: build
	openocd -f board/digilent_anvyl.cfg -c "init; virtex2 refresh xc6s.pld; pld load xc6s.pld main.bit ; exit"


