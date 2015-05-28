# >>> from struct import *
import struct

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
var st = newStruct(format)
discard st.add(5.2'f32).add(6.4'f32).add('A').add(true).add(false)
var out1 =  st.add('a').add(8'i32).add(8589934591).add(10.4'f64).add(32767.int16).pack()
echo out1
echo unpack(format, out1)

assert newStruct("h").add(32767.int16).pack() == "\xff\x7f"

assert newStruct("4s3s").add("Viet").add("Nam").pack() == "VietNam"

assert newStruct("5s6s4s").add("Ho").add("Chi").add("Minh").pack() == "Ho\x00\x00\x00Chi\x00\x00\x00Minh"

assert newStruct("6sxxxxx3s").add("Viet").add("Nam").pack().len == 14



# >>> pack('hhi', 1, 2, 3)
st = newStruct("hhi")
var output =  st.add(1.int16).add(2.int16).add(3.int32).pack()

# alternative way to pack
# output = pack("hhi", newStructShort(1), newStructShort(1), newStructInt(3))

# >>> unpack('hhi', '\x00\x01\x00\x02\x00\x00\x00\x03')
var result = unpack("hhi", output);
echo result[0].getShort
echo result[1].getShort
echo result[2].getInt
