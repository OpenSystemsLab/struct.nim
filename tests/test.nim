# >>> from struct import *
import struct, strutils

let buf ="\x41\x42\x43\x44\x45\x01\x00\x07\x08\x01\x02\x03\x04\x0D\x00\x00\x00"
let result1 = unpack("<5b2?h2i", buf)
assert result1.len == 10
assert result1[5].getBool == true
assert result1[6].getBool == false
echo result1
let result2 =  unpack(">5b2?hQ", buf)
assert result2.len == 9
echo result2
echo unpack("<5b2?hQ", buf)

let buf2 = "\x40\xA6\x66\x66\xCD\xCC\xCC\xCC\xCC\xCC\x14\x40"
let result3 = unpack(">fd", buf2)
assert result3.len == 2
echo result3
let buf3 = "Viet Nam"
let result4 = unpack("4sx3s", buf3)
assert result4.len == 2
assert result4[0].getString == "Viet"
assert result4[1].getString == "Nam"
echo result4

#echo pack("<fi?c", newStructFloat(5.2), newStructInt(8), newStructBool(true), newStructChar('a'))
var format = "<ffb2?biQdH"
var out1 = pack(format, 5.2, 6.4, 'A', true, false, 'a', 8, 8589934591, 10.4, 32767)
echo unpack(format, out1)

out1 = pack("h", 32767)
assert out1 == "\xff\x7f"
out1 = pack("4s3s", "Viet", "Nam")
assert out1 == "VietNam"
out1 = pack("5s6s4s", "Ho", "Chi", "Minh")
assert out1 == "Ho\x00\x00\x00Chi\x00\x00\x00Minh"
out1 = pack("6sxxxxx3s", "Viet", "Nam")
assert out1.len == 14


# >>> pack('hhi', 1, 2, 3)
var output =  pack("hhi", 1, 2, 3)

# alternative way to pack
# output = pack("hhi", newStructShort(1), newStructShort(1), newStructInt(3))

# >>> unpack('hhi', '\x00\x01\x00\x02\x00\x00\x00\x03')
var result = unpack("hhi", output);
echo result[0].getShort
echo result[1].getShort
echo result[2].getInt

assert struct.unpack(">H", parseHexStr("FFFF"))[0].getShort == int16(-1)
assert struct.unpack(">H", parseHexStr("FFFF"))[0].getUShort == 65535

assert struct.unpack(">I", parseHexStr("FFFFFFFF"))[0].getInt == int32(-1)
assert struct.unpack(">I", parseHexStr("FFFFFFFF"))[0].getUInt == uint32(4294967295)