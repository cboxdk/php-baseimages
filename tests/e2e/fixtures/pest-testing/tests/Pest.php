<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Pest v4 Configuration
|--------------------------------------------------------------------------
|
| Cbox Base Images E2E Test Suite using Pest v4 with native browser testing.
| Features: Playwright-powered browser tests, architecture testing, parallel execution.
|
| @see https://pestphp.com/docs
|
*/

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
*/

// pest()->extend(Tests\TestCase::class)->in('Feature');

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
*/

expect()->extend('toBeOne', function () {
    return $this->toBe(1);
});

expect()->extend('toBeValidPhpVersion', function () {
    return $this->toMatch('/^\d+\.\d+\.\d+/');
});

expect()->extend('toBeLoadedExtension', function () {
    return $this->toBeTrue();
});

/*
|--------------------------------------------------------------------------
| Functions
|--------------------------------------------------------------------------
*/

function something(): void
{
    // Helper function placeholder
}

/*
|--------------------------------------------------------------------------
| Architecture Presets
|--------------------------------------------------------------------------
|
| Pest v4 architecture testing presets for enforcing code quality.
|
*/

// arch()->preset()->php();
// arch()->preset()->security();
