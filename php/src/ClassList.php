<?php

declare(strict_types=1);

namespace Tonksthebear\ClassyYaml;

/**
 * A compiled YAML leaf: the classes of a string or a (flattened) list. Ruby's Classy compiles a
 * leaf to a frozen Array and a mapping to a frozen Hash; PHP has one array type for both, so a
 * leaf is wrapped to keep the two apart.
 */
final class ClassList
{
    /** @param list<string> $classes */
    public function __construct(public readonly array $classes)
    {
    }
}
