import 'dart:io';

Future<void> main() async {
  final repositoryRoot = _findRepositoryRoot(Directory.current);
  final adminWebDirectory = Directory(
    '${repositoryRoot.path}${Platform.pathSeparator}admin_web',
  );
  final pubspec = File(
    '${adminWebDirectory.path}${Platform.pathSeparator}pubspec.yaml',
  );

  if (!pubspec.existsSync()) {
    stderr.writeln(
      'Không tìm thấy admin_web/pubspec.yaml từ ${repositoryRoot.path}.',
    );
    exitCode = 2;
    return;
  }

  final arguments = <String>[
    'build',
    'web',
    '--release',
    '--csp',
    '--no-web-resources-cdn',
  ];

  // These values are public browser configuration, not secrets. Keeping them
  // optional lets the default same-origin /api/v1 deployment build cleanly.
  for (final name in const ['API_BASE_URL', 'APP_CHECK_SITE_KEY']) {
    final value = Platform.environment[name]?.trim();
    if (value != null && value.isNotEmpty) {
      arguments.add('--dart-define=$name=$value');
    }
  }

  stdout.writeln(
    'Building Flutter Admin Web from ${adminWebDirectory.path}...',
  );
  final process = await Process.start(
    'flutter',
    arguments,
    workingDirectory: adminWebDirectory.path,
    runInShell: Platform.isWindows,
  );

  await Future.wait<void>([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  final resultCode = await process.exitCode;
  if (resultCode != 0) {
    stderr.writeln(
      'Flutter Admin Web build failed with exit code $resultCode.',
    );
    exitCode = resultCode;
  }
}

Directory _findRepositoryRoot(Directory start) {
  var current = start.absolute;
  while (true) {
    final firebaseConfig = File(
      '${current.path}${Platform.pathSeparator}firebase.json',
    );
    final adminPubspec = File(
      '${current.path}${Platform.pathSeparator}admin_web'
      '${Platform.pathSeparator}pubspec.yaml',
    );
    if (firebaseConfig.existsSync() && adminPubspec.existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError(
        'Không tìm thấy repository chứa firebase.json và admin_web/pubspec.yaml.',
      );
    }
    current = parent;
  }
}
