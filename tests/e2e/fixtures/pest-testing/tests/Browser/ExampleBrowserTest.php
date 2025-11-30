<?php

/**
 * Pest v4 Browser Testing
 *
 * These tests demonstrate Pest v4's native browser testing capabilities
 * powered by Playwright. No Dusk required!
 *
 * @see https://pestphp.com/docs/browser-testing
 */

use function Pest\Browser\visit;

describe('Browser Testing with Pest v4', function () {
    it('can visit example.com', function () {
        visit('https://example.com')
            ->assertSee('Example Domain')
            ->assertTitle('Example Domain');
    });

    it('can interact with page elements', function () {
        visit('https://example.com')
            ->assertVisible('h1')
            ->assertSee('This domain is for use in illustrative examples');
    });

    it('can check for links', function () {
        visit('https://example.com')
            ->assertLinkExists('More information...');
    });
});

describe('Visual Regression Testing', function () {
    it('takes screenshot for visual comparison', function () {
        visit('https://example.com')
            ->screenshot('example-homepage');
    });
})->skip(fn () => !function_exists('Pest\Browser\visit'), 'Browser plugin not installed');

describe('Device Emulation', function () {
    it('can test on mobile viewport', function () {
        visit('https://example.com')
            ->resize(375, 667) // iPhone SE
            ->assertSee('Example Domain');
    });

    it('can test on tablet viewport', function () {
        visit('https://example.com')
            ->resize(768, 1024) // iPad
            ->assertSee('Example Domain');
    });
})->skip(fn () => !function_exists('Pest\Browser\visit'), 'Browser plugin not installed');
