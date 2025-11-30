<?php
/**
 * libvips Image Processing Test
 * Tests vips extension capabilities for image processing
 */

header('Content-Type: application/json');

$results = [];
$tempDir = sys_get_temp_dir();

// Check if vips extension is loaded
if (!extension_loaded('vips')) {
    echo json_encode([
        'error' => 'VIPS extension not loaded',
        'available' => false
    ], JSON_PRETTY_PRINT);
    exit;
}

// Create a test image using GD first (to have something to process)
$testImage = imagecreatetruecolor(200, 200);
$blue = imagecolorallocate($testImage, 0, 100, 200);
imagefill($testImage, 0, 0, $blue);
$testPath = $tempDir . '/vips_test_source.jpg';
imagejpeg($testImage, $testPath, 90);
imagedestroy($testImage);

// Test 1: JPEG processing
try {
    $image = vips_image_new_from_file($testPath);
    if ($image) {
        $outputPath = $tempDir . '/vips_test_output.jpg';
        $result = vips_image_write_to_file($image, $outputPath);
        $results['jpeg'] = [
            'success' => file_exists($outputPath),
            'size' => file_exists($outputPath) ? filesize($outputPath) : 0
        ];
        @unlink($outputPath);
    }
} catch (Exception $e) {
    $results['jpeg'] = [
        'success' => false,
        'error' => $e->getMessage()
    ];
}

// Test 2: WebP conversion
try {
    $image = vips_image_new_from_file($testPath);
    if ($image) {
        $outputPath = $tempDir . '/vips_test_output.webp';
        $result = vips_image_write_to_file($image, $outputPath . '[Q=80]');
        $results['webp'] = [
            'success' => file_exists($outputPath),
            'size' => file_exists($outputPath) ? filesize($outputPath) : 0
        ];
        @unlink($outputPath);
    }
} catch (Exception $e) {
    $results['webp'] = [
        'success' => false,
        'error' => $e->getMessage()
    ];
}

// Test 3: Thumbnail generation
try {
    $image = vips_image_new_from_file($testPath);
    if ($image) {
        // Use vips_thumbnail for efficient resizing
        $thumb = vips_call('thumbnail', $testPath, 100);
        if ($thumb) {
            $outputPath = $tempDir . '/vips_test_thumb.jpg';
            vips_image_write_to_file($thumb, $outputPath);
            $results['thumbnail'] = [
                'success' => file_exists($outputPath),
                'size' => file_exists($outputPath) ? filesize($outputPath) : 0
            ];
            @unlink($outputPath);
        }
    }
} catch (Exception $e) {
    // Fallback: try resize operation
    try {
        $image = vips_image_new_from_file($testPath);
        $resized = vips_call('resize', $image, 0.5);
        if ($resized) {
            $outputPath = $tempDir . '/vips_test_resized.jpg';
            vips_image_write_to_file($resized, $outputPath);
            $results['thumbnail'] = [
                'success' => file_exists($outputPath),
                'size' => file_exists($outputPath) ? filesize($outputPath) : 0,
                'method' => 'resize'
            ];
            @unlink($outputPath);
        }
    } catch (Exception $e2) {
        $results['thumbnail'] = [
            'success' => false,
            'error' => $e->getMessage()
        ];
    }
}

// Test 4: Strip metadata
try {
    $image = vips_image_new_from_file($testPath);
    if ($image) {
        // Remove all metadata by copying just pixel data
        $outputPath = $tempDir . '/vips_test_stripped.jpg';
        $result = vips_image_write_to_file($image, $outputPath . '[strip]');
        $results['strip_metadata'] = [
            'success' => file_exists($outputPath),
            'size' => file_exists($outputPath) ? filesize($outputPath) : 0
        ];
        @unlink($outputPath);
    }
} catch (Exception $e) {
    $results['strip_metadata'] = [
        'success' => false,
        'error' => $e->getMessage()
    ];
}

// Test 5: Get image info
try {
    $image = vips_image_new_from_file($testPath);
    if ($image) {
        $results['info'] = [
            'success' => true,
            'width' => vips_image_get($image, 'width'),
            'height' => vips_image_get($image, 'height'),
            'bands' => vips_image_get($image, 'bands'),
            'format' => vips_image_get($image, 'format')
        ];
    }
} catch (Exception $e) {
    $results['info'] = [
        'success' => false,
        'error' => $e->getMessage()
    ];
}

// Cleanup
@unlink($testPath);

// Add version info
$results['version'] = function_exists('vips_version') ? vips_version() : 'unknown';
$results['available'] = true;

echo json_encode($results, JSON_PRETTY_PRINT);
