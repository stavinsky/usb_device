add_file pins.cst

add_file modules/top.v
add_file modules/constants.txt

add_file modules/queue.v
add_file modules/usb_setup.v
add_file modules/rpll.v
add_file modules/uart_tx.v
add_file modules/usb_pll.v
add_file modules/buffered_uart_tx.v
add_file modules/power_on_reset.v
add_file modules/buffered_usb.v
add_file usbcorev/usb.v
add_file usbcorev/usb_recv.v
add_file usbcorev/usb_tx.v
add_file usbcorev/usb_utils.v
add_file usbcorev/utils.v

set_device GW1NR-LV9QN88PC6/I5 -device_version C
set_option -top_module  top
run all
