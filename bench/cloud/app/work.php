<?php
// Deterministic request-level CPU work: 6000 chained sha256 rounds plus a
// small sort. Identical code must be used by the FrankenPHP worker router.
header('Content-Type: application/json');
$h = 'seed';
for ($i = 0; $i < 6000; $i++) { $h = hash('sha256', $h . $i); }
$a = [];
for ($i = 0; $i < 500; $i++) { $a[] = ($i * 2654435761) % 1000003; }
sort($a);
echo json_encode(['ok' => true, 'h' => substr($h, 0, 16), 'm' => $a[250]]);
