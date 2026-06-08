use strict;
use warnings;
use Test::More;
use lib 'src', 'lib';

use MetaAoh;

my $m = MetaAoh->new(
    [
        { A => 'A1', B => 'B1', C => 'C1', D => 'D1', E => 'E1' },
        { A => 'A1', B => 'B1', C => 'C1', D => 'D2', E => 'E2' },
        { A => 'A1', B => 'B1', C => 'C2', D => 'D3', E => 'E3' },
        { A => 'A1', B => 'B2', C => 'C1', D => 'D4', E => 'E4' },
        { A => 'A2', B => 'B1', C => 'C1', D => 'D5', E => 'E5' },
        { A => 'A2', B => 'B1', C => 'C2', D => 'D6', E => 'E6' },
    ],
    qw(A B C D E)
);

is_deeply(
    $m->meta,
    {
        order => [qw(A B C D E)],
        attrs => {
            A => 'str',
            B => 'str',
            C => 'str',
            D => 'str',
            E => 'str',
        },
        cols => [qw(A B C D E)],
        grouped => 0,
    },
    'meta is created from order',
);

is_deeply( [ $m->keys ], [qw(A B C D E)], 'keys follow cols' );
is( $m->count, 6, 'count returns row count' );
ok( MetaAoh::is_metaAOH($m), 'is_metaAOH detects metaAoh' );
ok( !MetaAoh::is_metaAOH( [] ), 'is_metaAOH rejects plain AOH' );
ok( MetaAoh::validate( [ { A => 'A1', B => 'B1', C => 'C1', D => 'D1', E => 'E1' } ], [qw(A B C D E)] ), 'validate accepts valid AOH' );

eval { MetaAoh::validate( [ { A => 'A1', B => undef } ], [qw(A B)] ) };
like( $@, qr/undef value not allowed: B/, 'validate rejects undef values' );

my $sorted = MetaAoh->new(
    [
        { name => 'b', age => '10' },
        { name => 'a', age => '20' },
        { name => 'a', age => '05' },
        { name => 'a', age => '9' },
    ],
    'name',
    'age#',
)->sort(qw(name age));

is_deeply(
    $sorted->meta,
    {
        order => [ 'name', 'age#' ],
        attrs => {
            name => 'str',
            age  => 'num',
        },
        cols => [ 'name', 'age' ],
        grouped => 0,
    },
    'meta keeps order spec and plain cols',
);

is_deeply(
    [ map { [ @$_{qw(name age)} ] } @$sorted ],
    [
        [ 'a', '05' ],
        [ 'a', '9' ],
        [ 'a', '20' ],
        [ 'b', '10' ],
    ],
    'sort supports multiple keys and numeric attr',
);

$m->add({ A => 'A3', B => 'B3', C => 'C3', D => 'D7', E => 'E7' });
is( $m->count, 7, 'add appends valid row' );
is_deeply( $m->toAoh, [ @$m ], 'toAoh returns flat AOH copy' );

my $g = $m->group(
    [ 'A', 'B' ],
    ['C'],
);

isa_ok( $g, 'MetaAoh' );
is( $g->count, 4, 'grouped count returns top-level node count' );
is_deeply(
    $g->meta,
    {
        %{ $m->meta },
        grouped => 1,
    },
    'group inherits meta and sets grouped flag',
);

is_deeply(
    $g,
    [
        {
            A   => 'A1',
            B   => 'B1',
            '*' => [
                {
                    C   => 'C1',
                    '*' => [
                        { D => 'D1', E => 'E1' },
                        { D => 'D2', E => 'E2' },
                    ],
                },
                {
                    C   => 'C2',
                    '*' => [
                        { D => 'D3', E => 'E3' },
                    ],
                },
            ],
        },
        {
            A   => 'A1',
            B   => 'B2',
            '*' => [
                {
                    C   => 'C1',
                    '*' => [
                        { D => 'D4', E => 'E4' },
                    ],
                },
            ],
        },
        {
            A   => 'A2',
            B   => 'B1',
            '*' => [
                {
                    C   => 'C1',
                    '*' => [
                        { D => 'D5', E => 'E5' },
                    ],
                },
                {
                    C   => 'C2',
                    '*' => [
                        { D => 'D6', E => 'E6' },
                    ],
                },
            ],
        },
        {
            A   => 'A3',
            B   => 'B3',
            '*' => [
                {
                    C   => 'C3',
                    '*' => [
                        { D => 'D7', E => 'E7' },
                    ],
                },
            ],
        },
    ],
    'group returns grouped metaAoh structure',
);

