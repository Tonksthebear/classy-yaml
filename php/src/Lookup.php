<?php

declare(strict_types=1);

namespace Tonksthebear\ClassyYaml;

/**
 * Port of Classy::Yaml::Lookup (classy-yaml 1.7.3, lib/classy/yaml/lookup.rb).
 *
 * Argument mapping from Ruby to PHP:
 * - a Ruby Hash is a PHP array that is not a list (array_is_list() is false);
 * - a Ruby Array is a PHP list;
 * - a Ruby Symbol or String is a PHP string (Classy calls to_s on both).
 * The keys add, skip_base and classy_files are Symbol keys in Ruby. In PHP they are
 * string keys, so a PHP caller cannot use "add" as a YAML key name in a hash argument.
 */
final class Lookup
{
    /** Returned by walk() when a key path goes through a value that is not a hash. */
    public const INVALID = "\0classy:invalid";

    /**
     * Collects the lookup key paths and add: values in the order 1.7.2 used:
     * leaf paths first, then the parent paths of each list of values.
     *
     * @param list<mixed> $values
     * @param list<string> $root
     * @param list<list<string>> $keys
     * @param list<mixed> $adds
     */
    public static function collectList(array $values, array $root, array &$keys, array &$adds): void
    {
        $parents = null;
        foreach ($values as $value) {
            $parents = self::collect($value, $root, $keys, $adds, $parents);
        }
        if ($parents !== null) {
            array_push($keys, ...$parents);
        }
    }

    /**
     * @param list<string> $root
     * @param list<list<string>> $keys
     * @param list<mixed> $adds
     * @param list<list<string>>|null $parents
     * @return list<list<string>>|null
     */
    private static function collect(mixed $value, array $root, array &$keys, array &$adds, ?array $parents): ?array
    {
        if (self::isHash($value)) {
            if (array_key_exists('add', $value)) {
                $adds[] = $value['add'];
            }
            foreach ($value as $name => $child) {
                $name = (string) $name;
                if ($name === 'add') {
                    continue;
                }
                if ($root === [] && ($name === 'skip_base' || $name === 'classy_files')) {
                    continue;
                }
                $path = [...$root, $name];
                $parents ??= [];
                $parents[] = $path;
                $nested = self::collect($child, $path, $keys, $adds, null);
                if ($nested !== null) {
                    array_push($keys, ...$nested);
                }
            }
        } elseif (is_array($value)) {
            self::collectList($value, $root, $keys, $adds);
        } else {
            $keys[] = [...$root, self::segment($value)];
        }

        return $parents;
    }

    /** Ruby's to_s for the scalar argument types Classy accepts. */
    public static function segment(mixed $value): string
    {
        return match (true) {
            $value === null => '',
            $value === true => 'true',
            $value === false => 'false',
            $value instanceof \BackedEnum => (string) $value->value,
            $value instanceof \UnitEnum => $value->name,
            is_float($value) && floor($value) === $value && abs($value) < 1e16 => sprintf('%.1f', $value),
            default => (string) $value,
        };
    }

    /**
     * Resolves each key path against the layers (lowest priority first) and appends base and
     * specific classes. Returns false when a path went through a value that is not a hash.
     *
     * @param list<list<string>> $keys
     * @param list<array<string, mixed>> $layers
     * @param list<string> $classes
     * @param callable(list<string>): void $warn
     */
    public static function resolve(array $keys, array $layers, bool $skipBase, array &$classes, callable $warn): bool
    {
        $clean = true;
        foreach ($keys as $path) {
            if (! self::resolvePath($path, $layers, $skipBase, $classes, $warn)) {
                $clean = false;
            }
        }

        return $clean;
    }

    /**
     * @param list<string> $path
     * @param list<array<string, mixed>> $layers
     * @param list<string> $classes
     * @param callable(list<string>): void $warn
     */
    private static function resolvePath(array $path, array $layers, bool $skipBase, array &$classes, callable $warn): bool
    {
        $clean = true;
        $baseClasses = null;
        $fetchedClasses = null;
        $last = count($path) - 1;

        for ($index = count($layers) - 1; $index >= 0; $index--) {
            $parent = self::walk($layers[$index], $path, $last);
            if (self::isHashNode($parent)) {
                $value = $parent[$path[$last]] ?? null;
            } elseif ($parent === null) {
                $value = null;
            } else {
                $value = self::INVALID;
            }

            if ($value === self::INVALID) {
                $clean = false;
                $warn($path);
            } else {
                if (! $skipBase && $baseClasses === null) {
                    $baseValue = null;
                    if (self::isHashNode($value)) {
                        $baseValue = $value['base'] ?? null;
                    } elseif ($last > 0 && self::isHashNode($parent)) {
                        $baseValue = $parent['base'] ?? null;
                    }
                    $baseClasses = self::classesOf($baseValue);
                }
                if ($fetchedClasses === null && ! self::isHashNode($value)) {
                    $fetchedClasses = self::classesOf($value);
                }
            }

            if ($fetchedClasses !== null && ($skipBase || $baseClasses !== null)) {
                break;
            }
        }

        if ($baseClasses !== null) {
            array_push($classes, ...$baseClasses);
        }
        if ($fetchedClasses !== null) {
            array_push($classes, ...$fetchedClasses);
        }

        return $clean;
    }

    /**
     * Follows path[0..depth) from node. Returns null when a key is missing, and INVALID when the
     * path continues through a value that is not a hash.
     *
     * @param list<string> $path
     */
    private static function walk(mixed $node, array $path, int $depth): mixed
    {
        for ($index = 0; $index < $depth; $index++) {
            if (self::isHashNode($node)) {
                $node = $node[$path[$index]] ?? null;
            } elseif ($node === null) {
                return null;
            } else {
                return self::INVALID;
            }
        }

        return $node;
    }

    /**
     * A compiled leaf is a non-empty list of classes; anything else has none.
     *
     * @return list<string>|null
     */
    private static function classesOf(mixed $value): ?array
    {
        return $value instanceof ClassList && $value->classes !== [] ? $value->classes : null;
    }

    /** A compiled YAML mapping. Compiled leaves are ClassList objects, never arrays. */
    private static function isHashNode(mixed $node): bool
    {
        return is_array($node);
    }

    /** A Ruby Hash argument: a PHP array that is not a list. */
    public static function isHash(mixed $value): bool
    {
        return is_array($value) && $value !== [] && ! array_is_list($value);
    }
}
