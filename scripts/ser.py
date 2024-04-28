import serial
import binascii

ser = serial.Serial("/dev/tty.usbmodem11301", 1000000)
setup_data = True
while True:
    if setup_data:
        s = ser.read(8)
#    h = binascii.hexlify(s)
    print(s.hex(" ", 1), )