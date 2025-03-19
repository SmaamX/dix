import sequtils, strutils, math, tables

proc compressLZW(inputFile, compressedFile: string) =
  let data = readFile(inputFile)
  var dictionary = initTable[string, int]()
  for i in 0 .. 255:
    dictionary[$char(i)] = i
  var current = ""
  var compressed: seq[int] = @[]
  var nextCode = 256
  for c in data:
    let combined = current & c
    if dictionary.hasKey(combined):
      current = combined
    else:
      compressed.add(dictionary[current])
      dictionary[combined] = nextCode
      nextCode += 1
      current = $c
  if current.len > 0:
    compressed.add(dictionary[current])
  let bitsPerCode = max(9, ceil(log2(float(nextCode))).int)
  let seed = 12345'u32
  var output: seq[byte] = @[]
  output.add(byte(data.len shr 24))
  output.add(byte(data.len shr 16))
  output.add(byte(data.len shr 8))
  output.add(byte(data.len))
  output.add(byte(seed shr 24))
  output.add(byte(seed shr 16))
  output.add(byte(seed shr 8))
  output.add(byte(seed))
  output.add(byte(bitsPerCode))
  var bits: seq[byte] = @[]
  var bitCount = 0
  var currentByte = 0'u8
  for code in compressed:
    var value = uint64(code)
    var bitsLeft = bitsPerCode
    while bitsLeft > 0:
      let bitsToWrite = min(8 - bitCount, bitsLeft)
      let shift = bitsLeft - bitsToWrite
      currentByte = currentByte or uint8((value shr shift) and ((1'u64 shl bitsToWrite) - 1)) shl (8 - bitCount - bitsToWrite)
      bitCount += bitsToWrite
      bitsLeft -= bitsToWrite
      if bitCount >= 8:
        bits.add(currentByte)
        currentByte = 0'u8
        bitCount = 0
      value = value and ((1'u64 shl shift) - 1)
  if bitCount > 0:
    bits.add(currentByte)
  output.add(bits)
  writeFile(compressedFile, output)

proc decompressLZW(compressedFile, outputFile: string) =
  let compressed = readFile(compressedFile).toSeq.mapIt(byte(it))
  let originalSize = (int(compressed[0]) shl 24) or (int(compressed[1]) shl 16) or (int(compressed[2]) shl 8) or int(compressed[3])
  discard (uint32(compressed[4]) shl 24) or (uint32(compressed[5]) shl 16) or (uint32(compressed[6]) shl 8) or uint32(compressed[7])  # seed
  let bitsPerCode = int(compressed[8])
  let compressedData = compressed[9 .. ^1]
  var dictionary = initTable[int, string]()
  for i in 0 .. 255:
    dictionary[i] = $char(i)
  var nextCode = 256
  var codes: seq[int] = @[]
  var bits: uint64 = 0
  var bitCount = 0
  for b in compressedData:
    bits = (bits shl 8) or uint64(b)
    bitCount += 8
    while bitCount >= bitsPerCode:
      let mask = (1'u64 shl bitsPerCode) - 1
      let code = int((bits shr (bitCount - bitsPerCode)) and mask)
      codes.add(code)
      bitCount -= bitsPerCode
      bits = bits and ((1'u64 shl bitCount) - 1)
  var decompressed = ""
  var current = dictionary[codes[0]]
  decompressed &= current
  for i in 1 ..< codes.len:
    let code = codes[i]
    var entry = ""
    if dictionary.hasKey(code):
      entry = dictionary[code]
    elif code == nextCode:
      entry = current & current[0]
    else:
      break
    decompressed &= entry
    dictionary[nextCode] = current & entry[0]
    nextCode += 1
    current = entry
    if decompressed.len >= originalSize:
      break
  writeFile(outputFile, decompressed[0 ..< originalSize])

when isMainModule:
  let inputFile = "input.txt"
  let compressedFile = "compressed.dix"
  let outputFile = "dinput.txt"
  echo "Compressing..."
  compressLZW(inputFile, compressedFile)
  echo "Compressed to ", compressedFile, " (size: ", readFile(compressedFile).len, " bytes)"
  echo "Decompressing..."
  decompressLZW(compressedFile, outputFile)
  echo "File reconstructed as ", outputFile
