import struct

let val = unpack(">3I", "Hello World ")
echo val
assert $val == "@[1214606444, 1864390511, 1919706144]"