<?php
/**
 * Database Connection Tests
 * Tests MySQL, PostgreSQL, and SQLite connectivity
 */

header('Content-Type: application/json');

$results = [
    'status' => 'ok',
    'timestamp' => date('c'),
    'php_version' => PHP_VERSION,
    'extensions' => [
        'pdo' => extension_loaded('pdo'),
        'pdo_mysql' => extension_loaded('pdo_mysql'),
        'pdo_pgsql' => extension_loaded('pdo_pgsql'),
        'pdo_sqlite' => extension_loaded('pdo_sqlite'),
        'mysqli' => extension_loaded('mysqli'),
        'pgsql' => extension_loaded('pgsql'),
    ],
    'tests' => [],
];

// Test MySQL with PDO
$results['tests']['mysql_pdo'] = testMySQLPDO();

// Test MySQL with mysqli
$results['tests']['mysql_mysqli'] = testMySQLMysqli();

// Test PostgreSQL with PDO
$results['tests']['postgres_pdo'] = testPostgreSQLPDO();

// Test PostgreSQL with native driver
$results['tests']['postgres_native'] = testPostgreSQLNative();

// Test SQLite
$results['tests']['sqlite'] = testSQLite();

echo json_encode($results, JSON_PRETTY_PRINT);

// ─────────────────────────────────────────────────────────────────────────────
// Test Functions
// ─────────────────────────────────────────────────────────────────────────────

