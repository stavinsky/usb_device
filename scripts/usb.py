import usb.core
import usb.util
import time

# find our device
dev = usb.core.find(idVendor=0x0605, idProduct=0x0807)

# was it found?
if dev is None:
    raise ValueError('Device not found')

# set the active configuration. With no arguments, the first
# configuration will be the active one
# dev.set_configuration()
# cfg = dev.get_active_configuration()
# intf = cfg[(0,0)]

# dev.ctrl_transfer(0b11000010, 0x30, wValue=0b11011, wIndex=0, data_or_wLength=0, timeout=None)

for i in range(10):
    data = map(lambda x: str(i*10 + x), range(10))
    data = " ".join(data) + " "
    dev.write(0x2, data);
dev.write(0x2, "\n"*10)


# dev.ctrl_transfer(0b01000000, 0x30, wValue=0b11011, wIndex=0, data_or_wLength=0, timeout=None)
# res = dev.ctrl_transfer(0b11000000, 0x31, wValue=0b11011, wIndex=0, data_or_wLength=0x1a, timeout=None)
# res = dev.ctrl_transfer(0b01000000, 0x31, wValue=0b11011, wIndex=0, data_or_wLength=[0,1,2,3], timeout=None)
# print(res)
res = dev.ctrl_transfer(0b11000000, 0x31, wValue=0b11011, wIndex=0, data_or_wLength=4, timeout=None)
print(res)