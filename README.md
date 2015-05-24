# struct.nim
**Python-like '[struct](http://docs.python.org/2/library/struct.html)' for Nim**

*This library is still under development, use it as yourown risk!*

Format String
======

Byte Order
------
<table>
<tr><td>Character</td><td>Byte order</td></tr>
<tr><td>@</td><td>native</td></tr>
<tr><td>=</td><td>native</td></tr>
<tr><td><</td><td>little-endian</td></tr>
<tr><td>></td><td>big-endian</td></tr>
<tr><td>!</td><td>network (= big-endian)</td></tr>
</table>

**Notes:**
- Unlike Python -byte-order can specified once as first character, with this implementation, you can change byte-order anywhere and anytime you want

Format Characters:
------
<table>
<tr><td>Format</td><td>C Type</td><td>Python Type</td><td>Nim Type</td><td>Size (bytes)</td></tr>
<tr><td>x</td><td>pad byte</td><td>no value</td><td></td><td></td></tr>
<tr><td>b</td><td>char</td><td>string of length 1</td><td>char</td><td>1</td></tr>
<tr><td>?</td><td>_Bool</td><td>bool</td><td>bool</td><td>1</td></tr>
<tr><td>h</td><td>short</td><td>integer</td>integer<td>int16</td><td>2</td></tr>
<tr><td>H</td><td>usigned short</td><td>integer</td>integer<td>uint16</td><td>2</td></tr>
<tr><td>i</td><td>int</td><td>integer</td>integer<td>int32</td><td>4</td></tr>
<tr><td>I</td><td>unsigned int</td><td>integer</td>integer<td>uint32</td><td>4</td></tr>
<tr><td>q</td><td>long long</td><td>integer</td><td>int64</td><td>8</td></tr>
<tr><td>Q</td><td>unsigned long long</td><td>integer</td><td>uint64</td><td>8</td></tr>
<tr><td>f</td><td>float</td><td>float</td><td>float32</td><td>4</td></tr>
<tr><td>d</td><td>double</td><td>float</td><td>float64</td><td>8</td></tr>
<tr><td>s</td><td>char[]</td><td>string</td><td>string</td><td></td></tr>
</table>

**Notes:**
- Format character can has a number prefix, you can use "*3?*" instead of "*???*" for pack/unpack three bool value
- For string , number prefix is the length of value

Usage
======

````
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
````