function testMySQLPDO(): array {
    $result = ['driver' => 'PDO MySQL', 'success' => false];

    if (!extension_loaded('pdo_mysql')) {
        $result['error'] = 'pdo_mysql extension not loaded';
        return $result;
    }

    try {
        $dsn = sprintf(
            'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
            getenv('DB_HOST') ?: 'mysql',
            getenv('DB_PORT') ?: '3306',
            getenv('DB_DATABASE') ?: 'test_db'
        );

        $pdo = new PDO($dsn, getenv('DB_USERNAME') ?: 'test_user', getenv('DB_PASSWORD') ?: 'test_password', [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);

        // Test query
        $stmt = $pdo->query('SELECT VERSION() as version, NOW() as server_time');
        $row = $stmt->fetch();

        $result['success'] = true;
        $result['version'] = $row['version'];
        $result['server_time'] = $row['server_time'];

        // Test write operation
        $pdo->exec('CREATE TABLE IF NOT EXISTS test_table (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))');
        $pdo->exec("INSERT INTO test_table (name) VALUES ('test_value')");
        $count = $pdo->query('SELECT COUNT(*) as cnt FROM test_table')->fetch()['cnt'];
        $pdo->exec('DROP TABLE test_table');

        $result['write_test'] = 'passed';
        $result['row_count'] = (int)$count;

    } catch (PDOException $e) {
        $result['error'] = $e->getMessage();
    }

    return $result;
}

function testMySQLMysqli(): array {
    $result = ['driver' => 'mysqli', 'success' => false];

    if (!extension_loaded('mysqli')) {
        $result['error'] = 'mysqli extension not loaded';
        return $result;
    }

    try {
        $mysqli = new mysqli(
            getenv('DB_HOST') ?: 'mysql',
            getenv('DB_USERNAME') ?: 'test_user',
            getenv('DB_PASSWORD') ?: 'test_password',
            getenv('DB_DATABASE') ?: 'test_db',
            (int)(getenv('DB_PORT') ?: 3306)
        );

        if ($mysqli->connect_error) {
            throw new Exception($mysqli->connect_error);
        }

        $res = $mysqli->query('SELECT VERSION() as version');
        $row = $res->fetch_assoc();

        $result['success'] = true;
        $result['version'] = $row['version'];
        $result['client_info'] = $mysqli->client_info;

        $mysqli->close();

    } catch (Exception $e) {
        $result['error'] = $e->getMessage();
    }

    return $result;
}

function testPostgreSQLPDO(): array {
    $result = ['driver' => 'PDO PostgreSQL', 'success' => false];

    if (!extension_loaded('pdo_pgsql')) {
        $result['error'] = 'pdo_pgsql extension not loaded';
        return $result;
    }

    try {
        $dsn = sprintf(
            'pgsql:host=%s;port=%s;dbname=%s',
            getenv('POSTGRES_HOST') ?: 'postgres',
            getenv('POSTGRES_PORT') ?: '5432',
            getenv('POSTGRES_DB') ?: 'test_db'
        );

        $pdo = new PDO($dsn, getenv('POSTGRES_USER') ?: 'test_user', getenv('POSTGRES_PASSWORD') ?: 'test_password', [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ]);

        $stmt = $pdo->query('SELECT version() as version, NOW() as server_time');
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        $result['success'] = true;
        $result['version'] = $row['version'];
        $result['server_time'] = $row['server_time'];

        // Test write
        $pdo->exec('CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name VARCHAR(255))');
        $pdo->exec("INSERT INTO test_table (name) VALUES ('test_value')");
        $count = $pdo->query('SELECT COUNT(*) as cnt FROM test_table')->fetch(PDO::FETCH_ASSOC)['cnt'];
        $pdo->exec('DROP TABLE test_table');

        $result['write_test'] = 'passed';
        $result['row_count'] = (int)$count;

    } catch (PDOException $e) {
        $result['error'] = $e->getMessage();
    }

    return $result;
}

function testPostgreSQLNative(): array {
    $result = ['driver' => 'pgsql native', 'success' => false];

    if (!extension_loaded('pgsql')) {
        $result['error'] = 'pgsql extension not loaded';
        return $result;
    }

    try {
        $connStr = sprintf(
            'host=%s port=%s dbname=%s user=%s password=%s',
            getenv('POSTGRES_HOST') ?: 'postgres',
            getenv('POSTGRES_PORT') ?: '5432',
            getenv('POSTGRES_DB') ?: 'test_db',
            getenv('POSTGRES_USER') ?: 'test_user',
            getenv('POSTGRES_PASSWORD') ?: 'test_password'
        );

        $conn = pg_connect($connStr);
        if (!$conn) {
            throw new Exception('Connection failed');
        }

        $res = pg_query($conn, 'SELECT version() as version');
        $row = pg_fetch_assoc($res);

        $result['success'] = true;
        $result['version'] = substr($row['version'], 0, 50) . '...';

        pg_close($conn);

    } catch (Exception $e) {
        $result['error'] = $e->getMessage();
    }

    return $result;
}

function testSQLite(): array {
    $result = ['driver' => 'SQLite', 'success' => false];

    if (!extension_loaded('pdo_sqlite')) {
        $result['error'] = 'pdo_sqlite extension not loaded';
        return $result;
    }

    $dbPath = '/tmp/test_sqlite.db';

    try {
        $pdo = new PDO("sqlite:$dbPath", null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ]);

        // Get SQLite version
        $version = $pdo->query('SELECT sqlite_version() as version')->fetch(PDO::FETCH_ASSOC)['version'];

        // Test table operations
        $pdo->exec('CREATE TABLE IF NOT EXISTS test_table (id INTEGER PRIMARY KEY, name TEXT)');
        $pdo->exec("INSERT INTO test_table (name) VALUES ('test_value')");
        $count = $pdo->query('SELECT COUNT(*) as cnt FROM test_table')->fetch(PDO::FETCH_ASSOC)['cnt'];

        $result['success'] = true;
        $result['version'] = $version;
        $result['write_test'] = 'passed';
        $result['row_count'] = (int)$count;

        // Cleanup
        $pdo = null;
        @unlink($dbPath);

    } catch (PDOException $e) {
        $result['error'] = $e->getMessage();
        @unlink($dbPath);
    }

    return $result;
}
