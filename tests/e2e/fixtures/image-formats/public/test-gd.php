<?php
/**
 * GD Image Creation Tests
 * Tests creating images in various formats using GD library
 */

header('Content-Type: application/json');

$results = [
    'library' => 'GD',
    'tests' => [],
];

$tempDir = '/tmp/gd-tests';
if (!is_dir($tempDir)) {
    mkdir($tempDir, 0755, true);
}

// Create a test image (100x100 with gradient)
$img = imagecreatetruecolor(100, 100);
$white = imagecolorallocate($img, 255, 255, 255);
$blue = imagecolorallocate($img, 0, 100, 200);
imagefill($img, 0, 0, $white);
imagefilledrectangle($img, 10, 10, 90, 90, $blue);
imagestring($img, 5, 20, 40, 'TEST', $white);

// Test JPEG
$jpegPath = "$tempDir/test.jpg";
$jpegResult = @imagejpeg($img, $jpegPath, 85);
$results['tests']['jpeg'] = [
    'success' => $jpegResult && file_exists($jpegPath),
    'size' => $jpegResult ? filesize($jpegPath) : 0,
    'function' => 'imagejpeg()',
];

// Test PNG
$pngPath = "$tempDir/test.png";
$pngResult = @imagepng($img, $pngPath, 6);
$results['tests']['png'] = [
    'success' => $pngResult && file_exists($pngPath),
    'size' => $pngResult ? filesize($pngPath) : 0,
    'function' => 'imagepng()',
];

// Test GIF
$gifPath = "$tempDir/test.gif";
$gifResult = @imagegif($img, $gifPath);
$results['tests']['gif'] = [
    'success' => $gifResult && file_exists($gifPath),
    'size' => $gifResult ? filesize($gifPath) : 0,
    'function' => 'imagegif()',
];

// Test WebP
$webpPath = "$tempDir/test.webp";
if (function_exists('imagewebp')) {
    $webpResult = @imagewebp($img, $webpPath, 85);
    $results['tests']['webp'] = [
        'success' => $webpResult && file_exists($webpPath),
        'size' => $webpResult ? filesize($webpPath) : 0,
        'function' => 'imagewebp()',
    ];
} else {
    $results['tests']['webp'] = [
        'success' => false,
        'error' => 'imagewebp() function not available',
    ];
}

// Test AVIF (PHP 8.1+)
$avifPath = "$tempDir/test.avif";
if (function_exists('imageavif')) {
    $avifResult = @imageavif($img, $avifPath, 85);
    $results['tests']['avif'] = [
        'success' => $avifResult && file_exists($avifPath),
        'size' => $avifResult ? filesize($avifPath) : 0,
        'function' => 'imageavif()',
    ];
} else {
    $results['tests']['avif'] = [
        'success' => false,
        'error' => 'imageavif() function not available (requires PHP 8.1+ with libavif)',
    ];
}

// Cleanup
imagedestroy($img);
array_map('unlink', glob("$tempDir/*"));
rmdir($tempDir);

echo json_encode($results, JSON_PRETTY_PRINT);
