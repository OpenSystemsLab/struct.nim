#
#          Nim's Unofficial Library
#        (c) Copyright 2015 Huy Doan
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

## This module implements Python struct for Nim

import strutils, endians, macros

type
  SomeByte* = byte|char|int8|uint8
  StructError* = object of OSError

  StructKind* = enum
    StructChar,
    StructBool,
    StructInt,
    StructFloat,
    StructString

  StructNode* = object
    case kind*: StructKind
    of StructChar:
      ch: char
    of StructBool:
      bval: bool
    of StructInt:
      num: BiggestInt
    of StructFloat:
      fval: BiggestFloat
    of StructString:
      str: string

  Struct* = object
    fmt: string
    vars: seq[StructNode]

  StructContext = object
    byteOrder: Endianness
    buffer: string
    offset: int
    repeat: int
    index: int

const
  STRUCT_VERSION* = "0.2.2"

proc getSize(t: char): int {.noSideEffect, inline.} =
  case t
  of 'x', 'b', 's', '?': 1
  of 'h', 'H': 2
  of 'i', 'I', 'f': 4
  of 'q', 'Q', 'd': 8
  else: 0

proc newStructChar*(c: char): StructNode = StructNode(kind: StructChar, ch: c)

proc newStructBool*(b: bool): StructNode = StructNode(kind: StructBool, bval: b)

proc newStructInt*[T: SomeInteger](i: T): StructNode = StructNode(kind: StructInt, num: i.BiggestInt)

proc newStructFloat*(d: BiggestFloat): StructNode = StructNode(kind: StructFloat, fval: d)

proc newStructString*(s: string): StructNode = StructNode(kind: StructString, str: s)

proc newStructContext(): StructContext =
  result.byteOrder = system.cpuEndian
  result.offset = 0
  result.repeat = 1
  result.index = 0

proc `$`*( node: StructNode ): string =
  return case node.kind:
  of StructChar:
    $node.ch
  of StructBool:
    $node.bval
  of StructInt:
    $node.num
  of StructFloat:
    $node.fval
  of StructString:
    $node.str

proc getChar*(node: StructNode): char {.noSideEffect, inline.} =
  node.ch

proc getBool*(node: StructNode): bool {.noSideEffect, inline.} =
  node.bval

proc getShort*(node: StructNode): int16 {.noSideEffect, inline.} =
  node.num.int16

proc getUShort*(node: StructNode): uint16 {.noSideEffect, inline.} =
  node.num.uint.uint16

proc getInt*(node: StructNode): int32 {.noSideEffect, inline.} =
  node.num.int32

proc getUInt*(node: StructNode): uint32 {.noSideEffect, inline.} =
  node.num.uint.uint32

proc getQuad*(node: StructNode): int64 {.noSideEffect, inline.} =
  node.num.int64

proc getUQuad*(node: StructNode): uint64 {.noSideEffect, inline.} =
  node.num.uint.uint64

proc getFloat*(node: StructNode): float32 {.noSideEffect, inline.} =
  node.fval.float32

proc getDouble*(node: StructNode): float64 {.noSideEffect, inline.} =
  node.fval.float64

proc getString*(node: StructNode): string {.noSideEffect, inline.} =
  node.str

proc computeLength*(format: string): int =
  ## Compute the length for string represent `format`
  var repeat = newString(0)
  for i in 0..<format.len:
    let f = format[i]
    if f in '0'..'9':
      repeat.add($f)
    else:
      if repeat == "":
        inc(result, getSize(f))
      else:
        inc(result, parseInt(repeat) * getSize(f))
      repeat = newString(0)

proc parse_prefix(ctx: var StructContext, f: char)  =
  case f
  of '=':
    ctx.byteOrder = system.cpuEndian
  of '<':
    ctx.byteOrder = littleEndian
  of '>', '!':
    ctx.byteOrder = bigEndian
  else:
    ctx.byteOrder = system.cpuEndian

proc load_16*[T: SomeByte](a, b: T, endian: Endianness): int16 {.inline.} =
  if endian == littleEndian:
    a.int16 or b.int16 shl 8
  else:
    b.int16 or a.int16 shl 8

proc load_32*[T: SomeByte](a, b, c, d: T, endian: Endianness): int32 {.inline.} =
  if endian == littleEndian:
    a.int32 or b.int32 shl 8 or c.int32 shl 16 or d.int32 shl 24
  else:
    d.int32 or c.int32 shl 8 or b.int32 shl 16 or a.int32 shl 24

proc load_32f*[T: SomeByte](a, b, c, d: T, endian: Endianness): float32 {.inline.} =
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
  for i in 0..<sizeof(int64):
    result  = result shl 8
    if endian == littleEndian:
      result = result or s[8 - i - 1].int64
    else:
      result = result or s[i].int64;

proc load_64f*(s: string, endian: Endianness): float64 {.inline.} =
  var o = cast[cstring](addr result)
  for i in 0..<sizeof(float64):
    if endian == littleEndian:
      o[i] = s[i]
    else:
      o[i] = s[8 - i - 1]

