import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class AudioProcessor {
  static const int segundosAntes = 30;
  static const int segundosDepois = 30;
  static const double volumeFundoDuranteVoz = 0.35;

  static Future<String?> mixAudio({
    required String voicePath,
    required String backgroundAssetPath,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();

      final bgBytes = await rootBundle.load(backgroundAssetPath);
      final bgFile = File('${tempDir.path}/bg_temp.mp3');
      await bgFile.writeAsBytes(bgBytes.buffer.asUint8List());

      final info = await FFprobeKit.getMediaInformation(voicePath);
      final mediaInfo = info.getMediaInformation();
      if (mediaInfo == null) {
        print('AudioProcessor: nao consegui ler informacoes do audio de voz');
        return null;
      }
      final durationStr = mediaInfo.getDuration();
      final voiceDuration = double.tryParse(durationStr ?? '0') ?? 0;

      if (voiceDuration <= 0) {
        print('AudioProcessor: duracao invalida ($durationStr)');
        return null;
      }

      final totalDuration = segundosAntes + voiceDuration + segundosDepois;
      final outputPath =
          '${tempDir.path}/audio_final_${DateTime.now().millisecondsSinceEpoch}.mp3';

      final command = '-y '
          '-stream_loop -1 -i "${bgFile.path}" '
          '-i "$voicePath" '
          '-filter_complex '
          '"[0:a]atrim=0:$totalDuration,asetpts=PTS-STARTPTS,volume=$volumeFundoDuranteVoz[bg];'
          '[1:a]adelay=${segundosAntes * 1000}|${segundosAntes * 1000}[voz];'
          '[bg][voz]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[out]" '
          '-map "[out]" -c:a libmp3lame -q:a 2 "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      } else {
        final logs = await session.getAllLogsAsString();
        print('AudioProcessor: erro no ffmpeg -> $logs');
        return null;
      }
    } catch (e) {
      print('AudioProcessor: excecao -> $e');
      return null;
    }
  }
}
