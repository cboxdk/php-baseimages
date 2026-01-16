<?php
header('Content-Type: application/json');
echo json_encode([
    'status' => 'ok',
    'php_version' => PHP_VERSION,
    'server' => 'Cbox PM Test',
    'timestamp' => date('c'),
]);
