import struct

let val = unpack(">3I", "Hello World ")

assert $val == "@[1214606444, 1864390511, 1919706144]"

assert pack(">3I", val) == "Hello World "
assert pack(">3I", val[0], val[1], val[2]) == "Hello World "