import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';

import 'package:homecare_backend/db.dart';

Future<void> main(List<String> args) async {
  _loadEnv();

  final Directory migrationsDir = Directory('migrations');
  if (!migrationsDir.existsSync()) {
    stderr.writeln('No migrations directory found at ${migrationsDir.path}.');
    exitCode = 1;
    return;
  }

  final PostgreSQLConnection connection = await pg();
  await _ensureMigrationsTable(connection);

  final Set<String> appliedMigrations = await _fetchAppliedMigrations(connection);
  final List<File> migrationFiles = _collectMigrationFiles(migrationsDir);

  for (final File file in migrationFiles) {
    final String name = p.basename(file.path);
    if (appliedMigrations.contains(name)) {
      stdout.writeln('Skipping already applied migration: $name');
      continue;
    }

    final String sql = file.readAsStringSync();
    if (sql.trim().isEmpty) {
      stdout.writeln('Skipping empty migration: $name');
      continue;
    }

    stdout.writeln('Applying migration: $name');
    await connection.transaction((ctx) async {
      await ctx.execute(sql);
      await ctx.query(
        'INSERT INTO schema_migrations (filename) VALUES (@filename)',
        substitutionValues: {'filename': name},
      );
    });
    stdout.writeln('Applied migration: $name');
    appliedMigrations.add(name);
  }

  await closePg();
  stdout.writeln('Migration execution complete.');
}

void _loadEnv() {
  try {
    if (!dotenv.isInitialized) {
      dotenv.load();
    }
  } on FileSystemException {
    // Ignore missing .env file; fall back to process environment variables.
  }
}

Future<void> _ensureMigrationsTable(PostgreSQLConnection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      filename TEXT NOT NULL UNIQUE,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  ''');
}

Future<Set<String>> _fetchAppliedMigrations(PostgreSQLConnection connection) async {
  final results = await connection.query('SELECT filename FROM schema_migrations ORDER BY filename');
  return results.map((row) => row.first as String).toSet();
}

List<File> _collectMigrationFiles(Directory directory) {
  final files = directory
      .listSync(recursive: false, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.sql'))
      .toList();

  files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  return files;
}
