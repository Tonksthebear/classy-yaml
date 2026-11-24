<?php

// Runs the Classy conformance calls (calls.json) with Classy for PHP and compares the results
// with expected.json, which the Ruby gem writes (test/classy/conformance_test.rb).
//   php test/conformance/classy/run.php
// Prints each differing call and exits 1 when any call differs; prints "N calls match" and exits 0
// when all calls match. It writes no file.

declare(strict_types=1);

require __DIR__.'/../../../vendor/autoload.php';

use Tonksthebear\ClassyYaml\Classy;
use Tonksthebear\ClassyYaml\InvalidKeyError;

$dir = __DIR__;
$spec = json_decode(file_get_contents("$dir/calls.json"), true, flags: JSON_THROW_ON_ERROR);
$expected = json_decode(file_get_contents("$dir/expected.json"), true, flags: JSON_THROW_ON_ERROR);
$warnings = 0;

$build = function (array $suite) use ($dir, &$warnings): Classy {
    return new Classy(
        basePath: $dir,
        engineFiles: array_map(fn ($f) => realpath("$dir/$f") ?: "$dir/$f", $suite['engine_files']),
        defaultFile: $suite['default_file'],
        extraFiles: $suite['extra_files'],
        cacheSize: 0,
        warn: function (InvalidKeyError $e) use (&$warnings) { $warnings++; },
    );
};

// classy_files paths in calls are relative to this directory, as the Ruby harness resolves them.
$resolve = function (mixed $value) use (&$resolve, $dir): mixed {
    if (! is_array($value)) {
        return $value;
    }
    $out = [];
    foreach ($value as $key => $child) {
        $out[$key] = $key === 'classy_files' ? array_map(fn ($f) => "$dir/$f", $child) : $resolve($child);
    }

    return $out;
};

// A component's class_names merge, as the Ruby harness does it: with the tag helper override on, a
// hash argument is a yass lookup; then Rails' token_list (strings split on whitespace, hash keys whose
// value is truthy, nested lists, blanks dropped, tokens deduplicated); then one tailwind-merge pass with
// Classy's merger. PHP has no Symbol, so strings stay literal.
function processUserClass(Classy $classy, mixed $value): mixed
{
    if (is_array($value) && $value !== [] && ! array_is_list($value)) {
        return $classy->yass($value);
    }
    if (is_array($value)) {
        return array_map(fn ($item) => processUserClass($classy, $item), $value);
    }

    return $value;
}

/** @return list<string> */
function tokenList(array $args): array
{
    $tokens = [];
    foreach (tagValues($args) as $value) {
        foreach (preg_split('/\s+/', html_entity_decode($value, ENT_QUOTES | ENT_HTML5)) ?: [] as $token) {
            if ($token !== '') {
                $tokens[$token] = true;
            }
        }
    }

    return array_map('strval', array_keys($tokens));
}

/** Rails' build_tag_values. @return list<string> */
function tagValues(array $args): array
{
    $values = [];
    foreach ($args as $arg) {
        if (is_array($arg) && $arg !== [] && ! array_is_list($arg)) {
            foreach ($arg as $key => $value) {
                if ($value && (string) $key !== '') {
                    $values[] = (string) $key;
                }
            }
        } elseif (is_array($arg)) {
            array_push($values, ...tagValues($arg));
        } elseif ($arg instanceof \Stringable || is_scalar($arg)) {
            $string = (string) $arg;
            if (trim($string) !== '' && $arg !== false) {
                $values[] = $string;
            }
        }
    }

    return $values;
}

function mergedClassNames(Classy $classy, bool $overrideTagHelpers, array $args): string
{
    if ($overrideTagHelpers) {
        $args = array_map(fn ($arg) => processUserClass($classy, $arg), $args);
    }

    return $classy->mergeClasses(implode(' ', tokenList($args)));
}

$actual = ['suites' => [], 'class_names' => []];
$classies = [];
foreach ($spec['suites'] as $suiteName => $suite) {
    $classy = $classies[$suiteName] = $build($suite);
    foreach ($suite['calls'] as $call) {
        $warnings = 0;
        $classes = $classy->yass(...$resolve($call['args']));
        $actual['suites'][$suiteName][$call['name']] = ['classes' => $classes, 'warnings' => $warnings];
    }
}

$classy = $classies[$spec['class_names']['suite']];
$override = (bool) ($spec['class_names']['override_tag_helpers'] ?? false);
foreach ($spec['class_names']['calls'] as $call) {
    $parts = array_map(function ($part) use ($classy, $resolve) {
        if (is_array($part) && array_key_exists('yass', $part)) {
            return $classy->yass(...$resolve($part['yass']));
        }
        if (is_array($part) && array_key_exists('hash', $part)) {
            return $part['hash'];
        }

        return $part;
    }, $call['parts']);
    $actual['class_names'][$call['name']] = mergedClassNames($classy, $override, $parts);
}

$show = fn (mixed $value): string => $value === null ? '(missing)' : json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
$total = 0;
$differences = [];
$compare = function (string $label, array $want, array $got) use (&$total, &$differences, $show): void {
    foreach (array_unique([...array_keys($want), ...array_keys($got)]) as $name) {
        $total++;
        if (($want[$name] ?? null) !== ($got[$name] ?? null)) {
            $differences[] = "$label $name\n  expected.json: ".$show($want[$name] ?? null)."\n  php:           ".$show($got[$name] ?? null);
        }
    }
};
foreach (array_unique([...array_keys($expected['suites'] ?? []), ...array_keys($actual['suites'])]) as $suiteName) {
    $compare("[$suiteName]", $expected['suites'][$suiteName] ?? [], $actual['suites'][$suiteName] ?? []);
}
$compare('[class_names]', $expected['class_names'] ?? [], $actual['class_names']);

if ($differences !== []) {
    echo implode("\n", $differences)."\n\n";
    echo count($differences)." of $total calls differ\n";
    exit(1);
}
echo "$total calls match\n";
