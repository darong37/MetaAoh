# Design Concept

## Terms

### AOH
`AOH` は、各要素が1行を表すハッシュリファレンスである配列リファレンスである。

このプロジェクトにおける `AOH` は、次の条件を満たすものとする。

- すべての `row` は同じカラム集合を持つ。
- すべての `row` は `cols` で定義された全カラムを持つ。
- どのカラム値も `undef` であってはならない。
- 空の値が必要なときは `undef` ではなく空文字を使う。

### row
`row` は `AOH` を構成する1要素のハッシュリファレンスである。

### AnyAoh
`AnyAoh` は、このプロジェクトで扱う `AOH` 系データ構造の総称である。

`AnyAoh` は次のいずれかを指す。

- plain な `AOH`
- `metaAoh`

### AOT
`AOT` は `Array of Tree` である。

`AOT` は、`group` によって得られる木構造の配列リファレンスである。
各要素は tree node であり、階層を持つ。

### tree node
`tree node` は `AOT` を構成する1要素のハッシュリファレンスである。

各 `tree node` は、その階層で使われたグループカラムと `'*'` を持つ。
`'*'` には子要素の配列リファレンスが入る。

葉にあたる `tree node` の `'*'` には、残りカラムだけを持つ配列リファレンスが入る。

### metaAoh
`metaAoh` は、カラムに関するメタ情報を持つ配列リファレンスである。

`metaAoh` の本体構造は、平坦な `AOH` または木構造の `AOT` のいずれかを取りうる。
したがって `metaAoh` は `AnyAoh` の一種である。

`metaAoh` については、次のように区別する。

- `grouped == 0` の `metaAoh` は `AOH` を本体に持つ
- `grouped == 1` の `metaAoh` は `AOT` を本体に持つ

### meta
`meta` は `metaAoh` のカラムメタ情報を表すハッシュリファレンスである。

`meta` は次のキーを持つ。

- `order`
- `attrs`
- `cols`
- `grouped`

### order
`order` は、順番と属性指定を含んだカラム指定文字列の配列リファレンスである。

各要素は `NAME` または `NAME#` の形をとる。
`order` は `new` に渡す指定そのものを保持する。

`NAME` に使えない文字は次の通りとする。
- `#`（属性指定の区切り文字として予約）
- `*`（AOT の子要素コンテナキーとして予約）
- ASCII 制御文字（`\x00`–`\x1F`）

### cols
`cols` は、属性指定を除いた純粋なカラム名だけの配列リファレンスである。

`cols` はカラム順を表す。
各要素はカラム名のみを持ち、`#` を含まない。

### attrs
`attrs` は、カラム名をキーとし属性文字列を値とするハッシュリファレンスである。

値は次のいずれかとする。

- `str`
- `num`

`cols` と `attrs` は同じカラム集合を表す。

### grouped
`grouped` は、その `metaAoh` の本体構造が `AOH` ではなく `AOT` であることを示す真偽値である。

- `0` は `AOH`
- `1` は `AOT`

## Concept

`metaAoh` の本質は、`AOH` そのものではなく、カラムメタ情報を持った配列データである。
その配列データは、用途に応じて平坦な `AOH` と木構造の `AOT` を取りうる。

平坦状態では、`metaAoh` は通常の `AOH` として扱えることを保つ。
利用者は、通常の `AOH` と同じ感覚で `row` を読み、走査し、必要なら通常の配列操作も行える。

グループ化状態では、`metaAoh` の本体は `AOT` となる。
この状態では本体はもはや `AOH` ではないが、同じ `meta` を持つ `metaAoh` として扱う。

`metaAoh` が持つメタ情報は、カラム指定、カラム順、カラム属性、および現在の本体構造が `AOH` か `AOT` か、の4点に絞る。

カラム指定は `order` で表す。
純粋なカラム順は `cols` で表す。
カラム属性は `attrs` で表し、各カラムは `str` または `num` のいずれかを持つ。
構造状態は `grouped` で表す。

