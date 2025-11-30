<?php
/**
 * WordPress configuration stub for framework detection
 * PHPeek entrypoint detects WordPress by checking for this file
 */

define('DB_NAME', getenv('WORDPRESS_DB_NAME') ?: 'wordpress');
define('DB_USER', getenv('WORDPRESS_DB_USER') ?: 'wordpress');
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') ?: 'secret');
define('DB_HOST', getenv('WORDPRESS_DB_HOST') ?: 'mysql');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);

// Stub table prefix
$table_prefix = 'wp_';

// Stub ABSPATH
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
