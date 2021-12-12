# Makefile borrowed from https://github.com/cliffordwolf/icestorm/blob/master/examples/icestick/Makefile
#
# The following license is from the icestorm project and specifically applies to this file only:
#
#  Permission to use, copy, modify, and/or distribute this software for any
#  purpose with or without fee is hereby granted, provided that the above
#  copyright notice and this permission notice appear in all copies.
#
#  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
#  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
#  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

PROJ = uart

# icestick
# PIN_DEF = icestick.pcf
# DEVICE = hx1k
# PACKAGE = tq144

# tiny fpga bx
# PIN_DEF = tiny_fpga_bx.pcf
PIN_DEF = yyz_tinyfpga_bx_expansion.pcf
DEVICE = lp8k
PACKAGE = cm81

all: $(PROJ).bin

%.json: %.v
	# yosys -p 'synth_ice40 -top $(PROJ) -json $@' $<
	yosys -p 'synth_ice40 -json $@' $<

%.asc: %.json $(PIN_DEF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PIN_DEF) --asc $@ --ignore-loops

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

%_tb: %_tb.v %.v
	iverilog -o $@ $^

%_tb.vcd: %_tb
	vvp -N $< +vcd=$@

%_syn.v: %.blif
	yosys -p 'read_blif -wideports $^; write_verilog $@'

%_syntb: %_tb.v %_syn.v
	iverilog -o $@ $^ `yosys-config --datdir/ice40/cells_sim.v`

%_syntb.vcd: %_syntb
	vvp -N $< +vcd=$@

tinyprog: $(PROJ).bin
	tinyprog -p $<

sudo-tinyprog: $(PROJ).bin
	@echo 'Executing tinyprog as root!!!'
	sudo tinyprog -p $<

iceprog: $(PROJ).bin
	iceprog $<

sudo-iceprog: $(PROJ).bin
	@echo 'Executing iceprog as root!!!'
	sudo iceprog $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin $(PROJ).json

.SECONDARY:
.PHONY: all sudo-tinyprog tinyprog sudo-iceprog iceprog clean
