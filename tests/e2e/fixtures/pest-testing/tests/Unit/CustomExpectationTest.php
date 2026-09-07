<?php

declare(strict_types=1);

// Exercises the custom expectation defined in tests/Pest.php; the e2e
// scenario targets this via --filter='custom expectation'.
it('custom expectation toBeOne works', function () {
    expect(1)->toBeOne();
});
