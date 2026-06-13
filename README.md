# MetaAoh

[日本語版 README はこちら](README_ja.md)

A Perl module that provides an AOH (Array of Hash refs) with explicit column metadata — column order and column attributes (`str` / `num`).

## Features

- Extends a plain AOH with column metadata (`order`, `cols`, `attrs`, `grouped`)
- Can be used as a regular AOH at any time
- Supports multi-key sorting with per-column comparison types
- Groups rows into a tree structure (`group`) and restores them (`expand`)
- `group` and `expand` are reversible

## Synopsis

```perl
use MetaAoh;

my $m = MetaAoh->new(
    [
        { name => 'b', age => '10' },
        { name => 'a', age => '20' },
        { name => 'a', age => '05' },
    ],
    'name',   # str
    'age#',   # num
);

$m->sort(qw(name age));
# => [{ name => 'a', age => '05' }, { name => 'a', age => '20' }, { name => 'b', age => '10' }]

my $g = $m->group(['name']);
# => [{ name => 'a', '*' => [...] }, { name => 'b', '*' => [...] }]

my $flat = $g->expand;
# => metaAoh with grouped => 0, same rows as $m
```

## API

| Method / Function | Returns | Description |
|---|---|---|
| `MetaAoh->new($anyAoh, @order)` | `metaAoh` | Create a metaAoh from an AOH or metaAoh with column spec |
| `$m->meta()` | `meta` | Return metadata hash (`order`, `cols`, `attrs`, `grouped`) |
| `$m->keys()` | `@keys` | Return column names in `cols` order |
| `$m->count()` | `$count` | Number of rows (or top-level nodes if grouped) |
| `$m->toAoh()` | `$aoh` | Return a flat AOH copy (expands if grouped) |
| `$m->sort(@keys)` | `metaAoh` | Sort rows by the given keys in priority order |
| `$m->add(@rows)` | `metaAoh` | Append validated rows |
| `$m->group(@groups)` | `metaAoh` | Group rows into a tree structure (input must be sorted; croaks if a key re-appears) |
| `$m->expand()` | `metaAoh` | Restore a grouped metaAoh to flat form |
| `MetaAoh::is_metaAOH($v)` | `$bool` | Return true if value is a metaAoh |
| `MetaAoh::validate($aoh, $cols)` | `$bool` | Validate AOH against cols; croaks on failure |

## Column Spec Syntax

| Syntax | Meaning |
|---|---|
| `NAME` | Column `NAME` with `str` attribute (string comparison) |
| `NAME#` | Column `NAME` with `num` attribute (numeric comparison) |

The following characters are not allowed in `NAME`:

| Character | Reason |
|---|---|
| `#` | Reserved as attribute marker |
| `*` | Reserved as AOT child container key |
| ASCII control characters (`\x00`–`\x1F`) | Not permitted |

## Requirements

- Perl 5.38.5
