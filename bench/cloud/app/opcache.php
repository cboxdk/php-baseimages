<?php
// Reports opcache status as the WEB runtime sees it (CLI lies about this).
header('Content-Type: application/json');
$st = function_exists('opcache_get_status') ? @opcache_get_status(false) : false;
echo json_encode([
    'enabled' => is_array($st) && ($st['opcache_enabled'] ?? false),
    'jit' => is_array($st) ? ($st['jit']['on'] ?? false) : false,
]);
