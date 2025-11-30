<?php
/**
 * Plain PHP Test Fixture
 * Tests basic PHP functionality without any framework
 */

header('Content-Type: application/json');

$response = [
    'status' => 'ok',
    'php_version' => PHP_VERSION,
    'sapi' => php_sapi_name(),
    'timestamp' => date('c'),
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
    'server' => [
        'software' => $_SERVER['SERVER_SOFTWARE'] ?? 'unknown',
        'protocol' => $_SERVER['SERVER_PROTOCOL'] ?? 'unknown',
    ],
];

// Test file write (permissions check)
$testFile = '/tmp/phpeek-test-' . uniqid() . '.txt';
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
