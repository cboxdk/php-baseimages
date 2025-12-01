<?php
header('Content-Type: application/json');

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

function check_mysql(): array {
    try {
        $pdo = new PDO(
            sprintf('mysql:host=%s;port=3306;dbname=%s', getenv('DB_HOST') ?: 'mysql', getenv('DB_DATABASE') ?: 'magento'),
            getenv('DB_USERNAME') ?: 'magento',
            getenv('DB_PASSWORD') ?: 'secret',
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        $data = $pdo->query('SELECT NOW() as time, VERSION() as version')->fetch(PDO::FETCH_ASSOC);
        return ['ok' => true, 'time' => $data['time'], 'version' => $data['version']];
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => $e->getMessage()];
    }
}

function check_redis(): array {
    try {
        $redis = new Redis();
        $redis->connect(getenv('REDIS_HOST') ?: 'redis', 6379, 2.0);
        $key = 'magento_e2e_' . uniqid();
        $redis->set($key, 'ok', 5);
        $value = $redis->get($key);
        $redis->del($key);
        return ['ok' => $value === 'ok'];
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => $e->getMessage()];
    }
}

function check_opensearch(): array {
    $host = getenv('OPENSEARCH_HOST') ?: 'opensearch';
    $port = getenv('OPENSEARCH_PORT') ?: '9200';
    $url = sprintf('http://%s:%s/_cluster/health', $host, $port);
    try {
        $context = stream_context_create(['http' => ['timeout' => 2]]);
        $response = file_get_contents($url, false, $context);
        if ($response === false) {
            throw new RuntimeException('empty response');
        }
        $data = json_decode($response, true);
        return ['ok' => true, 'status' => $data['status'] ?? null];
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => $e->getMessage()];
    }
}

function scheduler_status(): array {
    $cron = shell_exec('crontab -l 2>/dev/null') ?: '';
    return [
        'env' => getenv('LARAVEL_SCHEDULER'),
        'cron_configured' => trim($cron) !== '',
    ];
}

switch ($path) {
    case '/':
        echo json_encode([
            'status' => 'ok',
            'platform' => 'magento',
            'opensearch' => check_opensearch(),
        ]);
        break;

    case '/health':
        $mysql = check_mysql();
        $redis = check_redis();
        $search = check_opensearch();
        $healthy = ($mysql['ok'] ?? false) && ($redis['ok'] ?? false) && ($search['ok'] ?? false);
        http_response_code($healthy ? 200 : 503);
        echo json_encode([
            'status' => $healthy ? 'healthy' : 'unhealthy',
            'mysql' => $mysql,
            'redis' => $redis,
            'opensearch' => $search,
        ]);
        break;

    case '/db':
        $mysql = check_mysql();
        http_response_code($mysql['ok'] ? 200 : 500);
        echo json_encode($mysql);
        break;

    case '/redis':
        $redis = check_redis();
        http_response_code($redis['ok'] ? 200 : 500);
        echo json_encode($redis);
        break;

    case '/search':
        $search = check_opensearch();
        http_response_code($search['ok'] ? 200 : 500);
        echo json_encode($search);
        break;

    case '/cron':
        echo json_encode(scheduler_status());
        break;

    default:
        http_response_code(404);
        echo json_encode(['error' => 'Not Found', 'path' => $path]);
}
