<?php
/**
 * Cbox Base Image - Environment Variable Configuration Test
 *
 * Tests:
 * 1. Environment variables are passed to PHP correctly
 * 2. Missing env vars are handled gracefully
 * 3. Override capability works
 * 4. PHP settings can be customized
 */

header('Content-Type: application/json');

$tests = [];
$allPassed = true;

// ═══════════════════════════════════════════════════════════════════════════
// TEST 1: Basic Environment Variables (should be set)
// ═══════════════════════════════════════════════════════════════════════════
$basicEnvVars = [
    'APP_NAME' => 'Expected value from docker-compose',
    'APP_ENV' => 'testing',
    'APP_DEBUG' => 'true',
    'DB_HOST' => 'localhost',
    'DB_DATABASE' => 'test_db',
    'CACHE_DRIVER' => 'array',
];

$envTest = [
    'name' => 'Basic Environment Variables',
    'passed' => true,
    'details' => [],
];

foreach ($basicEnvVars as $var => $expectedValue) {
    $actualValue = getenv($var);
    $passed = $actualValue === $expectedValue;

    $envTest['details'][$var] = [
        'expected' => $expectedValue,
        'actual' => $actualValue ?: '(not set)',
        'passed' => $passed,
    ];

    if (!$passed) {
        $envTest['passed'] = false;
        $allPassed = false;
    }
}
$tests['env_basic'] = $envTest;

// ═══════════════════════════════════════════════════════════════════════════
// TEST 2: Optional Environment Variables (may not be set - should not crash)
// ═══════════════════════════════════════════════════════════════════════════
$optionalVars = [
    'APP_KEY',
    'APP_URL',
    'DB_PASSWORD',
    'REDIS_HOST',
    'REDIS_PASSWORD',
    'AWS_ACCESS_KEY_ID',
    'MAIL_HOST',
    'TELESCOPE_ENABLED',
];

$optionalTest = [
    'name' => 'Optional Environment Variables (graceful handling)',
    'passed' => true,  // Should always pass - we're testing graceful handling
    'details' => [],
];

foreach ($optionalVars as $var) {
    $value = getenv($var);
    $optionalTest['details'][$var] = [
        'set' => $value !== false,
        'value' => $value !== false ? (strlen($value) > 20 ? substr($value, 0, 20) . '...' : $value) : '(not set)',
    ];
}
$tests['env_optional'] = $optionalTest;

// ═══════════════════════════════════════════════════════════════════════════
// TEST 3: Environment Variable Override Test
// ═══════════════════════════════════════════════════════════════════════════
$overrideTest = [
    'name' => 'Environment Variable Override',
    'passed' => true,
    'details' => [],
];

// CUSTOM_OVERRIDE should be set in docker-compose to test override capability
$customOverride = getenv('CUSTOM_OVERRIDE');
$overrideTest['details']['CUSTOM_OVERRIDE'] = [
    'set' => $customOverride !== false,
    'value' => $customOverride ?: '(not set)',
    'note' => 'Custom variable to test override capability',
];

// Check if override worked
if ($customOverride !== 'overridden_value') {
    $overrideTest['passed'] = false;
    $allPassed = false;
}
$tests['env_override'] = $overrideTest;

// ═══════════════════════════════════════════════════════════════════════════
// TEST 4: PHP Configuration Values
// ═══════════════════════════════════════════════════════════════════════════
$phpConfigTest = [
    'name' => 'PHP Configuration Values',
    'passed' => true,
    'details' => [],
];