proc extract_16*[T:int16|uint16](v: T, endian: Endianness): array[0..1, char] {.inline.} =
  var v = v
  if endian == littleEndian:
    littleEndian16(addr result, addr v)
  else:
    bigEndian16(addr result, addr v)

proc extract_32*[T:float32|int32|uint32](v: T, endian: Endianness): array[0..3, char] {.inline.} =
  var v = v
  if endian == littleEndian:
    littleEndian32(addr result, addr v)
  else:
    bigEndian32(addr result, addr v)

proc extract_64*[T:float64|int64|uint64](v: T, endian: Endianness): array[0..7, char] {.inline.} =
  var v = v
  if endian == littleEndian:
    littleEndian64(addr result, addr v)
  else:
    bigEndian64(addr result, addr v)

proc unpack_char(vars: var seq[StructNode], ctx: var StructContext) =
  for i in 0..<ctx.repeat:
    vars.add(newStructChar(ctx.buffer[ctx.offset]))
    inc(ctx.offset)

proc unpack_bool(vars: var seq[StructNode], ctx: var StructContext) =
  for i in 0..<ctx.repeat:
    vars.add(newStructBool(ctx.buffer[ctx.offset].bool))
    inc(ctx.offset)

proc unpack_short(vars: var seq[StructNode], ctx: var StructContext, f: char, signed: bool = false) =
  for i in 0..<ctx.repeat:
    let
      offset = ctx.offset + i * 2
      value = load_16(ctx.buffer[offset], ctx.buffer[offset+1], ctx.byteOrder)
    vars.add(newStructInt(value))
  inc(ctx.offset, ctx.repeat * getSize(f))

proc unpack_int(vars: var seq[StructNode], ctx: var StructContext, f: char, signed: bool = false) =
  for i in 0..<ctx.repeat:
    let
      offset = ctx.offset + i * 4
      value = load_32(ctx.buffer[offset], ctx.buffer[offset+1], ctx.buffer[offset+2], ctx.buffer[offset+3], ctx.byteOrder)
    vars.add(newStructInt(value))
  inc(ctx.offset, ctx.repeat * getSize(f))

proc unpack_quad(vars: var seq[StructNode], ctx: var StructContext, f: char, signed: bool = false) =
  for i in 0..<ctx.repeat:
    let
      offset = ctx.offset + i * 8
      value = load_64(ctx.buffer[offset..offset+7], ctx.byteOrder)
    vars.add(newStructInt(value))
  inc(ctx.offset, ctx.repeat * getSize(f))

proc unpack_float(vars: var seq[StructNode], ctx: var StructContext) =
  for i in 0..<ctx.repeat:
    let
      offset = ctx.offset + i * 4
      value = load_32f(ctx.buffer[offset], ctx.buffer[offset+1], ctx.buffer[offset+2], ctx.buffer[offset+3], ctx.byteOrder)
    vars.add(newStructFloat(value.float32))
  inc(ctx.offset, ctx.repeat * getSize('f'))

proc unpack_double(vars: var seq[StructNode], ctx: var StructContext) =
  for i in 0..<ctx.repeat:
    let
      offset = ctx.offset + i * 8
      value = load_64f(ctx.buffer[offset..offset+7], ctx.byteOrder)
    vars.add(newStructFloat(value))
  inc(ctx.offset, ctx.repeat * getSize('d'))

proc unpack_string(vars: var seq[StructNode], ctx: var StructContext) =
  var value: string
  if ctx.repeat == 1:
    value = $ctx.buffer[ctx.offset]
  else:
    value = ctx.buffer[ctx.offset..ctx.offset+ctx.repeat-1]
  vars.add(newStructString(value))
  inc(ctx.offset, ctx.repeat)


proc unpack*(fmt, buf: string): seq[StructNode] =
  result = @[]

  let length = computeLength(fmt)
  if buf.len < length:
    raise newException(ValueError, "unpack requires a string argument of length " & $length & ", input: " & $buf.len)

  var context = newStructContext()
  context.buffer = buf

  var repeat = newString(0)
  for i in 0..<fmt.len:
    let f: char = fmt[i]
    if f in '0'..'9':
      repeat.add(f)
      continue
    else:
      if repeat == "":
        context.repeat = 1
      else:
        context.repeat = parseInt(repeat)
        repeat = newString(0)

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
      inc(context.offset, context.repeat * getSize(f))
    else:
      raise newException(ValueError, "bad char in struct format")

proc pack_char(result: var string, vars: openarray[StructNode], ctx: var StructContext) =
  for i in 0..<ctx.repeat:
    assert vars[ctx.offset].kind == StructChar
    result[ctx.index + i] = vars[ctx.offset].ch
    inc(ctx.offset)
  inc(ctx.index, ctx.repeat)

proc pack_bool(result: var string, vars: openarray[StructNode], ctx: var StructContext) =
  for i in 0..<ctx.repeat:
    assert vars[ctx.offset].kind == StructBool
    if vars[ctx.offset].bval == true:
      result[ctx.index] = '\x01'
    else:
      result[ctx.index] = '\x00'
    inc(ctx.offset)

  inc(ctx.index, ctx.repeat)

