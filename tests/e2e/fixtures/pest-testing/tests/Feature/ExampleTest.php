<?php

test('example feature test', function () {
    expect(true)->toBeTrue();
});

test('php version is 8.2 or higher', function () {
    expect(PHP_VERSION_ID)->toBeGreaterThanOrEqual(80200);
});

test('required extensions are loaded', function (string $extension) {
    expect(extension_loaded($extension))->toBeTrue();
})->with([
    'pdo',
    'pdo_mysql',
    'pdo_pgsql',
    'pdo_sqlite',
    'mbstring',
    'openssl',
    'curl',
    'gd',
    'imagick',
    'redis',
    'xml',
    'bcmath',
]);

test('memory limit is adequate', function () {
    $memoryLimit = ini_get('memory_limit');
    $bytes = convertToBytes($memoryLimit);
    // At least 128MB
    expect($bytes)->toBeGreaterThanOrEqual(128 * 1024 * 1024);
});

function convertToBytes(string $memoryLimit): int
{
    $memoryLimit = trim($memoryLimit);
    $last = strtolower($memoryLimit[strlen($memoryLimit) - 1]);
    $memoryLimit = (int) $memoryLimit;

    switch ($last) {
        case 'g':
            $memoryLimit *= 1024;
            // no break
        case 'm':
            $memoryLimit *= 1024;
            // no break
        case 'k':
            $memoryLimit *= 1024;
    }

    return $memoryLimit;
}

test('max execution time is reasonable for web')
    ->expect(fn() => (int) ini_get('max_execution_time'))
    ->toBeLessThanOrEqual(120);

test('upload_max_filesize is configured', function () {
    $uploadMax = ini_get('upload_max_filesize');
    expect($uploadMax)->not->toBeEmpty();
    $bytes = convertToBytes($uploadMax);
    // At least 2MB
    expect($bytes)->toBeGreaterThanOrEqual(2 * 1024 * 1024);
});

describe('JSON operations', function () {
    it('can encode and decode JSON', function () {
        $data = ['key' => 'value', 'number' => 123];
        $json = json_encode($data);
        $decoded = json_decode($json, true);

        expect($decoded)->toBe($data);
    });

    it('handles UTF-8 in JSON', function () {
        $data = ['message' => 'Héllo Wörld 日本語'];
        $json = json_encode($data);
        $decoded = json_decode($json, true);

        expect($decoded['message'])->toBe('Héllo Wörld 日本語');
    });
});
