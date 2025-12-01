<?php
/**
 * PHPeek Base Image Test
 *
 * Simple PHP file to verify your container is working.
 * Place this in your webroot (public/ or root depending on your app).
 */

$extensions = get_loaded_extensions();
sort($extensions);

$checks = [
    'PHP Version' => PHP_VERSION,
    'Server Software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown',
    'Document Root' => $_SERVER['DOCUMENT_ROOT'] ?? 'Unknown',
    'Extensions Loaded' => count($extensions),
    'OPcache Enabled' => function_exists('opcache_get_status') && opcache_get_status() ? 'Yes' : 'No',
    'APCu Enabled' => extension_loaded('apcu') && ini_get('apc.enabled') ? 'Yes' : 'No',
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PHPeek Container Test</title>
    <style>
        body { font-family: system-ui, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; background: #f5f5f5; }
        h1 { color: #2563eb; }
        .card { background: white; padding: 20px; margin: 20px 0; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #f8fafc; font-weight: 600; }
        .success { color: #16a34a; }
        .mono { font-family: monospace; background: #f1f5f9; padding: 2px 6px; border-radius: 4px; }
        .ext-list { font-size: 14px; line-height: 1.8; }
    </style>
</head>
<body>
    <h1>PHPeek Container Test</h1>
    <p class="success">Container is working correctly.</p>

    <div class="card">
        <h2>System Information</h2>
        <table>
            <?php foreach ($checks as $label => $value): ?>
            <tr>
                <th><?= htmlspecialchars($label) ?></th>
                <td class="mono"><?= htmlspecialchars($value) ?></td>
            </tr>
            <?php endforeach; ?>
        </table>
    </div>

    <div class="card">
        <h2>Loaded Extensions (<?= count($extensions) ?>)</h2>
        <p class="ext-list">
            <?= implode(', ', array_map('htmlspecialchars', $extensions)) ?>
        </p>
    </div>

    <div class="card">
        <h2>Environment</h2>
        <table>
            <tr><th>APP_ENV</th><td class="mono"><?= htmlspecialchars(getenv('APP_ENV') ?: 'not set') ?></td></tr>
            <tr><th>APP_DEBUG</th><td class="mono"><?= htmlspecialchars(getenv('APP_DEBUG') ?: 'not set') ?></td></tr>
        </table>
    </div>

    <p style="color: #64748b; font-size: 14px; margin-top: 30px;">
        Generated: <?= date('Y-m-d H:i:s T') ?>
    </p>
</body>
</html>
