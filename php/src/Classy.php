<?php

declare(strict_types=1);

namespace Tonksthebear\ClassyYaml;

use Symfony\Component\Yaml\Exception\ParseException;
use Symfony\Component\Yaml\Yaml;
use TalesFromADev\TailwindMerge\TailwindMerge;

/**
 * Port of Classy::Yaml (classy-yaml 1.7.3, lib/classy/yaml.rb and helpers.rb) for PHP.
 *
 * Layers, lowest priority first: engine files, the default file, extra files, then the
 * classy_files of the call (component files). A path is resolved against the layers from the
 * highest priority down; see Lookup.
 *
 * Framework-free: a host framework builds one instance per application (per worker
 * under Octane) and passes the base path, the logger and whether files are checked for edits.
 */
final class Classy
{
    public const DEFAULT_CACHE_SIZE = 5000;

    /** @var array<string, array{signature: ?array, layer: ?array}> */
    private array $fileCache = [];

    /** @var list<array<string, mixed>>|null */
    private ?array $staticLayers = null;

    private ResultCache $results;

    private bool $checkPending = false;

    private ?TailwindMerge $merger = null;

    /** @var \Closure(InvalidKeyError): void */
    private \Closure $warn;

    /** @var \Closure(string, string): void */
    private \Closure $error;

    /**
     * @param list<string> $engineFiles absolute paths, lowest priority
     * @param list<string> $extraFiles paths relative to $basePath, above the default file
     * @param bool $reloading true while the app reloads code (local development): files are
     *                        checked for edits once per request, as Classy's executor hook does
     */
    public function __construct(
        private string $basePath,
        private array $engineFiles = [],
        private ?string $defaultFile = 'config/utility_classes.yml',
        private array $extraFiles = [],
        private bool $reloading = false,
        int $cacheSize = self::DEFAULT_CACHE_SIZE,
        private bool $tailwindMerge = true,
        ?callable $warn = null,
        ?callable $error = null,
    ) {
        $this->results = new ResultCache($cacheSize);
        $this->warn = $warn !== null ? \Closure::fromCallable($warn) : static fn (InvalidKeyError $e) => trigger_error($e->getMessage(), E_USER_WARNING);
        $this->error = $error !== null ? \Closure::fromCallable($error) : static fn (string $message) => trigger_error($message, E_USER_WARNING);
    }

    /** yass(*args): the classes for the arguments, as one space-separated string. */
    public function yass(mixed ...$args): string
    {
        return $this->classesFor(array_values($args));
    }

    /** @param list<mixed> $args */
    public function classesFor(array $args): string
    {
        if ($this->checkPending) {
            $this->checkForChanges();
        }
        $key = $this->results->maxSize() > 0 ? self::cacheKey($args, $this->tailwindMerge) : null;
        if ($key !== null) {
            $cached = $this->results->get($key);
            if ($cached !== null) {
                return $cached;
            }
        }

        $generation = $this->results->generation();
        [$result, $cacheable] = $this->buildClasses($args);
        if ($key !== null && $cacheable) {
            $this->results->store($key, $result, $generation);
        }

        return $result;
    }

    /** Tailwind-merges a class list with the shared merger (Classy::Yaml.merge_classes). */
    public function mergeClasses(string|array $classes): string
    {
        $this->merger ??= new TailwindMerge();

        return $this->merger->merge(is_array($classes) ? implode(' ', $classes) : $classes);
    }

    /** Called at the start of each request (Classy's executor hook): check files while reloading. */
    public function filesMayHaveChanged(): void
    {
        if ($this->reloading) {
            $this->checkPending = true;
        }
    }

    /** Parses the YAML and builds the merger ahead of the first request (Classy::Yaml.warm). */
    public function warm(): void
    {
        $this->staticLayers();
        if ($this->tailwindMerge) {
            $this->merger ??= new TailwindMerge();
        }
    }

    public function setCacheSize(int $size): void
    {
        if ($size < 0) {
            throw new \InvalidArgumentException("cache size must be an integer of 0 or more, got {$size}");
        }
        $this->results->setMaxSize($size);
    }

    public function generation(): int
    {
        return $this->results->generation();
    }

    public function resetCaches(bool $files = false): void
    {
        if ($files) {
            $this->fileCache = [];
        }
        $this->invalidateResults();
    }

    /**
     * @param list<mixed> $args
     * @return array{0: string, 1: bool}
     */
    private function buildClasses(array $args): array
    {
        $layers = $this->staticLayers();
        $classyFiles = self::findHashWith($args, 'classy_files');
        if ($classyFiles !== null) {
            foreach ((array) $classyFiles['classy_files'] as $filePath) {
                $layer = $this->cachedYamlFile((string) $filePath, 'classy');
                if ($layer !== null) {
                    $layers[] = $layer;
                }
            }
        }
        $skipBase = self::findHashWith($args, 'skip_base');

        $keys = [];
        $adds = [];
        Lookup::collectList($args, [], $keys, $adds);
        $keys = self::uniqueBy($keys);
        $classes = [];
        $clean = Lookup::resolve(
            $keys,
            $layers,
            $skipBase !== null && $skipBase['skip_base'] === true,
            $classes,
            fn (array $path) => ($this->warn)(new InvalidKeyError($path)),
        );
        $classes = self::uniqueBy($classes);
        if ($adds !== []) {
            // Ruby: classes.concat(adds); classes.flatten!; classes.uniq!
            $classes = self::uniqueBy([...$classes, ...self::flatten($adds)]);
        }

        if ($classes === []) {
            $result = '';
        } elseif ($this->tailwindMerge) {
            $result = $this->mergeClasses(array_map(fn ($c) => Lookup::segment($c), $classes));
        } else {
            $result = implode(' ', array_map(fn ($c) => Lookup::segment($c), $classes));
        }

        return [$result, $clean];
    }

