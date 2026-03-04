import 'dart:convert';
import 'dart:typed_data';

/// Sequential binary reader with pointer tracking
class BufferReader {
  int _pointer = 0;
  final Uint8List _buffer;

  BufferReader(Uint8List data) : _buffer = Uint8List.fromList(data);

  int get remaining => _buffer.length - _pointer;
  int get position => _pointer;

  int readByte() => readBytes(1)[0];

  Uint8List readBytes(int count) {
    if (_pointer + count > _buffer.length) {
      throw RangeError(
        'Read $count bytes at offset $_pointer, but only $remaining remaining (buffer: ${_buffer.length})',
      );
    }
    final data = _buffer.sublist(_pointer, _pointer + count);
    _pointer += count;
    return data;
  }

  void skipBytes(int count) {
    if (_pointer + count > _buffer.length) {
      throw RangeError('Skip $count bytes at offset $_pointer, but only $remaining remaining');
    }
    _pointer += count;
  }

  Uint8List readRemainingBytes() => readBytes(remaining);
  String readString() => utf8.decode(readRemainingBytes(), allowMalformed: true);

  String readCString(int maxLength) {
    final bytes = readBytes(maxLength);
    final value = <int>[];
    for (final byte in bytes) {
      if (byte == 0) break;
      value.add(byte);
    }
    try {
      return utf8.decode(Uint8List.fromList(value), allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(value);
    }
  }

  int readUInt8() => readByte();
  int readInt8() => readBytes(1).buffer.asByteData().getInt8(0);
  int readUInt16LE() => readBytes(2).buffer.asByteData().getUint16(0, Endian.little);
  int readUInt32LE() => readBytes(4).buffer.asByteData().getUint32(0, Endian.little);
  int readInt32LE() => readBytes(4).buffer.asByteData().getInt32(0, Endian.little);
  int readInt16LE() => readBytes(2).buffer.asByteData().getInt16(0, Endian.little);
}

/// Accumulating binary data builder
class BufferWriter {
  final BytesBuilder _builder = BytesBuilder();

  Uint8List toBytes() => _builder.toBytes();
  int get length => _builder.length;

  void writeByte(int byte) => _builder.addByte(byte);
  void writeBytes(Uint8List bytes) => _builder.add(bytes);

  void writeUInt16LE(int num) {
    final bytes = Uint8List(2)..buffer.asByteData().setUint16(0, num, Endian.little);
    writeBytes(bytes);
  }

  void writeUInt32LE(int num) {
    final bytes = Uint8List(4)..buffer.asByteData().setUint32(0, num, Endian.little);
    writeBytes(bytes);
  }

  void writeInt32LE(int num) {
    final bytes = Uint8List(4)..buffer.asByteData().setInt32(0, num, Endian.little);
    writeBytes(bytes);
  }

  void writeString(String string) => writeBytes(Uint8List.fromList(utf8.encode(string)));

  void writeCString(String string, int maxLength) {
    final bytes = Uint8List(maxLength);
    final encoded = utf8.encode(string);
    for (var i = 0; i < maxLength - 1 && i < encoded.length; i++) {
      bytes[i] = encoded[i];
    }
    writeBytes(bytes);
  }

  void writeHex(String hex) {
    if (hex.isEmpty || hex.length % 2 != 0) {
      throw FormatException('Invalid hex string: ${hex.length} chars');
    }
    final result = <int>[];
    for (int i = 0; i < hex.length ~/ 2; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) throw FormatException('Invalid hex at position $i');
      result.add(byte);
    }
    writeBytes(Uint8List.fromList(result));
  }
}
