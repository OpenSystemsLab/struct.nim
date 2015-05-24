import endians
import strutils
import tables

type
  StructError* = object of OSError

  StructKind* = enum ## possible JSON node types
    StructChar,
    StructBool,
    StructShort,
    StructUShort
    StructInt,
    StructUInt,
    StructQuad,
    StructUQuad,
    StructFloat,
    StructDouble,
    StructString

  StructNode* = ref StructNodeObj
  StructNodeObj = object
    case kind*: StructKind
    of StructChar:
      chr: char
    of StructBool:
      bval: bool
    of StructShort:
      sval: int16
    of StructUShort:
      usval: uint16
    of StructInt:
      ival: int32
    of StructUInt:
      uival: uint32
    of StructQuad:
      qval: int64
    of StructUQuad:
      uqval: uint64
    of StructFloat:
      fval: float32
    of StructDouble:
      dval: float64
    of StructString:
      str: string

  Struct* = ref StructObj
  StructObj = object
    fmt: string
    vars: seq[StructNode]

  StructContext = ref object of RootObj
    byteOrder: Endianness
    nativeAlignment: int
    nativeSize: int
    buffer: string
    offset: int
    repeat: int


const
  VERSION* = "0.0.2"

  TYPE_LENGTHS = {
    'x': sizeof(char),
    'b': sizeof(char),
    'h': sizeof(int16),
    'H': sizeof(uint16),
    'i': sizeof(int32),
    'l': sizeof(int32),
    'I': sizeof(uint32),
    'L': sizeof(uint32),
    'q': sizeof(int64),
    'Q': sizeof(uint64),
    'f': sizeof(float32),
    'd': sizeof(float64),
    's': sizeof(char),
    '?': sizeof(bool)
  }.toTable

proc newStructChar*(c: char): StructNode =
  new(result)
  result.kind = StructChar
  result.chr  = c

proc newStructBool*(b: bool): StructNode =
  new(result)
  result.kind = StructBool
  result.bval  = b

proc newStructShort*(i: int16): StructNode =
  new(result)
  result.kind = StructShort
  result.sval  = i

proc newStructUShort*(i: uint16): StructNode =
  new(result)
  result.kind = StructUShort
  result.usval  = i

proc newStructInt*(i: int32): StructNode =
  new(result)
  result.kind = StructInt
  result.ival  = i

proc newStructUInt*(i: uint32): StructNode =
  new(result)
  result.kind = StructUInt
  result.uival  = i

proc newStructQuad*(i: int64): StructNode =
  new(result)
  result.kind = StructQuad
  result.qval  = i

proc newStructUQuad*(i: uint64): StructNode =
  new(result)
  result.kind = StructUQuad
  result.uqval  = i

proc newStructFloat*(f: float32): StructNode =
  new(result)
  result.kind = StructFloat
  result.fval  = f

proc newStructDouble*(d: float64): StructNode =
  new(result)
  result.kind = StructDouble
  result.dval  = d

proc newStructString*(s: string): StructNode =
  new(result)
  result.kind = StructString
  result.str  = s


proc newStructContext(): StructContext =
  new(result)
  result.byteOrder = system.cpuEndian
  result.nativeSize = 1
  result.nativeAlignment = 1
  result.offset = 0
  result.repeat = 1

proc `$`*( node: StructNode ): string =
  ## Delegate stringification of `TNetstringNode` to its underlying object.
  return case node.kind:
  of StructChar:
    $node.chr
  of StructBool:
    $node.bval
  of StructShort:
    $node.sval
  of StructUShort:
    $node.usval
  of StructInt:
    $node.ival
  of StructUInt:
    $node.uival
  of StructQuad:
    $node.qval
  of StructUQuad:
    $node.uqval
  of StructFloat:
    $node.fval
  of StructDouble:
    $node.dval
  of StructString:
    $node.str

proc getChar*(node: StructNode): char =
  assert node.kind == StructChar
  result = node.chr

proc getBool*(node: StructNode): bool =
  assert node.kind == StructBool
  result = node.bval

proc getShort*(node: StructNode): int16 =
  assert node.kind == StructShort
  result = node.sval

proc getUShort*(node: StructNode): uint16 =
  assert node.kind == StructUShort
  result = node.usval

proc getInt*(node: StructNode): int32 =
  assert node.kind == StructInt
  result = node.ival

proc getUInt*(node: StructNode): uint32 =
  assert node.kind == StructUInt
  result = node.uival

