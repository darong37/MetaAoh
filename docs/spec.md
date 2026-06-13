# MetaAoh Spec

## 概要

`MetaAoh` は、カラム順・カラム属性のメタ情報を持つ Perl モジュールである。

`MetaAoh` の本体は、`grouped == 0` のときは通常の AOH（Array of Hash refs）、`grouped == 1` のときは AOT（Array of Tree）を取りうる。
平坦状態では通常の AOH として扱え、グループ化状態では同じメタ情報を持った木構造として扱える。

## 用語

| 用語 | 定義 |
|---|---|
| AnyAoh | このプロジェクトで扱う `AOH` 系データ構造の総称。plain な `AOH` または `metaAoh` を指す。 |
| AOH | 各要素がハッシュリファレンスである配列リファレンス。全 row が同じカラム集合を持ち、値に `undef` を含まない。 |
| row | AOH を構成する 1 要素のハッシュリファレンス。 |
| AOT | `group` により得られる木構造の配列リファレンス。 |
| tree node | `AOT` を構成するハッシュリファレンス。 |
| metaAoh | `MetaAoh` クラスの bless された配列リファレンス。`meta` を持ち、`grouped == 0` なら `AOH`、`grouped == 1` なら `AOT` を本体に取る。 |
| meta | `order`・`cols`・`attrs`・`grouped` を持つハッシュリファレンス。 |
| order | `new` に渡したカラム指定文字列の配列リファレンス（`NAME` or `NAME#`）。 |
| cols | `#` を除いた純粋なカラム名の配列リファレンス。カラム順を表す。 |
| attrs | カラム名をキー、`str` または `num` を値とするハッシュリファレンス。 |
| grouped | `metaAoh` の本体が `AOH` ではなく `AOT` であることを示す真偽値。 |

## カラム指定記法

| 記法 | 意味 |
|---|---|
| `NAME` | カラム `NAME` の属性が `str`（文字列比較） |
| `NAME#` | カラム `NAME` の属性が `num`（数値比較） |

`NAME` に使えない文字は次の通りとする。

| 文字 | 理由 |
|---|---|
| `#` | 属性指定の区切り文字として予約 |
| `*` | AOT の子要素コンテナキーとして予約 |
| ASCII 制御文字（`\x00`–`\x1F`） | 使用不可 |

## API

### `MetaAoh->new($anyAoh, @order)`

AnyAoh と、カラム指定から metaAoh を生成する。

- `@order` は常に必須。
- `$anyAoh` に metaAoh を渡した場合は `toAoh` で平坦化してから再生成する。
- grouped な metaAoh も `toAoh` により平坦 AOH へ変換できるため入力として許可する。
- `$anyAoh` 自体、または `toAoh` 後の結果が AOH 条件を満たさない場合はエラー。
- 返り値: `metaAoh`

### `$metaAoh->meta()`

インスタンスのメタ情報ハッシュリファレンスを返す。

- 返り値: `{ order => [...], cols => [...], attrs => {...}, grouped => 0|1 }`

### `$metaAoh->keys()`

`cols` に従ったカラム名のリストを返す。

- 返り値: `@keys`

### `$metaAoh->count()`

metaAoh が持つ本体要素数を返す。

- `grouped == 0` のときは row 数。
- `grouped == 1` のときは最上位 tree node 数。
- 返り値: `$count`

### `$metaAoh->toAoh()`

metaAoh を通常の平坦な AOH として返す。

- `grouped == 1` の metaAoh に対して呼んだ場合は内部で展開し、平坦化した AOH を返す。
- 各 row はコピーされる。
- 返り値: `$aoh`

### `$metaAoh->sort(@keys)`

指定カラムの優先順で row を並べ替える。

- `@keys` の先頭が第一優先。
- 各カラムの比較方法は `attrs` の属性（`str` / `num`）に従う。
- `grouped == 1` の metaAoh には使用不可（エラー）。
- `@keys` に存在しないカラムや重複を含む場合はエラー。
- 返り値: `metaAoh`（同一インスタンス、並べ替え済み）

### `$metaAoh->add(@rows)`

条件を満たす row を追加する。

- 追加する各 row は AOH 条件（`cols` 全カラム存在・`undef` なし）を満たさなければならない。
- `grouped == 1` の metaAoh には使用不可（エラー）。
- 返り値: `metaAoh`（同一インスタンス）

### `$metaAoh->group(@groups)`

`AOH` 構造の metaAoh を `AOT` 構造の metaAoh に変換する。

- `@groups` の各要素はカラム名の配列リファレンス。前に指定したグループほど外側の階層。
- 各グループ内・グループ間でのカラム重複はエラー。
- 入力はソート済み前提。各階層の「外側からの累積キー組」（level1、level1+level2、…）について、一度途切れたキー組が再出現したらエラー（ソート漏れの検出）。ソートしてからグループ化したい場合は先に `sort()` を呼ぶ。
- 返り値は元の metaAoh と同じ `meta` を引き継いだ新しい `metaAoh`。
- 返り値の `meta->{grouped}` は `1`。
- `grouped == 1` の metaAoh には使用不可（エラー）。
- 返り値: `metaAoh`

### `MetaAoh::is_metaAOH($value)`

値が metaAoh かどうかを返す。

- 返り値: `1`（真）または `''`（偽）

### `MetaAoh::validate($aoh, $cols)`

AOH が `cols` に対して AOH 条件を満たすことを検証する。

- 各 row が `cols` の全カラムを過不足なく持つこと。
- 各カラム値に `undef` がないこと。
- 条件を満たさない場合はエラー。
- 返り値: `1`

### `$metaAoh->expand()`

`AOT` 構造の metaAoh を `AOH` 構造の metaAoh に戻す。

- `grouped == 1` のときに意味を持つ。
- 返り値の `meta->{grouped}` は `0`。
- 返り値: `metaAoh`

## 整合性の考え方

- `push` などの直接配列操作は許容するが、整合性の保証は呼び出し側の責任。
- `meta` はオブジェクト自身にひも付く。同一インスタンスで row を書き換えても `meta` は維持される。
- `group` と `expand` は可逆。`$m->group(...)->expand()` は元の平坦 AOH の構造と値に戻る。
