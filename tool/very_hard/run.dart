import 'dart:io';

import 'package:conquest/game/very_hard_cpu.dart';

import 'benchmark.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help')) {
    stdout.write(_usage);
    return;
  }

  try {
    final options = _parseArguments(arguments);
    final pullRequestNumber = _parsePositiveInt(
      options['--pr-number']!,
      '--pr-number',
    );
    final expectedHead = _parseSha(options['--pr-head']!);
    final previewUrl = _parsePreviewUrl(options['--preview-url']!);
    final localHead = await _readLocalHead();
    if (localHead != expectedHead) {
      throw BenchmarkHeadMismatch(expected: expectedHead, actual: localHead);
    }

    final gateway = HttpVeryHardCpuGateway(
      endpoint: previewUrl.resolve(VeryHardCpuConfig.endpointPath),
    );
    try {
      final report = await VeryHardBenchmarkRunner(gateway: gateway).run(
        pullRequestNumber: pullRequestNumber,
        expectedHead: expectedHead,
        localHead: localHead,
      );
      stdout.write(report.toJapaneseMarkdown());
    } finally {
      gateway.close();
    }
  } on BenchmarkHeadMismatch catch (error) {
    stderr.writeln(
      '停止: ローカルHEADが指定されたPR HEADと一致しません。'
      ' expected=${error.expected} actual=${error.actual}',
    );
    exitCode = 2;
  } on BenchmarkPreflightUnavailable {
    stderr.writeln('停止: PreviewのVery Hard preflightに失敗しました。');
    exitCode = 3;
  } on FormatException catch (error) {
    stderr.writeln('引数エラー: ${error.message}');
    stderr.write(_usage);
    exitCode = 2;
  } on Object {
    // Do not print provider response bodies, request bodies, or arbitrary
    // exception text. The report contains only classified safe diagnostics.
    stderr.writeln('停止: ベンチマークを完了できませんでした。');
    exitCode = 1;
  }
}

const _usage =
    '''Very Hard / Hard 80-match local comparison

Usage:
  fvm dart run tool/very_hard/run.dart \
    --pr-number <number> \
    --pr-head <full-40-char-pr-head-sha> \
    --preview-url <https://preview.example.vercel.app>

The command refuses to run when `git rev-parse HEAD` differs from --pr-head.
The Preview URL must be an https/http origin without query parameters or
credentials. The endpoint path is added locally as
${VeryHardCpuConfig.endpointPath}.
''';

Map<String, String> _parseArguments(List<String> arguments) {
  const required = {'--pr-number', '--pr-head', '--preview-url'};
  final parsed = <String, String>{};
  for (var index = 0; index < arguments.length; index++) {
    final key = arguments[index];
    if (!required.contains(key)) {
      throw FormatException('不明な引数です: $key');
    }
    if (parsed.containsKey(key) || index + 1 >= arguments.length) {
      throw FormatException('$key の値が必要です');
    }
    final value = arguments[++index];
    if (value.startsWith('--') || value.isEmpty) {
      throw FormatException('$key の値が必要です');
    }
    parsed[key] = value;
  }
  for (final key in required) {
    if (!parsed.containsKey(key)) throw FormatException('$key が必要です');
  }
  return parsed;
}

int _parsePositiveInt(String value, String name) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) {
    throw FormatException('$name は正の整数で指定してください');
  }
  return parsed;
}

String _parseSha(String value) {
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(value)) {
    throw const FormatException('--pr-head は40桁の小文字SHAで指定してください');
  }
  return value;
}

Uri _parsePreviewUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw const FormatException(
      '--preview-url は認証情報・queryなしのhttp(s) URLで指定してください',
    );
  }
  return uri;
}

Future<String> _readLocalHead() async {
  final result = await Process.run('git', ['rev-parse', 'HEAD']);
  if (result.exitCode != 0) {
    throw const FormatException('ローカルHEADを取得できません');
  }
  final head = result.stdout.toString().trim();
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(head)) {
    throw const FormatException('ローカルHEADの形式が不正です');
  }
  return head;
}