proc getQuad*(node: StructNode): int64 =
  assert node.kind == StructQuad
  result = node.qval

proc getUQuad*(node: StructNode): uint64 =
  assert node.kind == StructUQuad
  result = node.uqval

proc getFloat*(node: StructNode): float32 =
  assert node.kind == StructFloat
  result = node.fval

proc getDouble*(node: StructNode): float64 =
  assert node.kind == StructDouble
  result = node.dval

proc getString*(node: StructNode): string =
  assert node.kind == StructString
  return node.str

proc calcsize(format: string): int =
  var repeat = ""
  for i in 0..format.len-1:
    let f: char = format[i]
    if f in '0'..'9':
      repeat.add($f)
    else:
      if repeat == "":
        result += TYPE_LENGTHS[f]
      else:
        result += parseInt(repeat) * TYPE_LENGTHS[f]
      repeat = ""

proc parse_prefix(ctx: StructContext, f: char)  =
  case f
  of '=':
    ctx.byteOrder = system.cpuEndian
    ctx.nativeSize = 0
    ctx.nativeAlignment = 0
  of '<':
    ctx.byteOrder = littleEndian
    ctx.nativeSize = 0
    ctx.nativeAlignment = 0
  of '>', '!':
    ctx.byteOrder = bigEndian
    ctx.nativeSize = 0
    ctx.nativeAlignment = 0
  else:
    ctx.byteOrder = system.cpuEndian
    ctx.nativeSize = 1
    ctx.nativeAlignment = 1

proc load_16*[T:byte|char|int8|uint8](a, b: T, endian: Endianness): int16 {.inline.} =
  if endian == littleEndian:
    a.int16 + b.int16 shl 8
  else:
    b.int16 + a.int16 shl 8

proc load_32*[T:byte|char|int8|uint8](a, b, c, d: T, endian: Endianness): int32 {.inline.} =
  if endian == littleEndian:
    a.int32 + b.int32 shl 8 + c.int32 shl 16 + d.int32 shl 24
  else:
    d.int32 + c.int32 shl 8 + b.int32 shl 16 + a.int32 shl 24

proc load_32f*[T:byte|char|int8|uint8](a, b, c, d: T, endian: Endianness): float32 {.inline.} =
    var o = cast[cstring](addr result)
    if endian == littleEndian:
      o[0] = a
      o[1] = b
      o[2] = c
      o[3] = d
    else:
      o[3] = a
      o[2] = b
      o[1] = c
      o[0] = d

proc load_64*(s: string, endian: Endianness): int64 {.inline.} =
  for i in 0..sizeof(int64)-1:
    result  = result shl 8
    if endian == littleEndian:
      result = result or s[8 - i - 1].int64
    else:
      result = result or s[i].int64;

proc load_64f*(s: string, endian: Endianness): float64 {.inline.} =
  var o = cast[cstring](addr result)
  for i in 0..sizeof(float64)-1:
    if endian == littleEndian:
      o[i] = s[i]
    else:
      o[i] = s[8 - i - 1]

proc extract_16*[T:int16|uint16](v: T, endian: Endianness): string {.inline.} =
  result = ""
  var v = v
  var o = cast[cstring](addr v)

  if endian == littleEndian:
    result &= $o[0] & $o[1]
  else:
    result &= $o[1] & $o[0]

proc extract_32*[T:float32|int32|uint32](v: T, endian: Endianness): string {.inline.} =
  result = ""
  var v = v
  var o = cast[cstring](addr v)
  for i in 0..3:
    if endian == littleEndian:
      result &= $o[i]
    else:
      result &= $o[3 - i]

proc extract_64*[T:float64|int64|uint64](v: T, endian: Endianness): string {.inline.} =
  result = ""
  var v = v
  var o = cast[cstring](addr v)
  for i in 0..7:
    if endian == littleEndian:
      result &= $o[i]
    else:
      result &= $o[7 - i]

proc unpack_char(vars: var seq[StructNode], ctx: StructContext) =
  for i in 0..ctx.repeat-1:
    vars.add(newStructChar(ctx.buffer[ctx.offset]))
    ctx.offset += 1

proc unpack_bool(vars: var seq[StructNode], ctx: StructContext) =
  for i in 0..ctx.repeat-1:
    vars.add(newStructBool(ctx.buffer[ctx.offset].bool))
    ctx.offset += 1

