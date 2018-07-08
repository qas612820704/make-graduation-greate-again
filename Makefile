
sources := $(wildcard src/*.p4)
p4_jsons := $(patsubst src/%.p4, build/%.json,$(sources))


build: dirs $(p4_jsons)

build/%.json: src/%.p4
	p4c-bm2-ss --p4v 16 \
		--p4runtime-file $(basename $@).p4info \
		--p4runtime-format text \
		-o $@ $<

dirs:
	mkdir -p build pcaps logs
