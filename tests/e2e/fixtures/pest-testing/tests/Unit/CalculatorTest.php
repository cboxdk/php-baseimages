<?php

use App\Calculator;

beforeEach(function () {
    $this->calculator = new Calculator();
});

describe('Calculator', function () {
    describe('add', function () {
        it('adds two positive numbers', function () {
            expect($this->calculator->add(2, 3))->toBe(5);
        });

        it('adds negative numbers', function () {
            expect($this->calculator->add(-2, -3))->toBe(-5);
        });

        it('adds zero', function () {
            expect($this->calculator->add(5, 0))->toBe(5);
        });

        it('adds floats', function () {
            expect($this->calculator->add(2.5, 3.5))->toBe(6.0);
        });
    });

    describe('subtract', function () {
        it('subtracts two numbers', function () {
            expect($this->calculator->subtract(10, 4))->toBe(6);
        });

        it('subtracts resulting in negative', function () {
            expect($this->calculator->subtract(3, 10))->toBe(-7);
        });
    });

    describe('multiply', function () {
        it('multiplies two numbers', function () {
            expect($this->calculator->multiply(4, 5))->toBe(20);
        });

        it('multiplies by zero', function () {
            expect($this->calculator->multiply(100, 0))->toBe(0);
        });

        it('multiplies negative numbers', function () {
            expect($this->calculator->multiply(-3, -4))->toBe(12);
        });
    });

    describe('divide', function () {
        it('divides two numbers', function () {
            expect($this->calculator->divide(20, 4))->toBe(5);
        });

        it('divides with float result', function () {
            expect($this->calculator->divide(10, 4))->toBe(2.5);
        });

        it('throws exception on division by zero', function () {
            expect(fn() => $this->calculator->divide(10, 0))
                ->toThrow(InvalidArgumentException::class, 'Division by zero');
        });
    });

    describe('percentage', function () {
        it('calculates percentage', function () {
            expect($this->calculator->percentage(200, 15))->toBe(30.0);
        });

        it('calculates 100%', function () {
            expect($this->calculator->percentage(50, 100))->toBe(50.0);
        });
    });
});

// Additional Pest-specific features
test('can use dataset for multiple inputs', function (int $a, int $b, int $expected) {
    expect((new Calculator())->add($a, $b))->toBe($expected);
})->with([
    [1, 1, 2],
    [5, 5, 10],
    [10, 20, 30],
    [-5, 5, 0],
]);

test('calculator is not null after instantiation')
    ->expect(fn() => new Calculator())
    ->not->toBeNull();
