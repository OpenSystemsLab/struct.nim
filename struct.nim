import endians
import macros
import parseutils
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
      chr*: char
    of StructBool:
      bval*: bool
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
      str*: string

  StructContext = ref object of RootObj
    byteOrder: Endianness
    nativeAlignment: int
    nativeSize: int
    buffer: string
    offset: int
    repeat: int


const
  VERSION* = "0.1.0"

  TYPE_LENGTHS = {
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
    's': sizeof(int32),
    '?': sizeof(bool)
  }.toTable

proc newStructChar(c: char): StructNode =
  new(result)
  result.kind = StructChar
  result.chr  = c

proc newStructBool(b: bool): StructNode =
  new(result)
  result.kind = StructBool
  result.bval  = b

proc newStructShort(i: int16): StructNode =
  new(result)
  result.kind = StructShort
  result.sval  = i

proc newStructUShort(i: uint16): StructNode =
  new(result)
  result.kind = StructUShort
  result.usval  = i

proc newStructInt(i: int32): StructNode =
  new(result)
  result.kind = StructInt
  result.ival  = i

proc newStructUInt(i: uint32): StructNode =
  new(result)
  result.kind = StructUInt
  result.uival  = i

proc newStructQuad(i: int64): StructNode =
  new(result)
  result.kind = StructQuad
  result.qval  = i

proc newStructUQuad(i: uint64): StructNode =
  new(result)
  result.kind = StructUQuad
  result.uqval  = i

proc newStructFloat(f: float32): StructNode =
  new(result)
  result.kind = StructFloat
  result.fval  = f

proc newStructDouble(d: float64): StructNode =
  new(result)
  result.kind = StructDouble
  result.dval  = d

proc newStructString(s: string): StructNode =
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

proc calcsize(format: string): int =
  result = 0

  var repeat = ""
  for i in 0..format.len-1:
    let c: char = format[i]
    if c in '0'..'9':
      repeat.add($c)
    else:
      if repeat == "":
        repeat = "1"
      result += repeat.parseInt() * TYPE_LENGTHS[c]
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

proc parse_repeat(ctx: StructContext, repeat: var string) =
  if repeat == "":
    ctx.repeat = 1
  else:
    ctx.repeat = repeat.parseInt()
    repeat = ""

proc load_16*(a, b: char, endian: Endianness): int16 {.inline.} =
  if endian == littleEndian:
    a.int16 + b.int16 shl 8
  else:
    b.int16 + a.int16 shl 8

proc load_32*(a, b, c, d: char, endian: Endianness): int32 {.inline.} =
  if endian == littleEndian:
    a.int32 + b.int32 shl 8 + c.int32 shl 16 + d.int32 shl 24
  else:
    d.int32 + c.int32 shl 8 + b.int32 shl 16 + a.int32 shl 24


proc unpack_byte(vars: var seq[StructNode], ctx: StructContext) =
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


proc unpack*(fmt, buf: string): seq[StructNode] =
  result = @[]

  let size = calcsize(fmt)
  if buf.len < size:
    raise newException(ValueError, "unpack requires a string argument of length " & $size)

  var context = newStructContext()
  context.buffer = buf
  var fmt = fmt

  var repeat = ""
  while fmt.len > 0:
    var f: char = fmt[0]
    case f
    of '=', '<', '>', '!', '@':
      context.parse_prefix(f)
    of 'b':
      context.parse_repeat(repeat)
      unpack_byte(result, context)
    of '?':
      context.parse_repeat(repeat)
      unpack_bool(result, context)
    of  'h':
      context.parse_repeat(repeat)
      unpack_short(result, context, f)
    of  'H':
      context.parse_repeat(repeat)
      unpack_short(result, context, f, true)
    of  'i':
      context.parse_repeat(repeat)
      unpack_int(result, context, f)
    of  'I':
      context.parse_repeat(repeat)
      unpack_int(result, context, f, true)
    of '0'..'9':
      repeat.add($f)
    else:
      raise newException(ValueError, "bad char in struct format")

    fmt.delete(0, 0)


when isMainModule:
  var format = "<5b2?hi"
  let buf ="\x41\x42\x43\x44\x45\x01\x00\x07\x08\x01\x02\x03\x04"
  echo unpack(format, buf)
  format = ">5b2?hi"
  echo unpack(format, buf)
