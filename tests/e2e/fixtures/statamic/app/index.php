<?php
header('Content-Type: application/json');

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

function mysql_check(): array {
    try {
        $pdo = new PDO(
            sprintf('mysql:host=%s;port=3306;dbname=%s', getenv('DB_HOST') ?: 'mysql', getenv('DB_DATABASE') ?: 'statamic'),
            getenv('DB_USERNAME') ?: 'statamic',
            getenv('DB_PASSWORD') ?: 'secret',
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        $result = $pdo->query('SELECT NOW() AS time')->fetch(PDO::FETCH_ASSOC);
        return ['ok' => true, 'time' => $result['time']];
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => $e->getMessage()];
    }
}

function redis_check(): array {
    try {
        $redis = new Redis();
        $redis->connect(getenv('REDIS_HOST') ?: 'redis', 6379, 2.0);
        $redis->set('statamic_e2e', '1', 5);
        $value = $redis->get('statamic_e2e');
        return ['ok' => $value === '1'];
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => $e->getMessage()];
    }
}

switch ($path) {
    case '/':
        echo json_encode([
            'status' => 'ok',
            'cms' => 'statamic',
            'queue_enabled' => getenv('LARAVEL_QUEUE') === 'true',
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

    case '/queue':
        echo json_encode([
            'queue_env' => getenv('LARAVEL_QUEUE'),
            'scheduler_env' => getenv('LARAVEL_SCHEDULER'),
        ]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['error' => 'Not Found', 'path' => $path]);
}
