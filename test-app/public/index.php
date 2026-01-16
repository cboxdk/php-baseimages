<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cbox Base Images - Test Page</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #666; margin-top: 30px; }
        .info { background: #e8f5e9; padding: 15px; border-radius: 4px; margin: 10px 0; }
        .success { color: #4CAF50; }
        .error { color: #f44336; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #4CAF50; color: white; }
        tr:hover { background: #f5f5f5; }
        .extension { display: inline-block; background: #4CAF50; color: white; padding: 4px 8px; margin: 2px; border-radius: 3px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐘 Cbox Base Images - Test Page</h1>

        <div class="info">
            <strong>PHP Version:</strong> <?php echo PHP_VERSION; ?><br>
            <strong>Server Software:</strong> <?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'N/A'; ?><br>
            <strong>Host:</strong> <?php echo gethostname(); ?>
        </div>

        <h2>PHP Information</h2>
        <table>
            <tr>
                <th>Setting</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Memory Limit</td>
                <td><?php echo ini_get('memory_limit'); ?></td>
            </tr>
            <tr>
                <td>Max Execution Time</td>
                <td><?php echo ini_get('max_execution_time'); ?> seconds</td>
            </tr>
            <tr>
                <td>Upload Max Filesize</td>
                <td><?php echo ini_get('upload_max_filesize'); ?></td>
            </tr>
            <tr>
                <td>Post Max Size</td>
                <td><?php echo ini_get('post_max_size'); ?></td>
            </tr>
            <tr>
                <td>OPcache Enabled</td>
                <td class="<?php echo ini_get('opcache.enable') ? 'success' : 'error'; ?>">
                    <?php echo ini_get('opcache.enable') ? '✓ Yes' : '✗ No'; ?>
                </td>
            </tr>
        </table>

        <h2>Installed Extensions</h2>
        <div>
            <?php
            $extensions = get_loaded_extensions();
            sort($extensions);
            foreach ($extensions as $ext) {
                echo "<span class='extension'>$ext</span>";
            }
            ?>
        </div>

        <h2>Database Connectivity Tests</h2>
        <table>
            <tr>
                <th>Database</th>
                <th>Status</th>
            </tr>
            <tr>
                <td>MySQL</td>
                <td class="<?php
                    try {
                        $pdo = new PDO('mysql:host=mysql;dbname=cbox_test', 'cbox', 'secret');
                        echo 'success">✓ Connected';
                    } catch (PDOException $e) {
                        echo 'error">✗ ' . $e->getMessage();
                    }
                ?>
                </td>
            </tr>
            <tr>
                <td>PostgreSQL</td>
                <td class="<?php
                    try {
                        $pdo = new PDO('pgsql:host=postgres;dbname=cbox_test', 'cbox', 'secret');
                        echo 'success">✓ Connected';
                    } catch (PDOException $e) {
                        echo 'error">✗ ' . $e->getMessage();
                    }
                ?>
                </td>
            </tr>
            <tr>
                <td>Redis</td>
                <td class="<?php
                    try {
                        if (extension_loaded('redis')) {
                            $redis = new Redis();
                            $redis->connect('redis', 6379);
                            $redis->set('test', 'value');
                            echo 'success">✓ Connected';
                            $redis->close();
                        } else {
                            echo 'error">✗ Extension not loaded';
                        }
                    } catch (Exception $e) {
                        echo 'error">✗ ' . $e->getMessage();
                    }
                ?>
                </td>
            </tr>
        </table>

        <h2>Composer</h2>
        <div class="info">
            <?php
            $composerVersion = shell_exec('composer --version 2>&1');
            echo nl2br(htmlspecialchars($composerVersion));
            ?>
        </div>

        <?php if (extension_loaded('xdebug')): ?>
        <h2>Xdebug (Development Mode)</h2>
        <div class="info success">
            ✓ Xdebug is loaded (Version: <?php echo phpversion('xdebug'); ?>)<br>
            <strong>Mode:</strong> <?php echo ini_get('xdebug.mode'); ?><br>
            <strong>Client Host:</strong> <?php echo ini_get('xdebug.client_host'); ?><br>
            <strong>Client Port:</strong> <?php echo ini_get('xdebug.client_port'); ?>
        </div>
        <?php endif; ?>

        <h2>Full PHP Info</h2>
        <details>
            <summary style="cursor: pointer; padding: 10px; background: #f5f5f5; border-radius: 4px;">
                Click to expand phpinfo()
            </summary>
            <div style="margin-top: 10px;">
                <?php phpinfo(); ?>
            </div>
        </details>
    </div>
</body>
</html>