proc unpack_short(vars: var seq[StructNode], ctx: StructContext, f: char, signed: bool = false) =
  for i in 0..ctx.repeat-1:
    var value = load_16(ctx.buffer[ctx.offset], ctx.buffer[ctx.offset+1], ctx.byteOrder)
    if signed:
      vars.add(newStructShort(value))
    else:
      vars.add(newStructUShort(value.uint16))
    ctx.offset += TYPE_LENGTHS[f]

proc unpack_int(vars: var seq[StructNode], ctx: StructContext, f: char, signed: bool = false) =
  for i in 0..ctx.repeat-1:
    var value = load_32(ctx.buffer[ctx.offset], ctx.buffer[ctx.offset+1], ctx.buffer[ctx.offset+2], ctx.buffer[ctx.offset+3], ctx.byteOrder)
    if signed:
      vars.add(newStructInt(value))
    else:
      vars.add(newStructUInt(value.uint32))
    ctx.offset += TYPE_LENGTHS[f]

proc unpack_quad(vars: var seq[StructNode], ctx: StructContext, f: char, signed: bool = false) =
  for i in 0..ctx.repeat-1:
    var value = load_64(ctx.buffer[ctx.offset..ctx.offset+7], ctx.byteOrder)
    if signed:
      vars.add(newStructQuad(value))
    else:
      vars.add(newStructUQuad(value.uint64))
    ctx.offset += TYPE_LENGTHS[f]

proc unpack_float(vars: var seq[StructNode], ctx: StructContext) =
  for i in 0..ctx.repeat-1:
    var value = load_32f(ctx.buffer[ctx.offset], ctx.buffer[ctx.offset+1], ctx.buffer[ctx.offset+2], ctx.buffer[ctx.offset+3], ctx.byteOrder)

    vars.add(newStructFloat(value.float32))
    ctx.offset += TYPE_LENGTHS['f']

proc unpack_double(vars: var seq[StructNode], ctx: StructContext) =
  for i in 0..ctx.repeat-1:
    var value = load_64f(ctx.buffer[ctx.offset..ctx.offset+7], ctx.byteOrder)

    vars.add(newStructDouble(value))
    ctx.offset += TYPE_LENGTHS['f']

proc unpack_string(vars: var seq[StructNode], ctx: StructContext) =
  var value: string
  if ctx.repeat == 1:
    value = $ctx.buffer[ctx.offset]
  else:
    value = ctx.buffer[ctx.offset..ctx.offset+ctx.repeat-1]
  vars.add(newStructString(value))
  ctx.offset += ctx.repeat



proc unpack*(fmt, buf: string): seq[StructNode] =
  result = @[]

  let size = calcsize(fmt)
  if buf.len < size:
    raise newException(ValueError, "unpack requires a string argument of length " & $size)

  var context = newStructContext()
  context.buffer = buf

  var repeat = ""
  for i in 0..fmt.len-1:
    let f: char = fmt[i]

    if f in '0'..'9':
      repeat.add($f)
      continue
    else:
      if repeat == "":
        context.repeat = 1
      else:
        context.repeat = parseInt(repeat)
        repeat = ""

    case f
    of '=', '<', '>', '!', '@':
      context.parse_prefix(f)
    of 'b':
      unpack_char(result, context)
    of '?':
      unpack_bool(result, context)
    of  'h':
      unpack_short(result, context, f)
    of  'H':
      unpack_short(result, context, f, true)
    of  'i':
      unpack_int(result, context, f)
    of  'I':
      unpack_int(result, context, f, true)
    of  'q':
      unpack_quad(result, context, f)
    of  'Q':
      unpack_quad(result, context, f, true)
    of  'f':
      unpack_float(result, context)
    of  'd':
      unpack_double(result, context)
    of 's':
      unpack_string(result, context)
    of 'x':
      context.offset += context.repeat * TYPE_LENGTHS[f]
    else:
      raise newException(ValueError, "bad char in struct format")

proc pack_char(vars: varargs[StructNode], ctx: StructContext): string =
  result = ""
  for i in 0..ctx.repeat-1:
    assert vars[ctx.offset].kind == StructChar
    result &= $vars[ctx.offset].chr
    ctx.offset += 1

proc pack_bool(vars: varargs[StructNode], ctx: StructContext): string =
  result = ""
  for i in 0..ctx.repeat-1:
    assert vars[ctx.offset].kind == StructBool
    if vars[ctx.offset].bval == true:
      result &= "\x01"
    else:
      result &= "\x00"
    ctx.offset += 1

