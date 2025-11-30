<?php
/**
 * Minimal Laravel-like entry point for E2E testing
 * This simulates a Laravel app structure without the full framework
 */

// Simulate Laravel bootstrap
define('LARAVEL_START', microtime(true));

// Load environment (simulated)
$env = [
    'APP_ENV' => getenv('APP_ENV') ?: 'production',
    'APP_DEBUG' => getenv('APP_DEBUG') === 'true',
    'DB_HOST' => getenv('DB_HOST') ?: 'localhost',
    'REDIS_HOST' => getenv('REDIS_HOST') ?: 'localhost',
];

// Route handling
$uri = $_SERVER['REQUEST_URI'] ?? '/';
$path = parse_url($uri, PHP_URL_PATH);

header('Content-Type: application/json');

switch ($path) {
    case '/':
    case '/index.php':
        echo json_encode([
            'status' => 'ok',
            'framework' => 'laravel',
            'version' => '11.x',
            'env' => $env['APP_ENV'],
            'debug' => $env['APP_DEBUG'],
        ]);
        break;

    case '/app-health':
        $checks = [];
        $healthy = true;

        // PHP check
        $checks['php'] = true;

        // MySQL check
        try {
            $pdo = new PDO(
                sprintf('mysql:host=%s;port=3306;dbname=laravel', $env['DB_HOST']),
                getenv('DB_USERNAME') ?: 'laravel',
                getenv('DB_PASSWORD') ?: 'secret',
                [PDO::ATTR_TIMEOUT => 5]
            );
            $pdo->query('SELECT 1');
            $checks['mysql'] = true;
        } catch (Exception $e) {
            $checks['mysql'] = false;
            $checks['mysql_error'] = $e->getMessage();
            $healthy = false;
        }

        // Redis check
        try {
            $redis = new Redis();
            $redis->connect($env['REDIS_HOST'], 6379, 5);
            $redis->ping();
            $checks['redis'] = true;
        } catch (Exception $e) {
            $checks['redis'] = false;
            $checks['redis_error'] = $e->getMessage();
            $healthy = false;
        }

        // OPcache check
        $checks['opcache'] = function_exists('opcache_get_status') && opcache_get_status() !== false;

        http_response_code($healthy ? 200 : 503);
        echo json_encode([
            'status' => $healthy ? 'healthy' : 'unhealthy',
            'checks' => $checks,
            'timestamp' => date('c'),
        ]);
        break;

    case '/api/test':
        echo json_encode([
            'message' => 'API endpoint working',
            'method' => $_SERVER['REQUEST_METHOD'],
            'timestamp' => date('c'),
        ]);
        break;

    case '/db/test':
        try {
            $pdo = new PDO(
                sprintf('mysql:host=%s;port=3306;dbname=laravel', $env['DB_HOST']),
                getenv('DB_USERNAME') ?: 'laravel',
                getenv('DB_PASSWORD') ?: 'secret'
            );
            $result = $pdo->query('SELECT NOW() as time, VERSION() as version')->fetch(PDO::FETCH_ASSOC);
            echo json_encode([
                'status' => 'connected',
                'database' => 'laravel',
                'server_time' => $result['time'],
                'version' => $result['version'],
            ]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error',
                'message' => $e->getMessage(),
            ]);
        }
        break;

    case '/redis/test':
        try {
            $redis = new Redis();
            $redis->connect($env['REDIS_HOST'], 6379);
            $testKey = 'e2e_test_' . uniqid();
            $redis->set($testKey, 'test_value', 10);
            $value = $redis->get($testKey);
            $redis->del($testKey);
            echo json_encode([
                'status' => 'connected',
                'read_write' => $value === 'test_value',
                'info' => $redis->info('server'),
            ]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error',
                'message' => $e->getMessage(),
            ]);
        }
        break;

    case '/scheduler/test':
        // Check if scheduler is configured (cron entry exists)
        $cronOutput = shell_exec('crontab -l 2>/dev/null') ?? '';
        $schedulerEnabled = strpos($cronOutput, 'schedule:run') !== false ||
                           strpos($cronOutput, 'artisan') !== false ||
                           getenv('LARAVEL_SCHEDULER') === 'true';
        echo json_encode([
            'scheduler_env' => getenv('LARAVEL_SCHEDULER'),
            'cron_configured' => !empty($cronOutput),
            'scheduler_likely_enabled' => $schedulerEnabled,
        ]);
        break;

    default:
        http_response_code(404);
        echo json_encode([
            'error' => 'Not Found',
            'path' => $path,
        ]);
}
