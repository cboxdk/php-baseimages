<?php

/**
 * Pest v4 Architecture Testing
 *
 * Architectural rules to enforce code quality and consistency.
 *
 * @see https://pestphp.com/docs/arch-testing
 */

arch('app classes should be final')
    ->expect('App')
    ->classes()
    ->toBeFinal();

arch('app classes should not have suffix')
    ->expect('App')
    ->not->toHaveSuffix('Class');

arch('no debugging statements')
    ->expect(['dd', 'dump', 'var_dump', 'print_r', 'ray'])
    ->not->toBeUsed();

arch('strict types in all app files')
    ->expect('App')
    ->toUseStrictTypes();

arch('interfaces should have Interface suffix')
    ->expect('App')
    ->interfaces()
    ->toHaveSuffix('Interface');

arch('enums should be backed')
    ->expect('App')
    ->enums()
    ->toBeStringBackedEnums()
    ->or()
    ->toBeIntBackedEnums();

// Dependency rules
arch('app should not depend on tests')
    ->expect('App')
    ->not->toUse('Tests');

// Value object immutability
arch('value objects should be readonly')
    ->expect('App\ValueObjects')
    ->classes()
    ->toBeReadonly();
