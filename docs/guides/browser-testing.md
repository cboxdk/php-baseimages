---
title: "Browser Testing"
description: "Pest v4 browser tests and Laravel Dusk on the chromium tier - zero-download setups for both"
weight: 26
---

# Browser Testing

The chromium tier ships everything both modern browser-testing stacks need,
so `vendor/bin/pest` and `php artisan dusk` run without downloading a
browser first. This page gives the working recipe for each and explains the
one version rule you need to know.

Use a `-chromium` (or `-dev`) image - browser testing needs PHP, Node and
the browser in the **same container** (Pest's Playwright server and its test
HTTP server both bind `127.0.0.1`; a browser sidecar cannot reach them).

## Pest v4 browser testing (Playwright)

Pest's browser plugin drives Playwright, and Playwright insists on its own
browser builds - it cannot use the distro Chromium (no executable override
in released plugin versions; watch
[pest-plugin-browser#243](https://github.com/pestphp/pest-plugin-browser/pull/243)).
The image therefore bakes Playwright's Chromium at
`PLAYWRIGHT_BROWSERS_PATH=/ms-playwright`, refreshed to `playwright@latest`
on every weekly rebuild.

```bash
composer require pestphp/pest-plugin-browser --dev
npm install playwright@latest
vendor/bin/pest
```

Expected: tests run immediately - `npx playwright install` is NOT needed,
because the baked browsers already match `playwright@latest` on a current
image.

```php
it('has a welcome page', function () {
    $page = visit('/');

    $page->assertSee('Laravel');
});
```

### The one version rule

Playwright browser builds are revision-locked to the npm package version.
The image bakes the revision matching `playwright@latest` at build time;
the weekly rebuild keeps that current.

❌ **Symptom of version skew** (old image + newer npm playwright):

```text
Error: Executable doesn't exist at /ms-playwright/chromium_headless_shell-.../...
```

✅ **Fix**: `docker pull` the current weekly image, or top the shared dir
up once: `npx playwright install chromium` (it lands in `/ms-playwright`
because the env is already set; add a named volume on that path in CI to
cache it across runs).

### Stability hints (not requirements)

- Playwright always launches Chromium with `--disable-dev-shm-usage`, so a
  small `/dev/shm` will not crash it - but for heavy suites give the
  container `--ipc=host` (or `shm_size: 1gb`) per Playwright's own Docker
  guidance.
- Running as root is fine: Playwright launches with its Chromium sandbox
  off by default (unlike Puppeteer, no `--no-sandbox` juggling).
- cbox-init is PID 1 and reaps the browser process tree - the `--init`
  flag Playwright's docs ask for is already covered.
- Emoji and unicode fonts (`fonts-noto-color-emoji`, `fonts-unifont`,
  `fonts-freefont-ttf`) are in the image, so screenshot assertions render
  glyphs instead of tofu boxes.

## Laravel Dusk (chromedriver)

Debian keeps `chromium` and `chromium-driver` version-matched, and both are
in the image - so Dusk needs no `dusk:chrome-driver` download at all. Two
small changes in `tests/DuskTestCase.php`:

```php
public static function prepare(): void
{
    // Use the image's chromedriver instead of downloading one into vendor/
    static::useChromedriver('/usr/bin/chromedriver');
    static::startChromeDriver();
}

protected function driver(): RemoteWebDriver
{
    $options = (new ChromeOptions)
        ->setBinary('/usr/bin/chromium')   // the image's Chromium
        ->addArguments(['--headless=new', '--disable-gpu', '--window-size=1920,1080']);

    return RemoteWebDriver::create(
        $_ENV['DUSK_DRIVER_URL'] ?? 'http://localhost:9515',
        DesiredCapabilities::chrome()->setCapability(ChromeOptions::CAPABILITY, $options)
    );
}
```

Expected:

```bash
php artisan dusk
# PASS  Tests\Browser\ExampleTest  - no chromedriver download, versions always match
```

Note: Laravel's own docs now recommend Pest browser testing over Dusk for
new projects; both are first-class on this image.

## Browsershot / Puppeteer

Unchanged and still zero-config: `PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium`
and `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true` are baked in. See the
[Image Processing guide](image-processing) for PDF generation examples.

## What is in the chromium tier for this

| Component | Purpose |
|---|---|
| `chromium` (distro) | Browsershot/Puppeteer, Dusk browser |
| `chromium-driver` (distro) | Dusk - apt keeps it version-matched with chromium |
| Playwright Chromium at `/ms-playwright` | Pest v4 browser tests - refreshed weekly to `playwright@latest` |
| `PLAYWRIGHT_BROWSERS_PATH=/ms-playwright` | Any `npx playwright install` lands in the shared dir |
| Node.js 22 + npm | Playwright's runtime |
| Emoji/unicode fonts | Deterministic screenshot assertions |
