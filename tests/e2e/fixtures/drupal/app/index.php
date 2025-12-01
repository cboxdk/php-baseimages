<?php
header('Content-Type: application/json');

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

function check_postgres(): array {
    $dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s', getenv('DB_HOST') ?: 'postgres', getenv('DB_PORT') ?: '5432', getenv('DB_DATABASE') ?: 'drupal');
    try {
        $pdo = new PDO($dsn, getenv('DB_USERNAME') ?: 'drupal', getenv('DB_PASSWORD') ?: 'secret', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        $result = $pdo->query('SELECT NOW() AS time')->fetch(PDO::FETCH_ASSOC);
        return ['ok' => true, 'time' => $result['time']];
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => $e->getMessage()];
    }
}

function check_redis(): array {
    try {
        $redis = new Redis();
        $redis->connect(getenv('REDIS_HOST') ?: 'redis', 6379, 2.0);
        $redis->set('drupal_e2e', '1', 5);
        $value = $redis->get('drupal_e2e');
        return ['ok' => $value === '1'];
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => $e->getMessage()];
    }
}

switch ($path) {
    case '/':
        echo json_encode([
            'status' => 'ok',
            'cms' => 'drupal',
            'version' => '10.x',
        ]);
        break;

    case '/health':
        $db = check_postgres();
        $redis = check_redis();
        $healthy = ($db['ok'] ?? false) && ($redis['ok'] ?? false);
        http_response_code($healthy ? 200 : 503);
        echo json_encode([
            'status' => $healthy ? 'healthy' : 'unhealthy',
            'database' => $db,
            'redis' => $redis,
        ]);
        break;

    case '/db':
        $db = check_postgres();
        http_response_code($db['ok'] ? 200 : 500);
        echo json_encode($db);
        break;

    case '/redis':
        $redis = check_redis();
        http_response_code($redis['ok'] ? 200 : 500);
        echo json_encode($redis);
        break;

    case '/cron':
        $cron = shell_exec('crontab -l 2>/dev/null') ?: '';
        echo json_encode([
            'scheduler_env' => getenv('LARAVEL_SCHEDULER'),
            'cron_configured' => trim($cron) !== '',
        ]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['error' => 'Not Found', 'path' => $path]);
}
