<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PHPeek Runtime Configuration Test</title>
    <style>
        body { font-family: system-ui; max-width: 1200px; margin: 50px auto; padding: 20px; }
        h1 { color: #2563eb; }
        .section { background: #f1f5f9; padding: 20px; margin: 20px 0; border-radius: 8px; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #cbd5e1; }
        th { background: #e2e8f0; font-weight: 600; }
        .success { color: #16a34a; }
        .value { font-family: monospace; background: white; padding: 2px 6px; border-radius: 4px; }
    </style>
</head>
<body>
    <h1>🚀 PHPeek Runtime Configuration Test</h1>
    <p>Testing environment variable-based PHP and Nginx configuration.</p>

    <div class="section">
        <h2>📋 PHP Core Settings</h2>
        <table>
            <tr>
                <th>Setting</th>
                <th>Value</th>
                <th>Environment Variable</th>
            </tr>
            <tr>
                <td>Memory Limit</td>
                <td class="value"><?= ini_get('memory_limit') ?></td>
                <td class="value">PHP_MEMORY_LIMIT</td>
            </tr>
            <tr>
                <td>Max Execution Time</td>
                <td class="value"><?= ini_get('max_execution_time') ?>s</td>
                <td class="value">PHP_MAX_EXECUTION_TIME</td>
            </tr>
            <tr>
                <td>Upload Max Filesize</td>
                <td class="value"><?= ini_get('upload_max_filesize') ?></td>
                <td class="value">PHP_UPLOAD_MAX_FILE_SIZE</td>
            </tr>
            <tr>
                <td>Post Max Size</td>
                <td class="value"><?= ini_get('post_max_size') ?></td>
                <td class="value">PHP_POST_MAX_SIZE</td>
            </tr>
            <tr>
                <td>Display Errors</td>
                <td class="value"><?= ini_get('display_errors') ? 'On' : 'Off' ?></td>
                <td class="value">PHP_DISPLAY_ERRORS</td>
            </tr>
            <tr>
                <td>Error Reporting</td>
                <td class="value"><?= error_reporting() ?></td>
                <td class="value">PHP_ERROR_REPORTING</td>
            </tr>
            <tr>
                <td>Timezone</td>
                <td class="value"><?= ini_get('date.timezone') ?></td>
                <td class="value">PHP_DATE_TIMEZONE</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>⚡ OPcache Configuration</h2>
        <table>
            <?php
            $opcache_status = function_exists('opcache_get_status') ? opcache_get_status(false) : null;
            ?>
            <tr>
                <th>Setting</th>
                <th>Value</th>
                <th>Environment Variable</th>
            </tr>
            <tr>
                <td>OPcache Enabled</td>
                <td class="value <?= ini_get('opcache.enable') ? 'success' : '' ?>">
                    <?= ini_get('opcache.enable') ? '✓ Enabled' : '✗ Disabled' ?>
                </td>
                <td class="value">PHP_OPCACHE_ENABLE</td>
            </tr>
            <tr>
                <td>Memory Consumption</td>
                <td class="value"><?= ini_get('opcache.memory_consumption') ?>M</td>
                <td class="value">PHP_OPCACHE_MEMORY_CONSUMPTION</td>
            </tr>
            <tr>
                <td>Max Accelerated Files</td>
                <td class="value"><?= number_format(ini_get('opcache.max_accelerated_files')) ?></td>
                <td class="value">PHP_OPCACHE_MAX_ACCELERATED_FILES</td>
            </tr>
            <tr>
                <td>Validate Timestamps</td>
                <td class="value"><?= ini_get('opcache.validate_timestamps') ? 'Enabled' : 'Disabled' ?></td>
                <td class="value">PHP_OPCACHE_VALIDATE_TIMESTAMPS</td>
            </tr>
            <tr>
                <td>JIT Mode</td>
                <td class="value"><?= ini_get('opcache.jit') ?: 'Off' ?></td>
                <td class="value">PHP_OPCACHE_JIT</td>
            </tr>
            <tr>
                <td>JIT Buffer Size</td>
                <td class="value"><?= ini_get('opcache.jit_buffer_size') ?: 'N/A' ?></td>
                <td class="value">PHP_OPCACHE_JIT_BUFFER_SIZE</td>
            </tr>
            <?php if ($opcache_status): ?>
            <tr>
                <td>Memory Usage</td>
                <td class="value">
                    <?= round($opcache_status['memory_usage']['used_memory'] / 1024 / 1024, 2) ?>M /
                    <?= round(($opcache_status['memory_usage']['used_memory'] + $opcache_status['memory_usage']['free_memory']) / 1024 / 1024, 2) ?>M
                </td>
                <td>-</td>
            </tr>
            <tr>
                <td>Cached Scripts</td>
                <td class="value"><?= number_format($opcache_status['opcache_statistics']['num_cached_scripts']) ?></td>
                <td>-</td>
            </tr>
            <?php endif; ?>
        </table>
    </div>

    <div class="section">
        <h2>💾 APCu Configuration</h2>
        <table>
            <?php
            $apcu_enabled = extension_loaded('apcu') && ini_get('apc.enabled');
            ?>
            <tr>
                <th>Setting</th>
                <th>Value</th>
                <th>Environment Variable</th>
            </tr>
            <tr>
                <td>APCu Enabled</td>
                <td class="value <?= $apcu_enabled ? 'success' : '' ?>">
                    <?= $apcu_enabled ? '✓ Enabled' : '✗ Disabled' ?>
                </td>
                <td class="value">PHP_APCU_ENABLED</td>
            </tr>
            <tr>
                <td>Shared Memory Size</td>
                <td class="value"><?= ini_get('apc.shm_size') ?: 'N/A' ?></td>
                <td class="value">PHP_APCU_SHM_SIZE</td>
            </tr>
            <tr>
                <td>TTL</td>
                <td class="value"><?= ini_get('apc.ttl') ?: 'N/A' ?>s</td>
                <td class="value">PHP_APCU_TTL</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>🌐 Server Information</h2>
        <table>
            <tr>
                <th>Variable</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Server Software</td>
                <td class="value"><?= $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown' ?></td>
            </tr>
            <tr>
                <td>Server Protocol</td>
                <td class="value"><?= $_SERVER['SERVER_PROTOCOL'] ?? 'Unknown' ?></td>
            </tr>
            <tr>
                <td>Server Port</td>
                <td class="value"><?= $_SERVER['SERVER_PORT'] ?? 'Unknown' ?></td>
            </tr>
            <tr>
                <td>Request Scheme</td>
                <td class="value"><?= $_SERVER['REQUEST_SCHEME'] ?? 'Unknown' ?></td>
            </tr>
            <tr>
                <td>HTTPS</td>
                <td class="value"><?= isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? '✓ Enabled' : '✗ Disabled' ?></td>
            </tr>
            <tr>
                <td>Document Root</td>
                <td class="value"><?= $_SERVER['DOCUMENT_ROOT'] ?? 'Unknown' ?></td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>📊 PHP Version & Extensions</h2>
        <table>
            <tr>
                <td><strong>PHP Version:</strong></td>
                <td class="value"><?= PHP_VERSION ?></td>
            </tr>
            <tr>
                <td><strong>Loaded Extensions (<?= count(get_loaded_extensions()) ?>):</strong></td>
                <td class="value"><?= implode(', ', get_loaded_extensions()) ?></td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>✅ Test Results</h2>
        <p>
            <?php
            $tests_passed = true;
            $results = [];

            // Test 1: PHP Memory Limit
            $memory_limit = ini_get('memory_limit');
            if ($memory_limit !== false) {
                $results[] = "✓ PHP memory limit configured: {$memory_limit}";
            } else {
                $results[] = "✗ PHP memory limit not set";
                $tests_passed = false;
            }

            // Test 2: OPcache
            if (ini_get('opcache.enable')) {
                $results[] = "✓ OPcache is enabled";
            } else {
                $results[] = "⚠ OPcache is disabled (okay for development)";
            }

            // Test 3: APCu
            if ($apcu_enabled) {
                $results[] = "✓ APCu is enabled";
            } else {
                $results[] = "⚠ APCu is disabled";
            }

            // Test 4: Upload limits
            $upload_max = ini_get('upload_max_filesize');
            $post_max = ini_get('post_max_size');
            if ($upload_max && $post_max) {
                $results[] = "✓ Upload limits configured: {$upload_max} / {$post_max}";
            }

            foreach ($results as $result) {
                echo "<li>{$result}</li>";
            }
            ?>
        </p>
    </div>

    <div class="section">
        <p><strong>Status:</strong>
            <span class="<?= $tests_passed ? 'success' : '' ?>">
                <?= $tests_passed ? '✓ All critical tests passed!' : '⚠ Some tests failed' ?>
            </span>
        </p>
        <p style="color: #64748b; font-size: 14px;">
            Generated at: <?= date('Y-m-d H:i:s T') ?>
        </p>
    </div>
</body>
</html>
