<?php
// Fixture for the nginx-template scenario. @@RELEASE@@ is replaced with the
// release id when the scenario builds the release tree, so a response says
// which release on disk produced it - the whole point of the $realpath_root
// assertions.
header('Content-Type: application/json');
echo json_encode([
    'release' => '@@RELEASE@@',
    'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? '',
    'script_filename' => $_SERVER['SCRIPT_FILENAME'] ?? '',
    'http_host' => $_SERVER['HTTP_HOST'] ?? '',
    'method' => $_SERVER['REQUEST_METHOD'] ?? '',
]);
