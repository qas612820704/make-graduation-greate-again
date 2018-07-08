sources := $(wildcard src/*.p4)
p4_jsons := $(patsubst src/%.p4, build/%.json,$(sources))

all: run

run: build

build: clean mkdirs $(p4_jsons)

build/%.json: src/%.p4
	p4c-bm2-ss --p4v 16 \
		--p4runtime-file $(basename $@).p4info \
		--p4runtime-format text \
		-o $@ $<

mkdirs:
	mkdir -p build/ pcaps/ logs/

stop:
	sudo mn -c

clean: stop
	rm -rf build/ pcaps/ logs/
