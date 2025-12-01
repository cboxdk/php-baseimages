<?php
/**
 * Minimal Symfony-like entry point for E2E testing
 * This simulates a Symfony app structure without the full framework
 */

// Simulate Symfony bootstrap
define('SYMFONY_START', microtime(true));

// Load environment
$env = [
    'APP_ENV' => getenv('APP_ENV') ?: 'prod',
    'APP_DEBUG' => getenv('APP_DEBUG') === '1',
    'APP_SECRET' => getenv('APP_SECRET') ?: 'default_secret',
    'DATABASE_URL' => getenv('DATABASE_URL') ?: '',
];

// Parse DATABASE_URL if present
$dbConfig = [];
if (!empty($env['DATABASE_URL'])) {
    $dbConfig = parse_url($env['DATABASE_URL']);
    $dbConfig['database'] = ltrim($dbConfig['path'] ?? '', '/');
}

// Route handling
$uri = $_SERVER['REQUEST_URI'] ?? '/';
$path = parse_url($uri, PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// Default content type
header('Content-Type: application/json');

switch ($path) {
    case '/':
    case '/index.php':
        echo json_encode([
            'status' => 'ok',
            'framework' => 'Symfony',
            'version' => '7.0',
            'environment' => $env['APP_ENV'],
            'debug' => $env['APP_DEBUG'],
            'php_version' => PHP_VERSION,
            'message' => 'Welcome to Symfony E2E Test Application',
        ], JSON_PRETTY_PRINT);
        break;

    case '/health':
        $checks = [];
        $healthy = true;

        // PHP check
        $checks['php'] = [
            'status' => 'ok',
            'version' => PHP_VERSION,
        ];

        // Required extensions check
        $requiredExtensions = ['intl', 'mbstring', 'xml', 'ctype'];
        $extensionsOk = true;
        $missingExtensions = [];
        foreach ($requiredExtensions as $ext) {
            if (!extension_loaded($ext)) {
                $extensionsOk = false;
                $missingExtensions[] = $ext;
            }
        }
        $checks['extensions'] = [
            'status' => $extensionsOk ? 'ok' : 'warning',
            'missing' => $missingExtensions,
        ];

        // Cache directory check
        $cacheDir = dirname(__DIR__) . '/var/cache';
        $cacheWritable = is_dir($cacheDir) && is_writable($cacheDir);
        $checks['cache'] = [
            'status' => $cacheWritable ? 'ok' : 'error',
            'path' => $cacheDir,
            'writable' => $cacheWritable,
        ];
        if (!$cacheWritable) {
            $healthy = false;
        }

        // Log directory check
        $logDir = dirname(__DIR__) . '/var/log';
        $logWritable = is_dir($logDir) && is_writable($logDir);
        $checks['log'] = [
            'status' => $logWritable ? 'ok' : 'error',
            'path' => $logDir,
            'writable' => $logWritable,
        ];
        if (!$logWritable) {
            $healthy = false;
        }

        // Database check (if configured)
        if (!empty($dbConfig)) {
            try {
                $dsn = sprintf(
                    'mysql:host=%s;port=%d;dbname=%s',
                    $dbConfig['host'] ?? 'localhost',
                    $dbConfig['port'] ?? 3306,
                    $dbConfig['database'] ?? 'symfony'
                );
                $pdo = new PDO(
                    $dsn,
                    $dbConfig['user'] ?? 'root',
                    $dbConfig['pass'] ?? '',
                    [PDO::ATTR_TIMEOUT => 5]
                );
                $pdo->query('SELECT 1');
                $checks['database'] = [
                    'status' => 'ok',
                    'driver' => 'mysql',
                ];
            } catch (Exception $e) {
                $checks['database'] = [
                    'status' => 'error',
                    'message' => $e->getMessage(),
                ];
                $healthy = false;
            }
        }

        // OPcache check
        if (function_exists('opcache_get_status')) {
            $opcacheStatus = opcache_get_status(false);
            $checks['opcache'] = [
                'status' => $opcacheStatus ? 'ok' : 'disabled',
                'enabled' => (bool)$opcacheStatus,
            ];
        }

        http_response_code($healthy ? 200 : 503);
        echo json_encode([
            'status' => $healthy ? 'healthy' : 'unhealthy',
            'symfony' => [
                'version' => '7.0',
                'environment' => $env['APP_ENV'],
            ],
            'checks' => $checks,
            'timestamp' => date('c'),
        ], JSON_PRETTY_PRINT);
        break;

    case '/api/test':
        echo json_encode([
            'message' => 'Symfony API endpoint working',
            'method' => $method,
            'framework' => 'Symfony',
            'timestamp' => date('c'),
        ], JSON_PRETTY_PRINT);
        break;

    case '/_profiler':
        // Simulate Symfony profiler (dev only)
        if ($env['APP_ENV'] !== 'dev') {
            http_response_code(404);
            echo json_encode(['error' => 'Profiler disabled in production']);
            break;
        }
        echo json_encode([
            'profiler' => 'enabled',
            'environment' => 'dev',
            'profiles' => [],
        ], JSON_PRETTY_PRINT);
        break;

    case '/db/test':
        if (empty($dbConfig)) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error',
                'message' => 'DATABASE_URL not configured',
            ]);
            break;
        }

        try {
            $dsn = sprintf(
                'mysql:host=%s;port=%d;dbname=%s',
                $dbConfig['host'] ?? 'localhost',
                $dbConfig['port'] ?? 3306,
                $dbConfig['database'] ?? 'symfony'
            );
            $pdo = new PDO(
                $dsn,
                $dbConfig['user'] ?? 'root',
                $dbConfig['pass'] ?? ''
            );
            $result = $pdo->query('SELECT NOW() as time, VERSION() as version')->fetch(PDO::FETCH_ASSOC);
            echo json_encode([
                'status' => 'connected',
                'database' => $dbConfig['database'],
                'server_time' => $result['time'],
                'version' => $result['version'],
            ], JSON_PRETTY_PRINT);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error',
                'message' => $e->getMessage(),
            ], JSON_PRETTY_PRINT);
        }
        break;

    case '/phpinfo':
        // Only in dev mode
        if ($env['APP_ENV'] !== 'dev') {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden in production']);
            break;
        }
        header('Content-Type: text/html');
        phpinfo();
        break;

    default:
        http_response_code(404);
        echo json_encode([
            'error' => 'Not Found',
            'message' => sprintf('No route found for "%s %s"', $method, $path),
            'status' => 404,
        ], JSON_PRETTY_PRINT);
}
