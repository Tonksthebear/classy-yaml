<?php

declare(strict_types=1);

namespace Tonksthebear\ClassyYaml;

/** Port of Classy::Yaml::InvalidKeyError. Classy logs it as a warning; it is never thrown. */
final class InvalidKeyError extends \RuntimeException
{
    /** @param list<string> $path */
    public function __construct(public readonly array $path)
    {
        parent::__construct(sprintf(
            'yass called with invalid keys: %s. This error can be raised when calling nested keys on an un-nested root.',
            self::rubyInspect($path),
        ));
    }

    /** @param list<string> $path */
    private static function rubyInspect(array $path): string
    {
        return '['.implode(', ', array_map(fn (string $part) => '"'.addcslashes($part, '"\\').'"', $path)).']';
    }
}
