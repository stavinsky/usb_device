set -e
source ~/build/oss-cad-suite/environment 
yosys -D LEDS_NR=6 -p "read_verilog $1; synth_gowin -json blinky.json"
# yosys -D LEDS_NR=8 -p "read_verilog pwm125.v; synth_gowin -json synth_gowin -json blinky.json"
# yosys -D LEDS_NR=8 -p "read_verilog usb_sniff.v; synth_gowin -json synth_gowin -json blinky.json"
DEVICE='GW1NR-LV9QN88PC6/I5'
BOARD='tangnano9k'
# /Users/stavinsky/bin/nextpnr-himbaechel  --json blinky.json \
/Users/stavinsky/bin/nextpnr-himbaechel \
  --json blinky.json \
  --write pnrblinky.json \
  --device GW1NR-LV9QN88PC6/I5 \
  --vopt cst=pins.cst \
  --vopt family=GW1N-9C

gowin_pack -d GW1N-9C -o pack.fs pnrblinky.json
openFPGALoader -b $BOARD pack.fs -f 