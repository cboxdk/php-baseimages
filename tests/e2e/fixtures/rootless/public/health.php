<?php
/**
 * Health check endpoint for rootless container
 */

header('Content-Type: application/json');

// Parse memory limit (handles K, M, G suffixes)
function parseMemoryLimit($limit) {
    if ($limit === '-1') return PHP_INT_MAX;
    $limit = trim($limit);
    $last = strtolower($limit[strlen($limit) - 1]);
    $value = (int)$limit;
    switch ($last) {
        case 'g': $value *= 1024;
        case 'm': $value *= 1024;
        case 'k': $value *= 1024;
    }
    return $value;
}

$memoryLimit = parseMemoryLimit(ini_get('memory_limit'));
$memoryUsage = memory_get_usage(true);

$checks = [
    'php' => true,
    'opcache' => function_exists('opcache_get_status') && opcache_get_status() !== false,
    'memory' => $memoryUsage < ($memoryLimit * 0.9),
    'rootless' => getenv('CBOX_ROOTLESS') === 'true',
    'non_root_user' => posix_getuid() !== 0,
];

$healthy = !in_array(false, $checks, true);

http_response_code($healthy ? 200 : 503);

echo json_encode([
    'status' => $healthy ? 'healthy' : 'unhealthy',
    'checks' => $checks,
    'user_id' => posix_getuid(),
    'timestamp' => date('c'),
]);
