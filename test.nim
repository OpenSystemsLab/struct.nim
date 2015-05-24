# >>> from struct import *
import struct

# >>> pack('hhi', 1, 2, 3)
var st = newStruct("hhi")
var output =  st.add(1.int16).add(2.int16).add(3.int32).pack()

# alternative way to pack
# output = pack("hhi", newStructShort(1), newStructShort(1), newStructInt(3))

# >>> unpack('hhi', '\x00\x01\x00\x02\x00\x00\x00\x03')
var result = unpack("hhi", output);
echo result[0].getShort
echo result[1].getShort
echo result[2].getInt
