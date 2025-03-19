import sequtils, strutils, math

proc getUniqueCharsAndCount(inputFile: string): (string, seq[(char, int)]) =
  let data = readFile(inputFile)
  var charCount: seq[(char, int)] = @[]
  var uniqueChars = ""
  for c in data:
    var found = false
    for i in 0 ..< charCount.len:
      if charCount[i][0] == c:
        charCount[i] = (c, charCount[i][1] + 1)
        found = true
        break
    if not found:
      charCount.add((c, 1))
      uniqueChars &= c
  return (uniqueChars, charCount)

proc compress(inputFile, compressedFile: string) =
  let data = readFile(inputFile)
  let (uniqueChars, charCount) = getUniqueCharsAndCount(inputFile)
  let bitsPerChar = ceil(log2(float(uniqueChars.len))).int
  var compressed: seq[byte] = @[]
  compressed.add(byte(uniqueChars.len shr 8))
  compressed.add(byte(uniqueChars.len))
  compressed.add(byte(bitsPerChar))
  compressed.add(byte(data.len shr 24))
  compressed.add(byte(data.len shr 16))
  compressed.add(byte(data.len shr 8))
  compressed.add(byte(data.len))
  for c in uniqueChars:
    compressed.add(byte(c))
  var bits: uint64 = 0
  var bitCount = 0
  for c in data:
    let index = uniqueChars.find(c)
    bits = (bits shl bitsPerChar) or uint64(index)
    bitCount += bitsPerChar
    if bitCount >= 8:
      compressed.add(byte(bits shr (bitCount - 8)))
      bits = bits and ((1'u64 shl (bitCount - 8)) - 1)
      bitCount -= 8
  if bitCount > 0:
    compressed.add(byte(bits shl (8 - bitCount)))
  writeFile(compressedFile, compressed)

proc decompress(compressedFile, outputFile: string) =
  let compressed = readFile(compressedFile).toSeq.mapIt(byte(it))
  let uniqueCharsLen = (int(compressed[0]) shl 8) or int(compressed[1])
  let bitsPerChar = int(compressed[2])
  let originalSize = (int(compressed[3]) shl 24) or (int(compressed[4]) shl 16) or (int(compressed[5]) shl 8) or int(compressed[6])
  var uniqueChars = ""
  for i in 7 ..< 7 + uniqueCharsLen:
    uniqueChars &= char(compressed[i])
  let headerSize = 7 + uniqueCharsLen
  if headerSize >= compressed.len:
    return
  let compressedData = compressed[headerSize .. ^1]
  var decompressed: seq[byte] = @[]
  var bits: uint64 = 0
  var bitCount = 0
  for b in compressedData:
    bits = (bits shl 8) or uint64(b)
    bitCount += 8
    while bitCount >= bitsPerChar and decompressed.len < originalSize:
      let mask = (1'u64 shl bitsPerChar) - 1
      let index = int((bits shr (bitCount - bitsPerChar)) and mask)
      decompressed.add(byte(uniqueChars[index]))
      bitCount -= bitsPerChar
      bits = bits and ((1'u64 shl bitCount) - 1)
  writeFile(outputFile, decompressed)

when isMainModule:
  let inputFile = "input.txt"
  let compressedFile = "compressed.dix"
  let outputFile = "dinput.txt"
  echo "Compressing..."
  compress(inputFile, compressedFile)
  echo "Compressed to ", compressedFile, " (size: ", readFile(compressedFile).len, " bytes)"
  echo "Decompressing..."
  decompress(compressedFile, outputFile)
  echo "File reconstructed as ", outputFile