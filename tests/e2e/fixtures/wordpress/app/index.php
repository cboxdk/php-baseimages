<?php
/**
 * Minimal WordPress-like entry point for E2E testing
 * This simulates WordPress structure without the full CMS
 */

// Simulate WordPress bootstrap
define('ABSPATH', __DIR__ . '/');
define('WP_DEBUG', true);

// Check if wp-config.php exists (framework detection marker)
$wpConfigExists = file_exists(ABSPATH . 'wp-config.php');

header('Content-Type: application/json');

$uri = $_SERVER['REQUEST_URI'] ?? '/';
$path = parse_url($uri, PHP_URL_PATH);

switch ($path) {
    case '/':
    case '/index.php':
        echo json_encode([
            'status' => 'ok',
            'cms' => 'wordpress',
            'version' => '6.4.0',
            'wp_config_exists' => $wpConfigExists,
            'abspath' => ABSPATH,
        ]);
        break;

    case '/health.php':
        require __DIR__ . '/health.php';
        break;

    case '/wp-admin/':
    case '/wp-admin/index.php':
        echo json_encode([
            'area' => 'admin',
            'status' => 'accessible',
        ]);
        break;

    default:
        // Simulate WordPress URL rewriting
        echo json_encode([
            'status' => 'ok',
            'path' => $path,
            'rewrite' => 'active',
        ]);
}
