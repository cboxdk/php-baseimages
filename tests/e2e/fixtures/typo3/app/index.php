<?php
header('Content-Type: application/json');

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

function mysql_check(): array {
    try {
        $pdo = new PDO(
            sprintf('mysql:host=%s;port=3306;dbname=%s', getenv('DB_HOST') ?: 'mysql', getenv('DB_DATABASE') ?: 'typo3'),
            getenv('DB_USERNAME') ?: 'typo3',
            getenv('DB_PASSWORD') ?: 'secret',
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        $result = $pdo->query('SELECT VERSION() as version')->fetch(PDO::FETCH_ASSOC);
        return ['ok' => true, 'version' => $result['version']];
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => $e->getMessage()];
    }
}

function redis_check(): array {
    try {
        $redis = new Redis();
        $redis->connect(getenv('REDIS_HOST') ?: 'redis', 6379, 2.0);
        $redis->set('typo3_e2e', 'cache', 5);
        $value = $redis->get('typo3_e2e');
        return ['ok' => $value === 'cache'];
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => $e->getMessage()];
    }
}

switch ($path) {
    case '/':
        echo json_encode([
            'status' => 'ok',
            'cms' => 'typo3',
            'version' => '12.x',
        ]);
        break;

    case '/health':
        $db = mysql_check();
        $redis = redis_check();
        $healthy = ($db['ok'] ?? false) && ($redis['ok'] ?? false);
        http_response_code($healthy ? 200 : 503);
        echo json_encode([
            'status' => $healthy ? 'healthy' : 'unhealthy',
            'database' => $db,
            'redis' => $redis,
        ]);
        break;

    case '/db':
        $db = mysql_check();
        http_response_code($db['ok'] ? 200 : 500);
        echo json_encode($db);
        break;

    case '/redis':
        $redis = redis_check();
        http_response_code($redis['ok'] ? 200 : 500);
        echo json_encode($redis);
        break;

    case '/scheduler':
        $cron = shell_exec('crontab -l 2>/dev/null') ?: '';
        echo json_encode([
            'env' => getenv('LARAVEL_SCHEDULER'),
            'cron_configured' => trim($cron) !== '',
        ]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['error' => 'Not Found', 'path' => $path]);
}
