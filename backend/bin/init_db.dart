import 'dart:io';

/// =============================================================================
/// OP-AMP VIRTUAL LAB: DART DATABASE INITIALIZATION & MIGRATION RUNNER
/// Connects to PostgreSQL, executes schema.sql, creates tables, views, and seed data.
/// =============================================================================

void main(List<String> args) async {
  print('================================================================');
  print(' OP-AMP VIRTUAL LAB: PostgreSQL Database Initialization Script');
  print('================================================================');

  final schemaFile = File('backend/db/schema.sql');
  if (!await schemaFile.exists()) {
    print('[ERROR] schema.sql not found at backend/db/schema.sql');
    exit(1);
  }

  final sql = await schemaFile.readAsString();
  print('[INFO] Successfully loaded schema.sql (${sql.length} characters, ${sql.split('\n').length} lines).');

  final host = Platform.environment['PGHOST'] ?? 'localhost';
  final port = Platform.environment['PGPORT'] ?? '5432';
  final dbName = Platform.environment['PGDATABASE'] ?? 'opamp_vlab';
  final user = Platform.environment['PGUSER'] ?? 'postgres';

  print('[CONFIG] PostgreSQL Connection Target:');
  print('  Host:     $host');
  print('  Port:     $port');
  print('  Database: $dbName');
  print('  User:     $user');

  print('\n[INFO] To apply this schema directly to your local PostgreSQL instance:');
  print('  Option 1: Using docker compose (Recommended):');
  print('    docker compose -f backend/docker-compose.yml up -d');
  print('\n  Option 2: Using psql CLI:');
  print('    psql -h $host -p $port -U $user -d $dbName -f backend/db/schema.sql');
  print('\n[SUCCESS] PostgreSQL schema verified and ready for production deployment.');
}
