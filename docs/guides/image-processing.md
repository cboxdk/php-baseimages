---
title: "Image Processing Guide"
description: "Complete guide to image manipulation with GD, ImageMagick, libvips, and Browsershot in Cbox"
weight: 50
---

# Image Processing Guide

Cbox images include three powerful image processing libraries plus Browsershot support for PDF generation.

## Quick Start

```php
// GD - Simple operations
$img = imagecreatefrompng('input.png');
imagejpeg($img, 'output.jpg', 90);

// ImageMagick - Advanced operations
$im = new Imagick('input.heic');
$im->setImageFormat('jpeg');
$im->writeImage('output.jpg');

// libvips - High-performance
$image = vips_image_new_from_file('input.jpg');
vips_image_write_to_file($image, 'output.webp');
```

## Library Comparison

| Feature | GD | ImageMagick | libvips |
|---------|:--:|:-----------:|:-------:|
| Memory usage | Medium | High | **Low** |
| Speed | Medium | Medium | **Fast** |
| HEIC/HEIF | - | ✓ | ✓ |
| PDF read/write | - | ✓ | - |
| SVG support | - | ✓ | ✓ |
| Color profiles | - | ✓ | ✓ |
| Streaming | - | - | ✓ |
| Laravel Integration | intervention/image | intervention/image | - |

**Recommendation**:
- **GD**: Simple thumbnails, basic operations
- **ImageMagick**: Complex manipulations, format conversions, PDF
- **libvips**: High-volume processing, memory-constrained environments

---

## GD Library

Best for simple operations with good Laravel/Intervention support.

### Basic Operations

```php
// Create thumbnail
$src = imagecreatefromjpeg('photo.jpg');
$thumb = imagescale($src, 300, 200);
imagejpeg($thumb, 'thumbnail.jpg', 85);
imagedestroy($src);
imagedestroy($thumb);

// Convert formats
$png = imagecreatefrompng('input.png');
imagewebp($png, 'output.webp', 80);
imagedestroy($png);

// Add watermark
$photo = imagecreatefromjpeg('photo.jpg');
$watermark = imagecreatefrompng('watermark.png');
imagecopy($photo, $watermark, 10, 10, 0, 0, imagesx($watermark), imagesy($watermark));
imagejpeg($photo, 'watermarked.jpg');
```

### Check GD Capabilities

```php
$info = gd_info();
echo "GD Version: " . $info['GD Version'] . "\n";
echo "JPEG: " . ($info['JPEG Support'] ? 'Yes' : 'No') . "\n";
echo "PNG: " . ($info['PNG Support'] ? 'Yes' : 'No') . "\n";
echo "WebP: " . ($info['WebP Support'] ? 'Yes' : 'No') . "\n";
echo "AVIF: " . ($info['AVIF Support'] ? 'Yes' : 'No') . "\n";
```

---

## ImageMagick (Imagick)

Best for complex operations, format conversions, and PDF handling.

### Basic Operations

```php
// Resize with aspect ratio
$im = new Imagick('photo.jpg');
$im->thumbnailImage(800, 0); // Width 800, auto height
$im->writeImage('resized.jpg');

// Convert to WebP
$im = new Imagick('photo.jpg');
$im->setImageFormat('webp');
$im->setImageCompressionQuality(80);
$im->writeImage('output.webp');

// Strip metadata (privacy)
$im = new Imagick('photo.jpg');
$im->stripImage();
$im->writeImage('stripped.jpg');
```

### HEIC/HEIF Conversion (iPhone Photos)

```php
// Convert iPhone HEIC to JPEG
$im = new Imagick('IMG_1234.HEIC');
$im->setImageFormat('jpeg');
$im->setImageCompressionQuality(90);
$im->writeImage('photo.jpg');

// Batch convert all HEIC files
foreach (glob('*.HEIC') as $heic) {
    $im = new Imagick($heic);
    $im->setImageFormat('jpeg');
    $im->writeImage(str_replace('.HEIC', '.jpg', $heic));
    $im->clear();
}
```

### PDF Operations

