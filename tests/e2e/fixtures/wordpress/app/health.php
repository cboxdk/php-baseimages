<?php
/**
 * Health check for WordPress E2E test
 */

header('Content-Type: application/json');

require_once __DIR__ . '/wp-config.php';

$checks = [];
$healthy = true;

// PHP check
$checks['php'] = true;

// MySQL check
try {
    $pdo = new PDO(
        sprintf('mysql:host=%s;port=3306;dbname=%s', DB_HOST, DB_NAME),
        DB_USER,
        DB_PASSWORD,
        [PDO::ATTR_TIMEOUT => 5]
    );
    $pdo->query('SELECT 1');
    $checks['mysql'] = true;
} catch (Exception $e) {
    $checks['mysql'] = false;
    $checks['mysql_error'] = $e->getMessage();
    $healthy = false;
}

// wp-config.php check
$checks['wp_config'] = file_exists(__DIR__ . '/wp-config.php');

// Uploads directory check
$uploadsDir = __DIR__ . '/wp-content/uploads';
$checks['uploads_writable'] = is_dir($uploadsDir) ? is_writable($uploadsDir) : 'not_created';

http_response_code($healthy ? 200 : 503);

echo json_encode([
    'status' => $healthy ? 'healthy' : 'unhealthy',
    'checks' => $checks,
    'timestamp' => date('c'),
]);
