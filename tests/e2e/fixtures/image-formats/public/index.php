<?php
/**
 * Image Format Support Test Endpoint
 * Tests GD, ImageMagick, and various image format capabilities
 */

header('Content-Type: application/json');

$results = [
    'status' => 'ok',
    'timestamp' => date('c'),
    'php_version' => PHP_VERSION,
    'extensions' => [
        'gd' => extension_loaded('gd'),
        'imagick' => extension_loaded('imagick'),
        'exif' => extension_loaded('exif'),
    ],
];

// GD Info
if (extension_loaded('gd')) {
    $results['gd_info'] = gd_info();
}

// ImageMagick formats
if (extension_loaded('imagick')) {
    $results['imagick_formats'] = Imagick::queryFormats();
    $results['imagick_version'] = Imagick::getVersion();
}

echo json_encode($results, JSON_PRETTY_PRINT);
