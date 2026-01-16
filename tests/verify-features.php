<?php
/**
 * Cbox Base Image - Complete Feature Verification
 * Tests all extensions, format support, and tools
 */

echo "╔══════════════════════════════════════════════════════════════╗\n";
echo "║     Cbox Base Image - Complete Feature Verification        ║\n";
echo "╚══════════════════════════════════════════════════════════════╝\n\n";

$passed = 0;
$failed = 0;

function test($condition, $success, $failure) {
    global $passed, $failed;
    if ($condition) {
        echo "  ✓ $success\n";
        $passed++;
        return true;
    } else {
        echo "  ✗ $failure\n";
        $failed++;
        return false;
    }
}

// === 1. PHP Extensions ===
echo "═══ 1. PHP EXTENSIONS ═══\n";
$required = ["redis", "imagick", "apcu", "mongodb", "vips", "gd", "intl", "pdo_mysql", "pdo_pgsql", "bcmath", "zip", "opcache", "pcntl", "sockets", "exif", "soap", "ldap", "bz2", "gmp"];
foreach ($required as $ext) {
    test(extension_loaded($ext), $ext, "$ext MISSING!");
}

// === 2. GD Format Support ===
echo "\n═══ 2. GD FORMAT SUPPORT ═══\n";
$gd = gd_info();
$gdFormats = [
    "JPEG Support" => "JPEG",
    "PNG Support" => "PNG",
    "GIF Read Support" => "GIF",
    "WebP Support" => "WebP",
    "AVIF Support" => "AVIF",
    "FreeType Support" => "FreeType"
];
foreach ($gdFormats as $key => $name) {
    test(isset($gd[$key]) && $gd[$key], "GD: $name", "GD: $name MISSING!");
}

// === 3. ImageMagick Format Support ===
echo "\n═══ 3. IMAGEMAGICK FORMAT SUPPORT ═══\n";
$imFormats = Imagick::queryFormats();
$checkFormats = ["JPEG", "PNG", "GIF", "WEBP", "AVIF", "HEIC", "HEIF", "PDF", "SVG"];
foreach ($checkFormats as $fmt) {
    test(in_array($fmt, $imFormats), "ImageMagick: $fmt", "ImageMagick: $fmt MISSING!");
}

// === 4. ImageMagick Operations ===
echo "\n═══ 4. IMAGEMAGICK OPERATIONS ═══\n";

// PDF Write
try {
    $pdf = new Imagick();
    $pdf->newImage(100, 100, new ImagickPixel("green"));
    $pdf->setImageFormat("pdf");
    $pdf->writeImage("/tmp/test.pdf");
    $size = filesize("/tmp/test.pdf");
    test($size > 0, "PDF Write ($size bytes)", "PDF Write - empty file");
} catch (Exception $e) {
    test(false, "", "PDF Write FAILED: " . $e->getMessage());
}

// SVG Read
try {
    file_put_contents("/tmp/test.svg", '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect fill="blue" width="100" height="100"/></svg>');
    $svg = new Imagick("/tmp/test.svg");
    $w = $svg->getImageWidth();
    $h = $svg->getImageHeight();
    test($w > 0 && $h > 0, "SVG Read ({$w}x{$h})", "SVG Read - invalid dimensions");
} catch (Exception $e) {
    test(false, "", "SVG Read FAILED: " . $e->getMessage());
}

// === 5. libvips ===
echo "\n═══ 5. LIBVIPS EXTENSION ═══\n";
if (test(extension_loaded("vips"), "vips extension loaded", "vips extension NOT loaded")) {
    try {
        $image = vips_image_new_from_array([[255, 0, 0], [0, 255, 0], [0, 0, 255]]);
        test($image !== false, "vips_image_new_from_array works", "vips operation returned false");
    } catch (Exception $e) {
        test(false, "", "vips operation failed: " . $e->getMessage());
    }
}

// === 6. Node.js & npm ===
echo "\n═══ 6. NODE.JS & NPM ═══\n";
$nodeVersion = trim(shell_exec("node --version 2>&1") ?? "");
$npmVersion = trim(shell_exec("npm --version 2>&1") ?? "");
test(strpos($nodeVersion, "v") === 0, "Node.js: $nodeVersion", "Node.js NOT working");
test(preg_match("/^\d+\.\d+/", $npmVersion), "npm: $npmVersion", "npm NOT working");

// === 7. Composer ===
echo "\n═══ 7. COMPOSER ═══\n";
$composerVersion = trim(shell_exec("composer --version 2>&1") ?? "");
test(strpos($composerVersion, "Composer") !== false, substr($composerVersion, 0, 50), "Composer NOT working");

// === 8. Cbox PM ===
echo "\n═══ 8. PHPEEK PM ═══\n";
$pmVersion = trim(shell_exec("/usr/local/bin/cbox-pm --version 2>&1") ?? "");
test(strpos($pmVersion, "cbox-pm") !== false || preg_match("/\d+\.\d+/", $pmVersion), "Cbox PM: $pmVersion", "Cbox PM NOT working: $pmVersion");

// === 9. Chromium (for Browsershot) ===
echo "\n═══ 9. CHROMIUM (BROWSERSHOT) ═══\n";
$chromium = trim(shell_exec("chromium-browser --version 2>&1 || chromium --version 2>&1") ?? "");
test(strpos($chromium, "Chromium") !== false, $chromium, "Chromium NOT installed");

// === 10. Exiftool ===
echo "\n═══ 10. EXIFTOOL ═══\n";
$exif = trim(shell_exec("exiftool -ver 2>&1") ?? "");
test(preg_match("/^\d+\.\d+/", $exif), "exiftool: v$exif", "exiftool NOT working");

// === Summary ===
$total = $passed + $failed;
echo "\n╔══════════════════════════════════════════════════════════════╗\n";
printf("║  SUMMARY: %d/%d passed (%d failed)                            ║\n", $passed, $total, $failed);
echo "╚══════════════════════════════════════════════════════════════╝\n";

exit($failed > 0 ? 1 : 0);