```php
// Generate PDF from image
$im = new Imagick('document.jpg');
$im->setImageFormat('pdf');
$im->writeImage('document.pdf');

// Read PDF page as image
$im = new Imagick();
$im->setResolution(150, 150); // Set BEFORE reading
$im->readImage('document.pdf[0]'); // First page
$im->setImageFormat('png');
$im->writeImage('page1.png');

// Multi-page PDF to images
$im = new Imagick();
$im->setResolution(150, 150);
$im->readImage('document.pdf');
foreach ($im as $i => $page) {
    $page->setImageFormat('png');
    $page->writeImage("page_{$i}.png");
}
```

### SVG Rendering

```php
// SVG to PNG (read-only for security)
$im = new Imagick();
$im->setBackgroundColor(new ImagickPixel('transparent'));
$im->readImage('icon.svg');
$im->setImageFormat('png');
$im->writeImage('icon.png');

// SVG at specific size
$im = new Imagick();
$im->setResolution(300, 300);
$im->readImage('icon.svg');
$im->resizeImage(512, 512, Imagick::FILTER_LANCZOS, 1);
$im->writeImage('icon-512.png');
```

### Check ImageMagick Capabilities

```php
// List supported formats
$formats = Imagick::queryFormats();
echo "Supported formats: " . count($formats) . "\n";

// Check specific format
$hasHeic = in_array('HEIC', $formats);
$hasPdf = in_array('PDF', $formats);
$hasSvg = in_array('SVG', $formats);

echo "HEIC: " . ($hasHeic ? 'Yes' : 'No') . "\n";
echo "PDF: " . ($hasPdf ? 'Yes' : 'No') . "\n";
echo "SVG: " . ($hasSvg ? 'Yes' : 'No') . "\n";
```

---

## libvips

Best for high-performance, memory-efficient processing.

### Basic Operations

```php
use Jcupitt\Vips\Image;

// Simple resize / thumbnail
$thumb = Image::thumbnail('input.jpg', 300);
$thumb->writeToFile('output.jpg');

// Convert format
$image = Image::newFromFile('input.png');
$image->writeToFile('output.webp', ['Q' => 80]);

// Crop
$image = Image::newFromFile('input.jpg');
$cropped = $image->crop(100, 100, 500, 500);
$cropped->writeToFile('cropped.jpg');
```

### Memory-Efficient Processing

```php
use Jcupitt\Vips\Image;

// Process large image without loading entirely into memory
$image = Image::newFromFile('huge-image.tiff', [
    'access' => 'sequential', // Stream processing
]);

// Apply operations
$processed = $image->resize(0.5);
$processed->writeToFile('output.jpg', ['Q' => 85]);
```

### Check libvips Capabilities

```php
use Jcupitt\Vips\Image;

if (extension_loaded('vips')) {
    echo 'libvips version: ' . phpversion('vips') . "\n";

    // Test operation
    $test = Image::newFromArray([[255, 0], [0, 255]]);
    echo 'libvips working: ' . ($test instanceof Image ? 'Yes' : 'No') . "\n";
}
```

---

## Browsershot (PDF Generation)

Cbox includes Chromium for Browsershot PDF/screenshot generation.

### Installation

```bash
composer require spatie/browsershot
```

### Generate PDF from HTML

```php
use Spatie\Browsershot\Browsershot;

// Simple PDF
Browsershot::html('<h1>Hello World</h1>')
    ->save('document.pdf');

// From URL
Browsershot::url('https://example.com')
    ->save('page.pdf');

// With options
Browsershot::html($html)
    ->format('A4')
    ->margins(20, 20, 20, 20)
    ->showBackground()
    ->save('styled.pdf');
```

### Generate Screenshots

```php
use Spatie\Browsershot\Browsershot;

// Full page screenshot
Browsershot::url('https://example.com')
    ->fullPage()
    ->save('screenshot.png');

// Specific viewport
Browsershot::url('https://example.com')
    ->windowSize(1920, 1080)
    ->save('desktop.png');

// Mobile viewport
Browsershot::url('https://example.com')
    ->windowSize(375, 812)
    ->device('iPhone X')
    ->save('mobile.png');
```

### Browsershot Configuration

Cbox sets these environment variables automatically:

```bash
PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

If needed manually:

```php
Browsershot::html($html)
    ->setChromePath('/usr/bin/chromium-browser')
    ->noSandbox()
    ->save('output.pdf');
