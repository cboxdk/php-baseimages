<?php
header('Content-Type: application/json');
echo json_encode(['ok' => true, 'php' => PHP_VERSION]);
