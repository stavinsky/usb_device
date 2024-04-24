add_file top.v
add_file constants.txt
add_file pins.cst
add_file queue.v
add_file rpll.v
add_file uart_tx.v
add_file usb_pll.v
add_file usbcorev/usb.v
add_file usbcorev/usb_recv.v
add_file usbcorev/usb_tx.v
add_file usbcorev/usb_utils.v
add_file usbcorev/utils.v
set_device GW1NR-LV9QN88PC6/I5
set_option -top_module  top
run all