コンストラクタ入力は、順番と属性を同時に表現する。
カラム名の末尾に `#` が付く場合は `num` を意味し、付かない場合は `str` を意味する。
保持されるメタ情報では、`order` には元の指定をそのまま保持し、`cols` には `#` を除いたカラム名を保持し、`attrs` には解決後の `str` または `num` を保持する。

`metaAoh` の整合性を保つためのメソッドは、本体が `AOH` のときは `AOH` 条件を検証する。
ただし `metaAoh` は平坦状態では通常の `AOH` としても扱えるべきなので、生の配列操作も許容する。
その場合の整合性は呼び出し側の責任とする。

`meta` は `metaAoh` オブジェクト自身にひも付くものとして扱う。
同じオブジェクトの中で本体構造や内容を書き換えても、オブジェクト実体が変わらない限り `meta` は維持されるものとする。

`group` は `AOH` 構造の `metaAoh` を `AOT` 構造の `metaAoh` に変換する操作である。
`expand` は `AOT` 構造の `metaAoh` を `AOH` 構造の `metaAoh` に戻す操作である。
この2つは可逆であることを重視する。

## API

| Method | Interface | Returns | Description |
| --- | --- | --- | --- |
| `new` | `MetaAoh->new($anyAoh, @order)` | `metaAoh` | `AnyAoh` と必須の順番指定から `metaAoh` を生成する。 |
| `meta` | `$metaAoh->meta()` | `meta` | インスタンスのメタ情報を返す。 |
| `keys` | `$metaAoh->keys()` | `@keys` | `cols` に従ったカラム名を返す。 |
| `count` | `$metaAoh->count()` | `$count` | 本体要素数を返す。平坦状態では `row` 数、グループ化状態では最上位 node 数を返す。 |
| `toAoh` | `$metaAoh->toAoh()` | `$aoh` | `metaAoh` を平坦な `AOH` として返す。 |
| `sort` | `$metaAoh->sort(@keys)` | `metaAoh` | 指定カラムの優先順で `row` を並べ替える。 |
| `add` | `$metaAoh->add(@rows)` | `metaAoh` | 条件を満たす `row` を追加する。 |
| `group` | `$metaAoh->group(@groups)` | `metaAoh` | `AOH` 構造の `metaAoh` を `AOT` 構造の `metaAoh` に変換する。 |
| `expand` | `$metaAoh->expand()` | `metaAoh` | `AOT` 構造の `metaAoh` を `AOH` 構造の `metaAoh` に戻す。 |

| Function | Interface | Returns | Description |
| --- | --- | --- | --- |
| `is_metaAOH` | `MetaAoh::is_metaAOH($value)` | `$bool` | 値が `metaAoh` かどうかを返す。 |
| `validate` | `MetaAoh::validate($aoh, $cols)` | `$bool` | `AOH` が `cols` 条件を満たすか検証する。 |

### `new($anyAoh, @order)`
`AnyAoh` と順番指定から `metaAoh` を生成する。

`$anyAoh` は `AnyAoh` である。
`@order` はカラム指定文字列の並びである。
`@order` は常に必須である。

`$anyAoh` に `metaAoh` を渡した場合は、まず `toAoh()` によって平坦な `AOH` を取り出し、その結果に対して新しい `metaAoh` を生成する。
したがって `$anyAoh` には plain `AOH` も `metaAoh` も渡してよい。

順番指定の記法は次の通りとする。

- `NAME` はカラム `NAME` の属性が `str` であることを表す。
- `NAME#` はカラム `NAME` の属性が `num` であることを表す。

例:

```perl
my $m = MetaAoh->new(
  [
    { col2 => '10', col1 => 'A' },
    { col2 => '20', col1 => 'B' },
  ],
  'col2#',
  'col1',
);
```

この指定から次のメタ情報を生成する。

```perl
{
  order => ['col2#', 'col1'],
  attrs => {
    col2 => 'num',
    col1 => 'str',
  },
  cols => ['col2', 'col1'],
  grouped => 0,
}
```

返り値は `metaAoh` とする。

`new` は、`$anyAoh` 自体、または `toAoh()` で取り出した結果が `AOH` の条件を満たすことを検証しなければならない。

### `is_metaAOH($value)`
`$value` が `metaAoh` なら真を返し、それ以外なら偽を返す。

