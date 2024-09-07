import serial
import sys
import re
import time

tty = "/dev/ttyUSB0"

with serial.Serial(tty, baudrate=9600, bytesize=8, stopbits=1, timeout=1) as port:
    port.write_timeout = 1
    time.sleep(1)

    if len(sys.argv) == 3 and sys.argv[1] in ["on", "off"] and 1 <= int(sys.argv[2]) <= 6:
        print(f"Turning {sys.argv[1]} outlet number {sys.argv[2]}")
        port.write(f"{sys.argv[1]} {sys.argv[2]}\r\n".encode('utf-8'))
        time.sleep(1)
        port.write("y\r\n".encode('utf-8'))

    elif len(sys.argv) == 3 and sys.argv[1] == "read" and 1 <= int(sys.argv[2]) <= 6:
        map = {}
        for line in port.readlines():
            match = re.match(r"([1-6])\)\.{3}(\w+)\s*: (On|Off)", line.decode("utf-8"))
            if match:
                map[match.group(1)] = {"device": match.group(2), "state": match.group(3)}
        print(map[sys.argv[2]]["state"])

    else:
        print("Invalid syntax. Ex: rpcoutlets (on|off|read) (1...6)")