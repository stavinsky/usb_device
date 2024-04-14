SYNTH_SRCS=top.v usb_pll.v rpll.v usbcorev/usb_tx.v usbcorev/usb_recv.v usbcorev/usb_utils.v usbcorev/utils.v
PINS=pins.cst
DEVICE=GW1NR-LV9QN88PC6/I5
BOARD='tangnano9k'
PNR=/Users/stavinsky/bin/nextpnr-himbaechel
PNR=/Users/stavinsky/build/nextpnr/build/nextpnr-himbaechel


.DEFAULT_GOAL := build/pack.fs

build/build.json: $(SYNTH_SRCS)
	yosys -q -p  'read_verilog  $(SYNTH_SRCS) ; synth_gowin -json $@'

build/pnr_build.json: build/build.json $(PINS)
	$(PNR) \
	    --json build/build.json \
      	--write $@ \
      	--device $(DEVICE) \
      	--vopt cst=$(PINS) \
      	--vopt family=GW1N-9C \
		--freq 48000000 \
		--placer-heap-cell-placement-timeout 8 \
		--threads `nproc` \
	    --randomize-seed


build/pack.fs: build/pnr_build.json
	gowin_pack -d GW1N-9C -o build/pack.fs build/pnr_build.json 


prog: build/pack.fs
	openFPGALoader -b $(BOARD) build/pack.fs  

.PHONY: prog

flash: build/pack.fs
	openFPGALoader -b $(BOARD) build/pack.fs -f 



clean:
	rm -rf build/*