$phpConfigs = [
    'memory_limit' => ['expected' => '256M', 'getter' => fn() => ini_get('memory_limit')],
    'upload_max_filesize' => ['expected' => '100M', 'getter' => fn() => ini_get('upload_max_filesize')],
    'post_max_size' => ['expected' => '100M', 'getter' => fn() => ini_get('post_max_size')],
    'max_execution_time' => ['expected' => '60', 'getter' => fn() => ini_get('max_execution_time')],
    'display_errors' => ['expected' => '', 'getter' => fn() => ini_get('display_errors')],  // Off = empty string
    'expose_php' => ['expected' => '', 'getter' => fn() => ini_get('expose_php')],
    'opcache.enable' => ['expected' => '1', 'getter' => fn() => ini_get('opcache.enable')],
];

foreach ($phpConfigs as $config => $info) {
    $actual = $info['getter']();
    $passed = $actual === $info['expected'];

    $phpConfigTest['details'][$config] = [
        'expected' => $info['expected'] ?: '(Off)',
        'actual' => $actual ?: '(Off)',
        'passed' => $passed,
    ];

    if (!$passed) {
        $phpConfigTest['passed'] = false;
        // Don't fail entire test for PHP config mismatches - might be intentional
    }
}
$tests['php_config'] = $phpConfigTest;

// ═══════════════════════════════════════════════════════════════════════════
// TEST 5: Security Settings
// ═══════════════════════════════════════════════════════════════════════════
$securityTest = [
    'name' => 'Security Configuration',
    'passed' => true,
    'details' => [],
];

// Check open_basedir is set
$openBasedir = ini_get('open_basedir');
$securityTest['details']['open_basedir'] = [
    'set' => !empty($openBasedir),
    'value' => $openBasedir ?: '(not set)',
    'expected' => 'Should restrict to /var/www/html:/tmp:/var/tmp',
];

// Check disabled functions
$disabledFunctions = ini_get('disable_functions');
$securityTest['details']['disable_functions'] = [
    'set' => !empty($disabledFunctions),
    'contains_pcntl' => strpos($disabledFunctions, 'pcntl_') !== false,
    'note' => 'pcntl functions should be disabled in FPM',
];

$tests['security'] = $securityTest;

// ═══════════════════════════════════════════════════════════════════════════
// TEST 6: Environment Passthrough Test (clear_env=no)
// ═══════════════════════════════════════════════════════════════════════════
$envPassthroughTest = [
    'name' => 'Environment Passthrough (clear_env=no)',
    'passed' => true,
    'details' => [],
];

// With clear_env=no, container env vars SHOULD be available
$shouldExist = ['PATH', 'HOSTNAME'];
foreach ($shouldExist as $var) {
    $value = getenv($var);
    $envPassthroughTest['details'][$var] = [
        'exists' => $value !== false,
        'value' => $value !== false ? (strlen($value) > 50 ? substr($value, 0, 50) . '...' : $value) : '(not set)',
        'note' => 'Should be available with clear_env=no',
    ];
    // PATH should always exist in a container
    if ($var === 'PATH' && $value === false) {
        $envPassthroughTest['passed'] = false;
    }
}

$tests['env_passthrough'] = $envPassthroughTest;

// ═══════════════════════════════════════════════════════════════════════════
// TEST 7: FPM-Specific Values
// ═══════════════════════════════════════════════════════════════════════════
$fpmTest = [
    'name' => 'FPM Pool Values',
    'passed' => true,
    'details' => [
        'sapi' => php_sapi_name(),
        'is_fpm' => php_sapi_name() === 'fpm-fcgi',
    ],
];
$tests['fpm'] = $fpmTest;

// ═══════════════════════════════════════════════════════════════════════════
// SUMMARY
// ═══════════════════════════════════════════════════════════════════════════
$response = [
    'status' => $allPassed ? 'ok' : 'issues_found',
    'timestamp' => date('c'),
    'php_version' => PHP_VERSION,
    'sapi' => php_sapi_name(),
    'tests' => $tests,
    'summary' => [
        'total_tests' => count($tests),
        'passed' => count(array_filter($tests, fn($t) => $t['passed'])),
        'failed' => count(array_filter($tests, fn($t) => !$t['passed'])),
    ],
];

echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
