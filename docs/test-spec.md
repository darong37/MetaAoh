# MetaAoh Test Spec

## テスト方針

- `Test::More` を使用。
- テストファイル: `test/metaaoh.t`
- 実行: `prove -lr test/`
- テスト実行時の環境変数は `.claude/settings.json` の `env` が設定済みである前提とする。
- `PERL5LIB=...` や `LOGDIR=...` をテストコマンドへ直接書かない。

## テストケース一覧

### new / meta

| # | 内容 | 確認方法 |
|---|---|---|
| 1 | `new` で生成した metaAoh の `meta` が正しい | `is_deeply($m->meta, { order, cols, attrs, grouped })` |
| 2 | `order` に `NAME#` を含む場合、`attrs` が `num`、`cols` が `#` なし、`grouped` が `0` | `is_deeply($sorted->meta, ...)` |

### keys / count

| # | 内容 | 確認方法 |
|---|---|---|
| 3 | `keys` が `cols` 順のカラム名リストを返す | `is_deeply([$m->keys], [...])` |
| 4 | `count` が row 数を返す | `is($m->count, 6)` |
| 5 | grouped metaAoh の `count` が最上位 tree node 数を返す | `is($g->count, 4)` |

### is_metaAOH / validate

| # | 内容 | 確認方法 |
|---|---|---|
| 6 | `is_metaAOH` が metaAoh に対して真を返す | `ok(is_metaAOH($m))` |
| 7 | `is_metaAOH` が通常 AOH に対して偽を返す | `ok(!is_metaAOH([]))` |
| 8 | `validate` が正常な AOH に対して真を返す | `ok(validate([...], [...]))` |
| 9 | `validate` が `undef` 値を含む row を拒否する | `like($@, qr/undef value not allowed/)` |

### sort

| # | 内容 | 確認方法 |
|---|---|---|
| 10 | 複数カラム指定・`num` 属性での並べ替えが正しい | `is_deeply([...], [[a,05],[a,9],[a,20],[b,10]])` |
| 11 | grouped metaAoh に対する `sort` がエラーになる | `like($@, qr/sort not available/)` |

### add / toAoh

| # | 内容 | 確認方法 |
|---|---|---|
| 12 | `add` で row が追加される | `is($m->count, 7)` |
| 13 | grouped metaAoh に対する `add` がエラーになる | `like($@, qr/add not available/)` |
| 14 | `toAoh` が平坦 AOH のコピーを返す | `is_deeply($m->toAoh, [@$m])` |

### group

| # | 内容 | 確認方法 |
|---|---|---|
| 15 | `group` の返り値が MetaAoh インスタンスである | `isa_ok($g, 'MetaAoh')` |
| 16 | `group` の返り値が元の `meta` を引き継ぎ、`grouped` を `1` にする | `is_deeply($g->meta, { %{$m->meta}, grouped => 1 })` |
| 17 | `group` が正しい木構造を生成する | `is_deeply($g, [...])` |
| 18 | grouped metaAoh に対する `group` がエラーになる | `like($@, qr/group not available/)` |
| 19 | `group` で未知カラムを指定するとエラーになる | `like($@, qr/unknown key:/)` |
| 20 | `group` でグループ間カラム重複があるとエラーになる | `like($@, qr/duplicate key across groups:/)` |
| 20a | `group` で単一レベルのキーが分断して再出現するとエラー | `like($@, qr/reappear/)` |
| 20b | `group` で全結合キーは各1回でも外側レベルが分断するとエラー | `like($@, qr/reappear/)` |
| 20c | ソート済み入力の `group` はエラーにならない | `is($gs->count, 2)` |

### expand / toAoh（grouped）/ new（metaAoh 入力）

| # | 内容 | 確認方法 |
|---|---|---|
| 21 | `expand` の返り値が MetaAoh インスタンスである | `isa_ok($expanded, 'MetaAoh')` |
| 22 | `expand` が grouped metaAoh を元の平坦 meta に戻す | `is_deeply($expanded->meta, $m->meta)` |
| 23 | `expand` が grouped metaAoh を元の平坦 AOH に戻す | `is_deeply($expanded->toAoh, $m->toAoh)` |
| 24 | grouped metaAoh への `toAoh` が平坦化された AOH を返す | `is_deeply($g->toAoh, $m->toAoh)` |
| 25 | `new` に metaAoh を渡すと平坦化して再生成される | `is_deeply($cloned, $m)` |
| 26 | 同じ `order` を明示すれば `meta` が同一になる | `is_deeply($cloned->meta, $m->meta)` |
| 27 | `new` に metaAoh を渡すとき `order` を省略するとエラー | `like($@, qr/order required/)` |

### 追加の回帰テスト

| # | 内容 | 確認方法 |
|---|---|---|
| 28 | `_` を含むカラム名を受け入れる | `ok(is_metaAOH($under))` |
| 29 | 予約カラム名 `*` を拒否する | `like($@, qr/bad order/)` |
| 30 | グループキー値に `\x1E` を含んでもバケット衝突しない | `is($sep_g->count, 2)` |
| 31 | 不正 AOT の葉でカラムが欠けている場合は `expand missing key` になる | `like($@, qr/expand missing key:/)` |
| 32 | flat metaAoh に対する `expand` は新しいオブジェクトを返す | `ok($flat != $eflat)` |
| 33 | `new` は呼び出し元 arrayref を bless しない | `ok(ref($orig) ne 'MetaAoh')` |
| 34 | `sort` は呼び出し元 arrayref を変更しない | `is($orig2->[0]{name}, 'b')` |
