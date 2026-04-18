# MetaAoh

AOH（Array of Hash refs）にカラムメタ情報（カラム順・カラム属性）を持たせる Perl モジュールです。

## 特徴

- 通常の AOH として扱いながら、`order`・`cols`・`attrs`・`grouped` のメタ情報を保持
- 複数カラムのソート（カラムごとに `str` / `num` 比較を指定可能）
- `group` で行を木構造にグループ化、`expand` で平坦な AOH に戻す
- `group` と `expand` は可逆

## 使い方

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
# => grouped => 0 の metaAoh（元の行内容に戻る）
```

## API

| メソッド / 関数 | 返り値 | 説明 |
|---|---|---|
| `MetaAoh->new($anyAoh, @order)` | `metaAoh` | AOH または metaAoh とカラム指定から metaAoh を生成 |
| `$m->meta()` | `meta` | メタ情報ハッシュを返す（`order`・`cols`・`attrs`・`grouped`） |
| `$m->keys()` | `@keys` | `cols` 順のカラム名リストを返す |
| `$m->count()` | `$count` | row 数（grouped の場合は最上位 node 数） |
| `$m->toAoh()` | `$aoh` | 平坦な AOH のコピーを返す（grouped なら展開） |
| `$m->sort(@keys)` | `metaAoh` | 指定カラムの優先順でソート |
| `$m->add(@rows)` | `metaAoh` | 検証済みの row を追加 |
| `$m->group(@groups)` | `metaAoh` | row を木構造にグループ化 |
| `$m->expand()` | `metaAoh` | grouped metaAoh を平坦な形に戻す |
| `MetaAoh::is_metaAOH($v)` | `$bool` | metaAoh なら真を返す |
| `MetaAoh::validate($aoh, $cols)` | `$bool` | AOH を cols に対して検証（失敗時は croak） |

## カラム指定記法

| 記法 | 意味 |
|---|---|
| `NAME` | カラム `NAME` の属性が `str`（文字列比較） |
| `NAME#` | カラム `NAME` の属性が `num`（数値比較） |

## 動作要件

- Perl 5.10 以上
- [Clone](https://metacpan.org/pod/Clone)