    /** @return list<array<string, mixed>> */
    private function staticLayers(): array
    {
        if ($this->staticLayers !== null) {
            return $this->staticLayers;
        }
        $layers = [];
        foreach ($this->engineFiles as $path) {
            $layers[] = $this->cachedYamlFile($path, 'engine');
        }
        if ($this->defaultFile !== null) {
            $layers[] = $this->cachedYamlFile($this->defaultFile, 'default');
        }
        foreach ($this->extraFiles as $path) {
            $layers[] = $this->cachedYamlFile($path, 'extra');
        }

        return $this->staticLayers = array_values(array_filter($layers, fn ($layer) => $layer !== null));
    }

    /** @return array<string, mixed>|null */
    private function cachedYamlFile(string $filePath, string $fileType): ?array
    {
        $path = $this->fullPath($filePath);
        $this->fileCache[$path] ??= $this->loadYamlFile($path, $filePath, $fileType);

        return $this->fileCache[$path]['layer'];
    }

    /** @return array{signature: ?array, layer: ?array} */
    private function loadYamlFile(string $path, string $filePath, string $fileType): array
    {
        $signature = self::fileSignature($path);
        if ($signature === null) {
            return ['signature' => null, 'layer' => null];
        }
        try {
            $parsed = Yaml::parseFile($path);

            return ['signature' => $signature, 'layer' => is_array($parsed) && ! array_is_list($parsed) ? self::compile($parsed) : null];
        } catch (ParseException $e) {
            ($this->error)("Classy::Yaml: Failed to parse {$fileType} YAML file {$filePath}: {$e->getMessage()}", $fileType);

            return ['signature' => $signature, 'layer' => null];
        }
    }

    private function checkForChanges(): void
    {
        $this->checkPending = false;
        $changed = false;
        foreach ($this->fileCache as $path => $entry) {
            if ($entry['signature'] !== self::fileSignature($path)) {
                unset($this->fileCache[$path]);
                $changed = true;
            }
        }
        if ($changed) {
            $this->invalidateResults();
        }
    }

    private function invalidateResults(): void
    {
        $this->staticLayers = null;
        $this->results->invalidate();
    }

    private function fullPath(string $filePath): string
    {
        return str_starts_with($filePath, '/') ? $filePath : rtrim($this->basePath, '/').'/'.$filePath;
    }

    /** mtime, ctime, size, inode and device, as Classy's file_signature; null for a missing file. */
    private static function fileSignature(string $path): ?array
    {
        clearstatcache(true, $path);
        $stat = @stat($path);
        if ($stat === false || ! is_file($path)) {
            return null;
        }

        return [$stat['mtime'], $stat['ctime'], $stat['size'], $stat['ino'], $stat['dev']];
    }

    /**
     * Turns parsed YAML into lookup data: a string becomes its classes, a list its flattened
     * classes. Other values stay as they are and give no classes.
     */
    public static function compile(mixed $value): mixed
    {
        if (is_array($value) && ($value === [] || ! array_is_list($value))) {
            $compiled = [];
            foreach ($value as $key => $child) {
                $compiled[(string) $key] = self::compile($child);
            }

            return $compiled;
        }
        if (is_string($value)) {
            return new ClassList(self::splitClasses($value));
        }
        if (is_array($value)) {
            $classes = [];
            foreach (self::flatten($value) as $item) {
                $item = Lookup::segment($item);
                if (trim($item) !== '') {
                    $classes[] = $item;
                }
            }

            return new ClassList($classes);
        }

        return $value;
    }

    /** Ruby's String#split(" ") with blanks rejected. */
    private static function splitClasses(string $value): array
    {
        return array_values(array_filter(preg_split('/[ \t\n\v\f\r]+/', $value) ?: [], fn ($c) => $c !== ''));
    }

    /** @return list<mixed> */
    private static function flatten(array $values): array
    {
        $flat = [];
        array_walk_recursive($values, function ($item) use (&$flat) {
            $flat[] = $item;
        });

        return $flat;
    }

    /**
     * @template T
     * @param list<T> $values
     * @return list<T>
     */
    private static function uniqueBy(array $values): array
    {
        $seen = [];
        $unique = [];
        foreach ($values as $value) {
            $id = is_array($value) ? "\0".implode("\0", $value) : (is_string($value) ? 's'.$value : serialize($value));
            if (! isset($seen[$id])) {
                $seen[$id] = true;
                $unique[] = $value;
            }
        }

        return $unique;
    }

    /** @param list<mixed> $args */
    private static function findHashWith(array $args, string $key): ?array
    {
        foreach ($args as $arg) {
            if (Lookup::isHash($arg) && array_key_exists($key, $arg)) {
                return $arg;
            }
        }

        return null;
    }

    /** An order-sensitive key: serialize keeps hash order and value types. */
    private static function cacheKey(array $args, bool $tailwind): ?string
    {
        try {
            return ($tailwind ? 't' : 'f').serialize($args);
        } catch (\Throwable) {
            return null;
        }
    }
}
