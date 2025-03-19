import sequtils, strutils, math, tables

proc getUniqueChunks(inputFile: string): (seq[string], seq[int]) =
  let data = readFile(inputFile)
  var chunkMap = initTable[string, int]()
  var uniqueChunks: seq[string] = @[]
  var indices: seq[int] = @[]
  let chunkSize = 4
  for i in countup(0, data.len - 1, chunkSize):
    let chunk = if i + chunkSize - 1 < data.len: data[i .. i + chunkSize - 1] else: data[i .. ^1] & "\0".repeat(chunkSize - (data.len - i))
    if not chunkMap.hasKey(chunk):
      chunkMap[chunk] = uniqueChunks.len
      uniqueChunks.add(chunk)
    indices.add(chunkMap[chunk])
  return (uniqueChunks, indices)

proc compress(inputFile, compressedFile: string) =
  let data = readFile(inputFile)
  let (uniqueChunks, indices) = getUniqueChunks(inputFile)
  let bitsPerIndex = max(1, ceil(log2(float(uniqueChunks.len))).int)
  var compressed: seq[byte] = @[]
  compressed.add(byte(uniqueChunks.len shr 8))
  compressed.add(byte(uniqueChunks.len))
  compressed.add(byte(bitsPerIndex))
  compressed.add(byte(data.len shr 24))
  compressed.add(byte(data.len shr 16))
  compressed.add(byte(data.len shr 8))
  compressed.add(byte(data.len))
  for chunk in uniqueChunks:
    for c in chunk:
      compressed.add(byte(c))
  var bits: seq[byte] = @[]
  var bitCount = 0
  var currentByte = 0'u8
  for idx in indices:
    var value = uint64(idx)
    var bitsLeft = bitsPerIndex
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
  compressed.add(bits)
  writeFile(compressedFile, compressed)

proc decompress(compressedFile, outputFile: string) =
  let compressed = readFile(compressedFile).toSeq.mapIt(byte(it))
  let uniqueChunksLen = (int(compressed[0]) shl 8) or int(compressed[1])
  let bitsPerIndex = int(compressed[2])
  let originalSize = (int(compressed[3]) shl 24) or (int(compressed[4]) shl 16) or (int(compressed[5]) shl 8) or int(compressed[6])
  var uniqueChunks: seq[string] = @[]
  let chunkSize = 4
  var chunkStart = 7
  for i in 0 ..< uniqueChunksLen:
    uniqueChunks.add(compressed[chunkStart .. chunkStart + chunkSize - 1].mapIt(char(it)).join(""))
    chunkStart += chunkSize
  let headerSize = 7 + uniqueChunksLen * chunkSize
  if headerSize >= compressed.len:
    return
  let compressedData = compressed[headerSize .. ^1]
  var indices: seq[int] = @[]
  var bits: uint64 = 0
  var bitCount = 0
  for b in compressedData:
    bits = (bits shl 8) or uint64(b)
    bitCount += 8
    while bitCount >= bitsPerIndex:
      let mask = (1'u64 shl bitsPerIndex) - 1
      let index = int((bits shr (bitCount - bitsPerIndex)) and mask)
      if index < uniqueChunks.len:
        indices.add(index)
      bitCount -= bitsPerIndex
      bits = bits and ((1'u64 shl bitCount) - 1)
  var decompressed: seq[byte] = @[]
  for idx in indices:
    if decompressed.len < originalSize:
      let chunk = uniqueChunks[idx]
      for c in chunk:
        if decompressed.len < originalSize:
          decompressed.add(byte(c))
  writeFile(outputFile, decompressed)

when isMainModule:
  let inputFile = "input.txt"
  let compressedFile = "compressed.dix"
  let outputFile = "d_input.txt"
  echo "Compressing..."
  compress(inputFile, compressedFile)
  echo "Compressed to ", compressedFile, " (size: ", readFile(compressedFile).len, " bytes)"
  echo "Decompressing..."
  decompress(compressedFile, outputFile)
  echo "File reconstructed as ", outputFile