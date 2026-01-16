<?php
/**
 * Cbox Browsershot/Puppeteer E2E Test
 * Tests Node.js, npm, Chromium and PDF generation capability
 */

header('Content-Type: application/json');

$results = [
    'status' => 'ok',
    'php_version' => PHP_VERSION,
    'node' => [],
    'npm' => [],
    'chromium' => [],
    'pdf_test' => [],
];

// Test Node.js
$nodeVersion = trim(shell_exec('node --version 2>&1') ?? '');
$results['node'] = [
    'installed' => strpos($nodeVersion, 'v') === 0,
    'version' => $nodeVersion,
    'path' => trim(shell_exec('which node 2>&1') ?? ''),
];

// Test npm
$npmVersion = trim(shell_exec('npm --version 2>&1') ?? '');
$results['npm'] = [
    'installed' => (bool) preg_match('/^\d+\.\d+\.\d+/', $npmVersion),
    'version' => $npmVersion,
    'path' => trim(shell_exec('which npm 2>&1') ?? ''),
];

// Test npx
$npxVersion = trim(shell_exec('npx --version 2>&1') ?? '');
$results['npx'] = [
    'installed' => (bool) preg_match('/^\d+\.\d+\.\d+/', $npxVersion),
    'version' => $npxVersion,
    'path' => trim(shell_exec('which npx 2>&1') ?? ''),
];

// Test Chromium
$chromiumPath = getenv('PUPPETEER_EXECUTABLE_PATH') ?: '/usr/bin/chromium-browser';
$chromiumVersion = trim(shell_exec("$chromiumPath --version 2>&1") ?? '');
$results['chromium'] = [
    'installed' => strpos($chromiumVersion, 'Chromium') !== false || strpos($chromiumVersion, 'chromium') !== false,
    'version' => $chromiumVersion,
    'path' => $chromiumPath,
    'puppeteer_skip_download' => getenv('PUPPETEER_SKIP_CHROMIUM_DOWNLOAD') === 'true',
];

// Test Puppeteer PDF generation (minimal test without installing packages)
$storageDir = '/var/www/html/storage';
$pdfTestFile = $storageDir . '/test.pdf';

// Create a simple test using Node.js directly with Puppeteer core
$puppeteerTestScript = <<<'JS'
const puppeteer = require('puppeteer-core');

(async () => {
    const browser = await puppeteer.launch({
        executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium-browser',
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
        ]
    });

    const page = await browser.newPage();
    await page.setContent('<h1>Cbox PDF Test</h1><p>Generated at: ' + new Date().toISOString() + '</p>');
    await page.pdf({ path: process.argv[2], format: 'A4' });
    await browser.close();

    console.log('PDF generated successfully');
})();
JS;

// Install puppeteer-core if not present, then run test
$nodeModulesDir = $storageDir . '/node_modules';
$packageJsonPath = $storageDir . '/package.json';
$testScriptPath = $storageDir . '/test-pdf.js';

// Create package.json if needed
if (!file_exists($packageJsonPath)) {
    file_put_contents($packageJsonPath, json_encode([
        'name' => 'browsershot-test',
        'private' => true,
        'dependencies' => [
            'puppeteer-core' => '^23.0.0'
        ]
    ], JSON_PRETTY_PRINT));
}

// Write test script
file_put_contents($testScriptPath, $puppeteerTestScript);

// Install dependencies if needed
if (!is_dir($nodeModulesDir)) {
    $installOutput = shell_exec("cd $storageDir && npm install --silent 2>&1");
    $results['pdf_test']['npm_install'] = $installOutput;
}

// Run PDF generation test
$pdfOutput = shell_exec("cd $storageDir && node test-pdf.js $pdfTestFile 2>&1");
$pdfGenerated = file_exists($pdfTestFile) && filesize($pdfTestFile) > 0;

$results['pdf_test'] = [
    'success' => $pdfGenerated,
    'output' => trim($pdfOutput ?? ''),
    'file_exists' => file_exists($pdfTestFile),
    'file_size' => file_exists($pdfTestFile) ? filesize($pdfTestFile) : 0,
];

// Clean up
if (file_exists($pdfTestFile)) {
    unlink($pdfTestFile);
}

// Overall status
$results['status'] = (
    $results['node']['installed'] &&
    $results['npm']['installed'] &&
    $results['chromium']['installed'] &&
    $results['pdf_test']['success']
) ? 'ok' : 'error';

echo json_encode($results, JSON_PRETTY_PRINT);