proc pack_16(result: var string, vars: openarray[StructNode], ctx: var StructContext, signed: bool) =
  for i in 0..<ctx.repeat:
    let value =
      if signed:
        extract_16(vars[ctx.offset].num.int16, ctx.byteOrder)
      else:
        extract_16(vars[ctx.offset].num.uint16, ctx.byteOrder)

    result[ctx.index + i] = value[0]
    result[ctx.index + i + 1] = value[1]

    inc(ctx.offset)
  inc(ctx.index, 2 * ctx.repeat)

proc pack_32(result: var string, vars: openarray[StructNode], ctx: var StructContext, signed: bool) =
  for i in 0..<ctx.repeat:
    var value: array[4, char]
    case vars[ctx.offset].kind:
    of StructFloat:
      value = extract_32(vars[ctx.offset].fval.float32, ctx.byteOrder)
    of StructInt:
      if signed:
        value = extract_32(vars[ctx.offset].num.int32, ctx.byteOrder)
      else:
        value = extract_32(vars[ctx.offset].num.uint32, ctx.byteOrder)
    else:
      raise newException(ValueError, "not supported")
    for j in 0..3:
      result[ctx.index + i * 4 + j] = value[j]
    inc(ctx.offset)
  inc(ctx.index, 4 * ctx.repeat)

proc pack_64(result: var string, vars: openarray[StructNode], ctx: var StructContext, signed: bool) =
  for i in 0..<ctx.repeat:
    var value: array[8, char]
    case vars[ctx.offset].kind:
    of StructFloat:
      value = extract_64(vars[ctx.offset].fval, ctx.byteOrder)
    of StructInt:
      if signed:
        value = extract_64(vars[ctx.offset].num.int64, ctx.byteOrder)
      else:
        value= extract_64(vars[ctx.offset].num.uint64, ctx.byteOrder)
    else:
      raise newException(ValueError, "not supported")

    for j in 0..7:
      result[ctx.index + i * 8 + j] = value[j]

    inc(ctx.offset)
  inc(ctx.index, 8 * ctx.repeat)

proc pack_string(result: var string, vars: openarray[StructNode], ctx: var StructContext) =
  assert vars[ctx.offset].kind == StructString

  let value = vars[ctx.offset].str
  for i in 0..<value.len:
    result[ctx.index + i] = value[i]
  if(value.len < ctx.repeat):
    for i in value.len..<ctx.repeat:
      result[ctx.index + i] = '\x00'

  inc(ctx.offset)
  inc(ctx.index, ctx.repeat)

proc pack_pad(result: var string, ctx: var StructContext) =
  for i in 0..<ctx.repeat:
    result[ctx.index + i] = '\x00'
  inc(ctx.index, ctx.repeat)

proc pack*(fmt: string, vars: varargs[StructNode]): string =
  result = newString(computeLength(fmt))
  var context = newStructContext()
  var repeat = newString(0)
  for i in 0..<fmt.len:
    let f = fmt[i]
    if f in '0'..'9':
      repeat.add(f)
      continue
    else:
      if repeat == "":
        context.repeat = 1
      else:
        context.repeat = parseInt(repeat)
        repeat = newString(0)

    case f
    of '=', '<', '>', '!', '@':
      context.parse_prefix(f)
    of 'b':
      pack_char(result, vars, context)
    of '?':
      pack_bool(result, vars, context)
    of 'h':
      pack_16(result, vars, context, true)
    of 'H':
      pack_16(result, vars, context, false)
    of 'i':
      pack_32(result, vars, context, true)
    of 'I', 'f':
      pack_32(result, vars, context, false)
    of  'q':
      pack_64(result, vars, context, true)
    of  'Q', 'd':
      pack_64(result, vars, context, false)
    of 's':
      pack_string(result, vars, context)
    of 'x':
      pack_pad(result, context)
    else:
      raise newException(ValueError, "bad char in struct format")

proc initStruct*(s: var Struct, fmt: string) {.inline.} =
  s.fmt = fmt
  s.vars = @[]

proc add*(s: var Struct, c: char) {.inline.} =
  s.vars.add(newStructChar(c))

proc add*(s: var Struct, b: bool) {.inline.} =
  s.vars.add(newStructBool(b))

proc add*[T: SomeNumber|BiggestInt](s: var Struct, d: T) {.inline.} =
  s.vars.add(newStructInt(d))

proc add*(s: var Struct, d: float) {.inline.} =
  s.vars.add(newStructFloat(d))

proc add*(s: var Struct, str: string) {.inline.} =
  s.vars.add(newStructString(str))

macro pack_m(n: openarray[typed]): untyped =
  result = newNimNode(nnkStmtList, n)
  result.add(newCall("initStruct", ident("s"), n[0]))
  if n.len > 1:
    for i in 1..<n.len:
      result.add(newCall(ident("add"), ident("s"), n[i]))

template `pack`*(n: varargs[typed]): untyped =
  when not declaredInScope(s):
    var s {.inject.}: Struct
  pack_m(n)
  pack(s.fmt, s.vars)


when isMainModule:
  var x = pack("3b", 'a', 'b', 'c')
  echo x
