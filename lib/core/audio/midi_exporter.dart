import 'dart:io';
import 'dart:typed_data';

/// Pure-Dart Standard MIDI File (SMF Type 0) encoder for exporting single
/// chords or full progressions to `.mid` files compatible with Ableton Live
/// and all standard DAWs.
class MidiExporter {
  MidiExporter._();

  static const int defaultTicksPerBeat = 480;
  static const int defaultBpm = 96;
  static const int defaultVelocity = 90;

  /// Encodes a sequence of chords (each chord is a list of MIDI pitches 0..127)
  /// into a valid Standard MIDI File (Format 0, single track).
  /// Each chord occupies 1 bar (4 beats) with a slight 40-tick release gap
  /// before the next bar so DAWs keep consecutive repeated notes cleanly separated.
  static Uint8List encodeMidiBytes({
    required List<List<int>> chordMidiNotes,
    String trackName = 'Spellchord',
    int bpm = defaultBpm,
    int ticksPerBeat = defaultTicksPerBeat,
    int beatsPerChord = 4,
    int velocity = defaultVelocity,
  }) {
    final BytesBuilder track = BytesBuilder(copy: false);

    // 1. Track Name meta-event (FF 03 <len> <ascii>)
    final List<int> nameBytes = trackName.codeUnits
        .map((int c) => c.clamp(32, 126))
        .toList(growable: false);
    _writeVarLen(track, 0);
    track.add(<int>[0xFF, 0x03]);
    _writeVarLen(track, nameBytes.length);
    track.add(nameBytes);

    // 2. Set Tempo meta-event (FF 51 03 <us/quarter>)
    final int safeBpm = bpm.clamp(30, 300);
    final int microsPerQuarter = (60000000 / safeBpm).round();
    _writeVarLen(track, 0);
    track.add(<int>[
      0xFF,
      0x51,
      0x03,
      (microsPerQuarter >> 16) & 0xFF,
      (microsPerQuarter >> 8) & 0xFF,
      microsPerQuarter & 0xFF,
    ]);

    // 3. Time Signature 4/4 meta-event (FF 58 04 04 02 18 08)
    _writeVarLen(track, 0);
    track.add(const <int>[0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08]);

    // 4. Chord note events
    final int barTicks = ticksPerBeat * beatsPerChord;
    final int releaseGap = (ticksPerBeat ~/ 12).clamp(1, barTicks ~/ 4);
    final int holdTicks = barTicks - releaseGap;
    final int safeVel = velocity.clamp(1, 127);

    int pendingDelta = 0;
    for (final List<int> rawNotes in chordMidiNotes) {
      final List<int> uniqueNotes = rawNotes
          .map((int n) => n.clamp(0, 127))
          .toSet()
          .toList()
        ..sort();

      if (uniqueNotes.isEmpty) {
        pendingDelta += barTicks;
        continue;
      }

      // Note On for all chord tones simultaneously
      for (int i = 0; i < uniqueNotes.length; i++) {
        _writeVarLen(track, i == 0 ? pendingDelta : 0);
        track.add(<int>[0x90, uniqueNotes[i], safeVel]);
      }
      pendingDelta = 0;

      // Note Off for all chord tones after holdTicks
      for (int i = 0; i < uniqueNotes.length; i++) {
        _writeVarLen(track, i == 0 ? holdTicks : 0);
        track.add(<int>[0x80, uniqueNotes[i], 0x00]);
      }

      pendingDelta = releaseGap;
    }

    // 5. End of Track meta-event (FF 2F 00)
    _writeVarLen(track, pendingDelta);
    track.add(const <int>[0xFF, 0x2F, 0x00]);

    final Uint8List trackData = track.takeBytes();

    // Build complete SMF file: MThd (14 bytes) + MTrk header (8 bytes) + trackData
    final ByteData header = ByteData(22);
    // 'MThd'
    header.setUint8(0, 0x4D);
    header.setUint8(1, 0x54);
    header.setUint8(2, 0x68);
    header.setUint8(3, 0x64);
    header.setUint32(4, 6, Endian.big); // Header length
    header.setUint16(8, 0, Endian.big); // Format 0
    header.setUint16(10, 1, Endian.big); // 1 track
    header.setUint16(12, ticksPerBeat, Endian.big); // Division

    // 'MTrk'
    header.setUint8(14, 0x4D);
    header.setUint8(15, 0x54);
    header.setUint8(16, 0x72);
    header.setUint8(17, 0x6B);
    header.setUint32(18, trackData.length, Endian.big);

    final Uint8List out = Uint8List(22 + trackData.length);
    out.setRange(0, 22, header.buffer.asUint8List());
    out.setRange(22, out.length, trackData);
    return out;
  }

  /// Writes a temporary `.mid` file ready for drag-and-drop into a DAW.
  static File writeTempMidiFile({
    required List<List<int>> chordMidiNotes,
    required String suggestedName,
    int bpm = defaultBpm,
  }) {
    final String safeName = _sanitizeFileName(suggestedName);
    final Directory dir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}spellchord_midi',
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final File file = File(
      '${dir.path}${Platform.pathSeparator}$safeName.mid',
    );
    final Uint8List bytes = encodeMidiBytes(
      chordMidiNotes: chordMidiNotes,
      trackName: safeName,
      bpm: bpm,
    );
    file.writeAsBytesSync(bytes, flush: true);
    return file;
  }

  static String _sanitizeFileName(String raw) {
    final String cleaned = raw
        .replaceAll('#', 'sharp')
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'Spellchord' : cleaned;
  }

  static void _writeVarLen(BytesBuilder builder, int value) {
    int v = value < 0 ? 0 : value;
    int buffer = v & 0x7F;
    while ((v >>= 7) > 0) {
      buffer <<= 8;
      buffer |= (v & 0x7F) | 0x80;
    }
    while (true) {
      builder.addByte(buffer & 0xFF);
      if ((buffer & 0x80) != 0) {
        buffer >>= 8;
      } else {
        break;
      }
    }
  }
}