proc pack_16(vars: varargs[StructNode], ctx: StructContext): string =
  result = ""
  for i in 0..ctx.repeat-1:
    case vars[ctx.offset].kind:
    of StructShort:
      result &= extract_16(vars[ctx.offset].sval, ctx.byteOrder)
    of StructUShort:
      result &= extract_16(vars[ctx.offset].usval, ctx.byteOrder)
    else:
      raise newException(ValueError, "not supported")
    ctx.offset += 1


proc pack_32(vars: varargs[StructNode], ctx: StructContext): string =
  result = ""
  for i in 0..ctx.repeat-1:
    case vars[ctx.offset].kind:
    of StructFloat:
      result &= extract_32(vars[ctx.offset].fval, ctx.byteOrder)
    of StructInt:
      result &= extract_32(vars[ctx.offset].ival, ctx.byteOrder)
    of StructUInt:
      result &= extract_32(vars[ctx.offset].uival, ctx.byteOrder)
    else:
      raise newException(ValueError, "not supported")
    ctx.offset += 1

proc pack_64(vars: varargs[StructNode], ctx: StructContext): string =
  result = ""
  for i in 0..ctx.repeat-1:
    case vars[ctx.offset].kind:
    of StructDouble:
      result &= extract_64(vars[ctx.offset].dval, ctx.byteOrder)
    of StructQuad:
      result &= extract_64(vars[ctx.offset].qval, ctx.byteOrder)
    of StructUQuad:
      result &= extract_64(vars[ctx.offset].uqval, ctx.byteOrder)
    else:
      raise newException(ValueError, "not supported")
    ctx.offset += 1

proc pack_string(vars: varargs[StructNode], ctx: StructContext): string =
  result = ""
  assert vars[ctx.offset].kind == StructString
  result &= vars[ctx.offset].str[0..ctx.repeat-1]

  var pad = ctx.repeat - vars[ctx.offset].str.len
  if pad > 0:
    result &= "\x00".repeat(pad)

  ctx.offset += 1

proc pack_pad(ctx: StructContext): string =
  result = ""
  for i in 0..ctx.repeat-1:
    result &= "\x00"

proc pack*(fmt: string, vars: varargs[StructNode]): string =
  result = ""
  var context = newStructContext()

  var repeat = ""
  for i in 0..fmt.len-1:
    let f: char = fmt[i]

    if f in '0'..'9':
      repeat.add($f)
      continue
    else:
      if repeat == "":
        context.repeat = 1
      else:
        context.repeat = parseInt(repeat)
        repeat = ""

    case f
    of '=', '<', '>', '!', '@':
      context.parse_prefix(f)
    of 'b':
      result &= pack_char(vars, context)
    of '?':
      result &= pack_bool(vars, context)
    of  'h', 'H':
      result &= pack_16(vars, context)
    of 'i', 'I', 'f':
      result &= pack_32(vars, context)
    of  'q', 'Q', 'd':
      result &= pack_64(vars, context)
    of 's':
      result &= pack_string(vars, context)
    of 'x':
      result &= pack_pad(context)
    else:
      raise newException(ValueError, "bad char in struct format")


proc newStruct(fmt: string): Struct =
  new(result)
  result.fmt = fmt
  result.vars = @[]

proc add(s: Struct, c: char): Struct =
  result = s
  s.vars.add(newStructChar(c))

proc add(s: Struct, b: bool): Struct =
  result = s
  s.vars.add(newStructBool(b))

proc add(s: Struct, i: int16): Struct =
  result = s
  s.vars.add(newStructShort(i))

proc add(s: Struct, i: uint16): Struct =
  result = s
  s.vars.add(newStructUShort(i))

proc add(s: Struct, i: int32): Struct =
  result = s
  s.vars.add(newStructInt(i))

proc add(s: Struct, i: uint32): Struct =
  result = s
  s.vars.add(newStructUint(i))

proc add(s: Struct, i: int64): Struct =
  result = s
  s.vars.add(newStructQuad(i))

proc add(s: Struct, i: uint64): Struct =
  result = s
  s.vars.add(newStructUQuad(i))

proc add(s: Struct, f: float32): Struct =
  result = s
  s.vars.add(newStructFloat(f))

proc add(s: Struct, d: float64): Struct =
  result = s
  s.vars.add(newStructDouble(d))

proc add(s: Struct, str: string): Struct =
  result = s
  s.vars.add(newStructString(str))

proc pack*(s: Struct): string =
  result = pack(s.fmt, s.vars)


when isMainModule:
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
  assert newStruct("6sxxxxx3s").add("Viet").add("Nam").pack().len == 14