```

---

## Laravel Integration

### Intervention Image (GD/ImageMagick)

```bash
composer require intervention/image
```

```php
use Intervention\Image\ImageManager;
use Intervention\Image\Drivers\Gd\Driver as GdDriver;
use Intervention\Image\Drivers\Imagick\Driver as ImagickDriver;

// Using GD
$manager = new ImageManager(new GdDriver());
$image = $manager->read('photo.jpg');
$image->scale(width: 300);
$image->save('thumbnail.jpg');

// Using ImageMagick (for HEIC, PDF, etc.)
$manager = new ImageManager(new ImagickDriver());
$image = $manager->read('photo.HEIC');
$image->toJpeg(90)->save('photo.jpg');
```

### Spatie Media Library

```bash
composer require spatie/laravel-medialibrary
```

```php
// Model setup
class Post extends Model implements HasMedia
{
    use InteractsWithMedia;

    public function registerMediaConversions(Media $media = null): void
    {
        $this->addMediaConversion('thumb')
            ->width(300)
            ->height(200);

        $this->addMediaConversion('webp')
            ->format('webp')
            ->quality(80);
    }
}

// Usage
$post->addMedia($request->file('image'))->toMediaCollection();
```

---

## Common Tasks

### Optimize Images for Web

```php
// ImageMagick optimization
$im = new Imagick('photo.jpg');
$im->setImageCompressionQuality(85);
$im->stripImage();  // Remove metadata
$im->gaussianBlurImage(0.05, 0.5);  // Slight blur helps compression
$im->writeImage('optimized.jpg');

// Convert to modern formats
$im->setImageFormat('webp');
$im->writeImage('photo.webp');

$im->setImageFormat('avif');
$im->writeImage('photo.avif');
```

### Generate Responsive Images

```php
$sizes = [320, 640, 1024, 1920];
$im = new Imagick('original.jpg');
$originalWidth = $im->getImageWidth();

foreach ($sizes as $width) {
    if ($width < $originalWidth) {
        $resized = clone $im;
        $resized->thumbnailImage($width, 0);
        $resized->writeImage("image-{$width}w.jpg");
    }
}
```

### Extract Image Metadata

```php
// Using PHP EXIF
$exif = exif_read_data('photo.jpg');
echo "Camera: " . ($exif['Make'] ?? 'Unknown') . "\n";
echo "Date: " . ($exif['DateTimeOriginal'] ?? 'Unknown') . "\n";

// Using exiftool (command line)
$output = shell_exec('exiftool -json photo.jpg');
$metadata = json_decode($output, true)[0];
```

---

## Troubleshooting

### HEIC Not Working

```php
// Check HEIC support
$formats = Imagick::queryFormats('HEIC');
if (empty($formats)) {
    echo "HEIC not supported - libheif may be missing\n";
}

// Verify in container
// docker exec myapp php -r "print_r(Imagick::queryFormats('HEI*'));"
```

### PDF Operations Fail

```php
// Check Ghostscript
$gs = shell_exec('gs --version 2>&1');
echo "Ghostscript: " . ($gs ?: 'NOT INSTALLED') . "\n";

// Check ImageMagick policy
// docker exec myapp cat /etc/ImageMagick-7/policy.xml | grep PDF
```

### Memory Issues with Large Images

```php
// Increase memory limit
ini_set('memory_limit', '512M');

// Use libvips for large images (streams, doesn't load full image)
$image = vips_image_new_from_file('huge.tiff', ['access' => 'sequential']);

// Or process in chunks with ImageMagick
$im = new Imagick();
$im->setResourceLimit(Imagick::RESOURCETYPE_MEMORY, 256 * 1024 * 1024);
```

### Check What's Installed

```bash
# In container
docker exec myapp php -m | grep -E "gd|imagick|vips"
docker exec myapp php -r "print_r(gd_info());"
docker exec myapp php -r "print_r(Imagick::queryFormats());"
docker exec myapp chromium-browser --version
docker exec myapp exiftool -ver
docker exec myapp gs --version
```

---

**Related Guides**: [Available Extensions](../reference/available-extensions.md) | [Laravel Guide](laravel-guide.md) | [Performance Tuning](../advanced/performance-tuning.md)