返り値は `$bool` とする。

### `validate($aoh, $cols)`
`$aoh` が `cols` に対して `AOH` 条件を満たすことを検証する。

問題がなければ真を返す。
条件を満たさない場合はエラーとする。

返り値は `$bool` とする。

### `meta()`
インスタンスのメタ情報ハッシュリファレンスを返す。

返り値は `meta` とする。

### `keys()`
順序付きのカラム名を返す。

たとえば `cols` が `['col2', 'col1']` なら、`keys()` は次を返す。

```perl
('col2', 'col1')
```

返り値は `@keys` とする。

### `count()`
本体要素数を返す。

`grouped` が `0` のときは `row` 数を返す。
`grouped` が `1` のときは最上位 `tree node` 数を返す。

返り値は `$count` とする。

### `toAoh()`
`metaAoh` を平坦な `AOH` として返す。

本体が `AOH` の場合は、その内容を `AOH` として返す。
本体が `AOT` の場合は、内部で `expand` 相当の処理を行い、平坦化した `AOH` を返す。

返り値は `$aoh` とする。

### `sort(@keys)`
複数カラムを使って `row` を並べ替える。

このメソッドは `grouped` が `0` のときにのみ意味を持つ。

`@keys` は並べ替えに使うカラム名の並びである。
前に指定したカラムほど優先順位が高い。
たとえば `sort('col1', 'col2')` は、`col1` を第一優先、`col2` を第二優先として並べ替えることを意味する。

各カラムは `attrs` に存在しなければならない。
比較方法は `attrs` の属性に従う。

- `str` は文字列比較を使う。
- `num` は数値比較を使う。

返り値は `metaAoh` とする。

### `add(@rows)`
`metaAoh` に `row` を追加する。

このメソッドは `grouped` が `0` のときにのみ意味を持つ。

追加されるすべての `row` は、`new` と同じ `AOH` 条件を満たさなければならない。
特に各 `row` は次を満たす。

- `cols` で定義された全カラムを持つ。
- それらのカラム値に `undef` を含まない。

返り値は `metaAoh` とする。

### direct array operations
`metaAoh` は平坦状態では通常の `AOH` としても扱えるため、`push` のような直接の配列操作も使用できる。

ただし直接の配列操作は、メタ情報との整合性や `row` の妥当性を保証しない。
その利用は許容するが、責任は呼び出し側にある。

### `group(@groups)`
`AOH` 構造の `metaAoh` を `AOT` 構造の `metaAoh` に変換する。

このメソッドは `grouped` が `0` のときにのみ意味を持つ。

`@groups` の各要素は、その階層で使うカラム名の配列リファレンスである。
前に指定したグループほど外側の階層を作り、後に指定したグループほど内側の階層を作る。

例:

```perl
my $g = $m->group(
  ['A', 'B'],
  ['C'],
);
```

この指定は次を意味する。

- まず `A, B` でグループ化する。
- その各グループの内側で `C` でグループ化する。
- 最後に未使用カラムを葉の配列へ置く。

グループ化後の各 node は、子要素の入れ物として `'*'` を持つ。

入力はソート済みであることを前提とする。各階層の「外側からの累積キー組」（`level1` の組、`level1+level2` の組、…）について、同一のキー組は連続して現れなければならない。一度終わったキー組が離れて再出現した場合は、呼び出し側のソート漏れ（SQL の `ORDER BY` 忘れ等）とみなして `dying` で送出する。ソートされていない入力をグループ化したい場合は、先に `sort()` を呼ぶ。連続した入力に対する結果は従来と変わらないため、`group` / `expand` の可逆性は維持される。

返り値は `metaAoh` とし、`meta` は元のインスタンスから引き継ぐ。
ただし返り値の `meta->{grouped}` は `1` でなければならない。

### `expand()`
`AOT` 構造の `metaAoh` を `AOH` 構造の `metaAoh` に戻す。

このメソッドは `grouped` が `1` のときに意味を持つ。

返り値は `metaAoh` とし、`meta` は元のインスタンスから引き継ぐ。
ただし返り値の `meta->{grouped}` は `0` でなければならない。