eval { $g->sort(qw(A B)) };
like( $@, qr/sort not available on grouped metaAoh/, 'sort rejects grouped metaAoh' );

eval { $g->add({ A => 'A9', B => 'B9', C => 'C9', D => 'D9', E => 'E9' }) };
like( $@, qr/add not available on grouped metaAoh/, 'add rejects grouped metaAoh' );

eval { $g->group(['A']) };
like( $@, qr/group not available on grouped metaAoh/, 'group rejects grouped metaAoh' );

eval { $m->group(['Z']) };
like( $@, qr/unknown key: Z/, 'group rejects unknown key' );

eval { $m->group(['A'], ['A']) };
like( $@, qr/duplicate key across groups: A/, 'group rejects duplicate key across groups' );

my $expanded = $g->expand;
my $cloned   = MetaAoh->new($g, @{ $g->meta->{order} });

isa_ok( $expanded, 'MetaAoh' );
is_deeply(
    $expanded->meta,
    $m->meta,
    'expand restores flat meta',
);
is_deeply(
    $expanded->toAoh,
    $m->toAoh,
    'expand restores flat AOH',
);
is_deeply( $g->toAoh, $m->toAoh, 'toAoh flattens grouped metaAoh' );
is_deeply( $cloned, $m, 'new accepts metaAoh with explicit order and rebuilds flat metaAoh' );
is_deeply( $cloned->meta, $m->meta, 'new keeps meta when same order is explicitly given' );

eval { MetaAoh->new($g) };
like( $@, qr/order required/, 'new requires order even for metaAoh input' );

# Bug 6: underscore column names must be accepted
my $under = MetaAoh->new( [ { col_name => 'v', _id => '1' } ], 'col_name', '_id' );
ok( MetaAoh::is_metaAOH($under), 'new accepts underscore column names' );

# '*' is reserved as AOT child key — must be rejected as a column name
eval { MetaAoh->new( [ { q => 'a', '*' => 'x' } ], 'q', '*' ) };
like( $@, qr/bad order/, 'new rejects reserved column name *' );

# Bug 5: multi-column group where values contain \x1E must not collide
# Row1: g1="a\x1Eb", g2="c"  → naive join gives "a\x1Eb\x1Ec"
# Row2: g1="a",      g2="b\x1Ec" → naive join also gives "a\x1Eb\x1Ec"  (collision!)
my $sep_m = MetaAoh->new(
    [
        { g1 => "a\x1Eb", g2 => 'c',      val => '1' },
        { g1 => 'a',      g2 => "b\x1Ec", val => '2' },
    ],
    'g1', 'g2', 'val',
);
my $sep_g = $sep_m->group( [ 'g1', 'g2' ] );
is( $sep_g->count, 2, 'group keeps rows with \\x1E in value separate' );

# Bug 1: corrupt AOT (missing a column in a leaf) should croak "expand missing key"
my $corrupt_g = MetaAoh->new( [ { A => 'a1', B => 'b1' } ], 'A', 'B' )->group( ['A'] );
push @$corrupt_g, { A => 'a2', '*' => [ {} ] };    # leaf {} is missing B
eval { $corrupt_g->expand };
like( $@, qr/expand missing key: B/, 'expand croaks missing key for corrupt leaf' );

my $flat   = MetaAoh->new( [ { X => 'v' } ], 'X' );
my $eflat  = $flat->expand;
ok( $flat != $eflat, 'expand on flat metaAoh returns new object' );

my $orig = [ { name => 'b' }, { name => 'a' } ];
MetaAoh->new( $orig, 'name' );
ok( ref($orig) ne 'MetaAoh', 'new does not bless the caller arrayref' );

my $orig2 = [ { name => 'b' }, { name => 'a' } ];
my $ms = MetaAoh->new( $orig2, 'name' );
$ms->sort('name');
is( $orig2->[0]{name}, 'b', 'sort does not mutate the original arrayref' );

done_testing;
