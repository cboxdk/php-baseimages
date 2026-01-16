<?php
/**
 * Rootless Container Test Fixture
 * Tests PHP functionality in rootless container mode
 */

header('Content-Type: application/json');

$response = [
    'status' => 'ok',
    'php_version' => PHP_VERSION,
    'sapi' => php_sapi_name(),
    'timestamp' => date('c'),

    // Rootless-specific information
    'rootless' => [
        'env_var' => getenv('CBOX_ROOTLESS') ?: 'unset',
        'user_id' => posix_getuid(),
        'user_name' => posix_getpwuid(posix_getuid())['name'] ?? 'unknown',
        'group_id' => posix_getgid(),
    ],

    // Extension checks
    'extensions' => [
        'opcache' => function_exists('opcache_get_status'),
        'redis' => extension_loaded('redis'),
        'pdo_mysql' => extension_loaded('pdo_mysql'),
        'pdo_pgsql' => extension_loaded('pdo_pgsql'),
        'gd' => extension_loaded('gd'),
        'intl' => extension_loaded('intl'),
        'zip' => extension_loaded('zip'),
        'bcmath' => extension_loaded('bcmath'),
        'pcntl' => extension_loaded('pcntl'),
    ],

    // Server info
    'server' => [
        'software' => $_SERVER['SERVER_SOFTWARE'] ?? 'unknown',
        'protocol' => $_SERVER['SERVER_PROTOCOL'] ?? 'unknown',
        'port' => $_SERVER['SERVER_PORT'] ?? 'unknown',
    ],
];

// Test file write (permissions check)
$testFile = '/tmp/cbox-rootless-test-' . uniqid() . '.txt';
$writeTest = @file_put_contents($testFile, 'test');
$response['filesystem'] = [
    'write_test' => $writeTest !== false,
    'temp_dir_writable' => is_writable('/tmp'),
];
if ($writeTest !== false) {
    @unlink($testFile);
}

// Test session (if enabled)
if (session_status() === PHP_SESSION_NONE) {
    @session_start();
}
$response['session'] = [
    'status' => session_status(),
    'id' => session_id() ?: null,
];

echo json_encode($response, JSON_PRETTY_PRINT);
