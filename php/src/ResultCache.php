<?php

declare(strict_types=1);

namespace Tonksthebear\ClassyYaml;

/**
 * Port of Classy::Yaml::ResultCache: a bounded least-recently-used cache of yass results with a
 * generation counter. PHP runs one request per process (or per worker with Octane), so the
 * Ruby version's Mutex is not needed; an Octane or Swoole host shares one instance per worker.
 */
final class ResultCache
{
    /** @var array<string, string> */
    private array $entries = [];

    private int $generation = 0;

    public function __construct(private int $maxSize)
    {
    }

    public function maxSize(): int
    {
        return $this->maxSize;
    }

    public function setMaxSize(int $size): void
    {
        $this->maxSize = $size;
        while (count($this->entries) > $this->maxSize) {
            array_shift($this->entries);
        }
    }

    public function generation(): int
    {
        return $this->generation;
    }

    public function size(): int
    {
        return count($this->entries);
    }

    public function get(string $key): ?string
    {
        if (! array_key_exists($key, $this->entries)) {
            return null;
        }
        $value = $this->entries[$key];
        // Move the entry to the newest end.
        unset($this->entries[$key]);
        $this->entries[$key] = $value;

        return $value;
    }

    public function store(string $key, string $value, int $generation): void
    {
        if ($generation !== $this->generation || $this->maxSize <= 0) {
            return;
        }
        unset($this->entries[$key]);
        $this->entries[$key] = $value;
        if (count($this->entries) > $this->maxSize) {
            array_shift($this->entries);
        }
    }

    public function invalidate(): void
    {
        $this->generation++;
        $this->entries = [];
    }
}
