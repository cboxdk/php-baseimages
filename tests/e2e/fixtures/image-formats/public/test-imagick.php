<?php
/**
 * ImageMagick Operations Tests
 * Tests various ImageMagick operations and format conversions
 */

header('Content-Type: application/json');

$results = [
    'library' => 'ImageMagick',
    'tests' => [],
];

if (!extension_loaded('imagick')) {
    $results['error'] = 'Imagick extension not loaded';
    echo json_encode($results, JSON_PRETTY_PRINT);
    exit;
}

$tempDir = '/tmp/imagick-tests';
if (!is_dir($tempDir)) {
    mkdir($tempDir, 0755, true);
}

try {
    // Create a test image
    $img = new Imagick();
    $img->newImage(200, 200, new ImagickPixel('white'));
    $img->setImageFormat('png');

    // Draw something on it
    $draw = new ImagickDraw();
    $draw->setFillColor(new ImagickPixel('#0066CC'));
    $draw->rectangle(20, 20, 180, 180);
    $draw->setFillColor(new ImagickPixel('white'));
    $draw->setFontSize(24);
    $draw->annotation(50, 110, 'TEST');
    $img->drawImage($draw);

    // Test resize
    try {
        $resized = clone $img;
        $resized->resizeImage(100, 100, Imagick::FILTER_LANCZOS, 1);
        $resizePath = "$tempDir/resized.png";
        $resized->writeImage($resizePath);
        $results['tests']['resize'] = [
            'success' => file_exists($resizePath),
            'original_size' => '200x200',
            'new_size' => $resized->getImageWidth() . 'x' . $resized->getImageHeight(),
        ];
        $resized->destroy();
    } catch (Exception $e) {
        $results['tests']['resize'] = ['success' => false, 'error' => $e->getMessage()];
    }

    // Test WebP conversion
    try {
        $webp = clone $img;
        $webp->setImageFormat('webp');
        $webpPath = "$tempDir/converted.webp";
        $webp->writeImage($webpPath);
        $results['tests']['convert_webp'] = [
            'success' => file_exists($webpPath),
            'size' => filesize($webpPath),
        ];
        $webp->destroy();
    } catch (Exception $e) {
        $results['tests']['convert_webp'] = ['success' => false, 'error' => $e->getMessage()];
    }

    // Test thumbnail
    try {
        $thumb = clone $img;
        $thumb->thumbnailImage(50, 50, true);
        $thumbPath = "$tempDir/thumb.jpg";
        $thumb->setImageFormat('jpeg');
        $thumb->writeImage($thumbPath);
        $results['tests']['thumbnail'] = [
            'success' => file_exists($thumbPath),
            'size' => $thumb->getImageWidth() . 'x' . $thumb->getImageHeight(),
        ];
        $thumb->destroy();
    } catch (Exception $e) {
        $results['tests']['thumbnail'] = ['success' => false, 'error' => $e->getMessage()];
    }

    // Test AVIF conversion (if supported)
    try {
        if (in_array('AVIF', Imagick::queryFormats())) {
            $avif = clone $img;
            $avif->setImageFormat('avif');
            $avifPath = "$tempDir/converted.avif";
            $avif->writeImage($avifPath);
            $results['tests']['convert_avif'] = [
                'success' => file_exists($avifPath),
                'size' => filesize($avifPath),
            ];
            $avif->destroy();
        } else {
            $results['tests']['convert_avif'] = [
                'success' => false,
                'error' => 'AVIF format not supported by this ImageMagick build',
            ];
        }
    } catch (Exception $e) {
        $results['tests']['convert_avif'] = ['success' => false, 'error' => $e->getMessage()];
    }

    // Test image info extraction
    try {
        $results['tests']['info'] = [
            'success' => true,
            'width' => $img->getImageWidth(),
            'height' => $img->getImageHeight(),
            'format' => $img->getImageFormat(),
            'colorspace' => $img->getImageColorspace(),
        ];
    } catch (Exception $e) {
        $results['tests']['info'] = ['success' => false, 'error' => $e->getMessage()];
    }

    $img->destroy();

} catch (Exception $e) {
    $results['error'] = $e->getMessage();
}

// Cleanup
array_map('unlink', glob("$tempDir/*"));
@rmdir($tempDir);

echo json_encode($results, JSON_PRETTY_PRINT);
