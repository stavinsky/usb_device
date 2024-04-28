from dataclasses import dataclass
from ctypes import c_byte, c_ushort
import binascii
import struct 

@dataclass
class Device: 
    bLength : c_byte
    bDescriptorType : c_byte
    bcdUSB : c_ushort
    bDeviceClass : c_byte
    bDeviceSubClass : c_byte
    bDeviceProtocol : c_byte
    bMaxPacketSize : c_byte
    idVendor : c_ushort
    idProduct : c_ushort
    bcdDevice : c_ushort
    iManufacturer: c_byte
    iProduct : c_byte
    iSerialNumber : c_byte
    bNumConfigurations : c_byte

    def pack(self):
        out = struct.pack(
            "BBHBBBBHHHBBBB", 
            self.bLength, 
            self.bDescriptorType,
            self.bcdUSB,
            self.bDeviceClass,
            self.bDeviceSubClass,
            self.bDeviceProtocol,
            self.bMaxPacketSize,
            self.idVendor,
            self.idProduct,
            self.bcdDevice,
            self.iManufacturer,
            self.iProduct,
            self.iSerialNumber,
            self.bNumConfigurations,
        )
        return (out)

device = Device(
    bLength=18,
    bDescriptorType=1,
    bcdUSB=0x0200,
    bDeviceClass=0xff,
    bDeviceSubClass=0xff,
    bDeviceProtocol=0xff,
    bMaxPacketSize=0x40,
    idVendor=0x0605,
    idProduct=0x0807,
    bcdDevice=0x0102,
    iManufacturer=0xAA,
    iProduct=0xAB,
    iSerialNumber=0xAC,
    bNumConfigurations=0x1,
)

print(device.pack())
