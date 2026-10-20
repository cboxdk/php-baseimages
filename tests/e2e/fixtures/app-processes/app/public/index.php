<?php
header('Content-Type: application/json');
echo json_encode([
    'ok' => true,
    'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? null,
    'script_filename' => $_SERVER['SCRIPT_FILENAME'] ?? null,
    'uid' => trim((string) shell_exec('id -u')),
]);
