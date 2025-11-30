<?php
/**
 * Security Test Endpoint
 * Returns basic info to confirm the app is running
 */

header('Content-Type: application/json');

echo json_encode([
    'status' => 'ok',
    'message' => 'Security test endpoint',
    'timestamp' => date('c'),
    'php_version' => PHP_VERSION,
], JSON_PRETTY_PRINT);
