<?php
/**
 * EXIF Metadata Tests
 * Tests EXIF extension for reading image metadata
 */

header('Content-Type: application/json');

$results = [
    'library' => 'EXIF',
    'extension_loaded' => extension_loaded('exif'),
    'tests' => [],
];

if (!extension_loaded('exif')) {
    $results['error'] = 'EXIF extension not loaded';
    echo json_encode($results, JSON_PRETTY_PRINT);
    exit;
}

// Test EXIF functions exist
$results['tests']['functions'] = [
    'exif_read_data' => function_exists('exif_read_data'),
    'exif_thumbnail' => function_exists('exif_thumbnail'),
    'exif_imagetype' => function_exists('exif_imagetype'),
];

// Create a test JPEG with basic data
$tempDir = '/tmp/exif-tests';
if (!is_dir($tempDir)) {
    mkdir($tempDir, 0755, true);
}

// Create test image using GD
if (extension_loaded('gd')) {
    $img = imagecreatetruecolor(100, 100);
    $white = imagecolorallocate($img, 255, 255, 255);
    imagefill($img, 0, 0, $white);

    $jpegPath = "$tempDir/test.jpg";
    imagejpeg($img, $jpegPath, 85);
    imagedestroy($img);

    // Try to read EXIF (may be minimal for GD-created images)
    try {
        $exifData = @exif_read_data($jpegPath);
        $results['tests']['exif_read'] = [
            'success' => $exifData !== false,
            'data_available' => is_array($exifData) ? array_keys($exifData) : [],
        ];
    } catch (Exception $e) {
        $results['tests']['exif_read'] = [
            'success' => false,
            'error' => $e->getMessage(),
        ];
    }

    // Test imagetype detection
    $type = exif_imagetype($jpegPath);
    $results['tests']['imagetype'] = [
        'success' => $type === IMAGETYPE_JPEG,
        'detected_type' => $type,
        'expected_type' => IMAGETYPE_JPEG,
    ];

    unlink($jpegPath);
} else {
    $results['tests']['exif_read'] = [
        'success' => false,
        'error' => 'GD extension required to create test image',
    ];
}

@rmdir($tempDir);

echo json_encode($results, JSON_PRETTY_PRINT);
