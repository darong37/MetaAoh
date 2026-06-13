package MetaAoh;

use strict;
use warnings;

use Carp qw(croak);
use Hash::Util::FieldHash qw(fieldhash);
use Scalar::Util qw(blessed);

fieldhash my %state_of;

sub new {
    my ($cls, $aoh, @order) = @_;

    croak "order required" unless @order;

    if (is_metaAOH($aoh)) {
        $aoh = $aoh->toAoh;
    }

    croak "aoh must be ARRAY ref" unless ref($aoh) eq 'ARRAY';
    my (@cols, %attrs);

    for my $spec (@order) {
        if ($spec !~ /^([^\x00-\x1F#*]+)(#?)$/) {
            croak "bad order: $spec";
        }

        my ($col, $mark) = ($1, $2);

        croak "duplicate order key: $col" if exists $attrs{$col};

        push @cols, $col;
        $attrs{$col} = $mark eq '#' ? 'num' : 'str';
    }

    validate($aoh, \@cols);

    my $obj = [@$aoh];
    bless $obj, $cls;
    $state_of{$obj} = {
        meta => {
            order => [@order],
            attrs => \%attrs,
            cols => \@cols,
            grouped => 0,
        },
    };

    return $obj;
}

sub meta {
    my ($self) = @_;

    my $state = $state_of{$self}
        or croak "meta state not found";

    return $state->{meta};
}

sub keys {
    my ($self) = @_;
    return @{ $self->meta->{cols} };
}

sub count {
    my ($self) = @_;
    return scalar @$self;
}

sub toAoh {
    my ($self) = @_;

    my $rows = $self->meta->{grouped}
        ? _expand_rows($self, $self->meta->{cols}, {})
        : $self;

    return [
        map {
            my %row = %$_;
            \%row;
        } @$rows
    ];
}

sub sort {
    my ($self, @keys) = @_;

    croak "sort requires keys" unless @keys;
    croak "sort not available on grouped metaAoh" if $self->meta->{grouped};

    my $meta = $self->meta;
    my %seen;

    for my $key (@keys) {
        croak "unknown key: $key" unless exists $meta->{attrs}{$key};
        croak "duplicate key: $key" if $seen{$key}++;
    }

    @$self = sort {
        for my $key (@keys) {
            my $type = $meta->{attrs}{$key};
            my $cmp
                = $type eq 'num'
                ? ($a->{$key} <=> $b->{$key})
                : ($a->{$key} cmp $b->{$key});
            return $cmp if $cmp;
        }
        return 0;
    } @$self;
    return $self;
}

sub add {
    my ($self, @rows) = @_;

    croak "add not available on grouped metaAoh" if $self->meta->{grouped};

    my $cols = $self->meta->{cols};
    validate(\@rows, $cols);

    push @$self, @rows;
    return $self;
}

sub group {
    my ($self, @groups) = @_;

    croak "group not available on grouped metaAoh" if $self->meta->{grouped};
    croak "group requires groups" unless @groups;

    my $meta = $self->meta;
    my @cols = @{ $meta->{cols} };
    my %known = map { $_ => 1 } @cols;
    my %used;

    for my $group (@groups) {
        croak "group must be ARRAY ref" unless ref($group) eq 'ARRAY';
        croak "group must not be empty" unless @$group;

        my %group_seen;
        for my $key (@$group) {
            croak "unknown key: $key" unless $known{$key};
            croak "duplicate key in group: $key" if $group_seen{$key}++;
            croak "duplicate key across groups: $key" if $used{$key}++;
        }
    }

    # 入力はソート済み前提。各階層の累積キー組が分断して再出現したら、
    # 呼び出し側のソート漏れ(ORDER BY 忘れ等)として croak する。
    _check_group_sorted($self, \@groups);

    my @rest = grep { !$used{$_} } @cols;
    my $grouped = _group_rows($self, \@groups, \@rest);
    my $meta2 = { %$meta, grouped => 1 };

    bless $grouped, ref($self);
    $state_of{$grouped} = {
        meta => $meta2,
    };

    return $grouped;
}

sub expand {
    my ($self) = @_;
    return ref($self)->new($self->toAoh, @{ $self->meta->{order} });
}

# 通常の関数

sub is_metaAOH {
    my ($value) = @_;
    return blessed($value) && $value->isa(__PACKAGE__) ? 1 : 0;
}

sub validate {
    my ($aoh, $cols) = @_;

    croak "aoh must be ARRAY ref" unless ref($aoh) eq 'ARRAY';
    croak "cols must be ARRAY ref" unless ref($cols) eq 'ARRAY';

    my $expected = scalar @$cols;

    for my $row (@$aoh) {
        croak "row must be HASH ref" unless ref($row) eq 'HASH';

        my @keys = CORE::keys %$row;
        croak "row has wrong column count" unless @keys == $expected;

        for my $key (@$cols) {
            croak "missing key: $key" unless exists $row->{$key};
            croak "undef value not allowed: $key" unless defined $row->{$key};
        }
    }

    return 1;
}

# 入力がソート済みかを検証する。各階層 L について「外側からの累積キー組」
# (level1 の組、level1+level2 の組、…)を順に見て、一度途切れたキー組が
# 再び現れたら croak する。最深の全結合キーだけでは上位レベルの分断を
# 捕捉できないため、各レベルを個別に確認する。
sub _check_group_sorted {
    my ($rows, $groups) = @_;

    my @cumulative;
    for my $group (@$groups) {
        push @cumulative, @$group;
        my %seen;
        my $prev;
        for my $row (@$rows) {
            my $key = join "\x1E", map {
                my $v = defined $row->{$_} ? $row->{$_} : '';
                length($v) . ':' . $v;
            } @cumulative;
            if ( !defined $prev || $key ne $prev ) {
                croak "group: key reappears (unsorted input); call sort() first"
                    if $seen{$key}++;
                $prev = $key;
            }
        }
    }
    return;
}

sub _group_rows {
    my ($rows, $groups, $rest) = @_;

    return [
        map {
            my %leaf;
            @leaf{@$rest} = @$_{@$rest};
            \%leaf;
        } @$rows
    ] unless @$groups;

    my ($cols, @next_groups) = @$groups;
    my (%bucket, @order_of_bucket);

    for my $row (@$rows) {
        my $bucket_key = join "\x1E", map {
            my $v = defined $row->{$_} ? $row->{$_} : '';
            length($v) . ':' . $v;
        } @$cols;

        if (!exists $bucket{$bucket_key}) {
            $bucket{$bucket_key} = [];
            push @order_of_bucket, $bucket_key;
        }

        push @{ $bucket{$bucket_key} }, $row;
    }

    my @out;

    for my $bucket_key (@order_of_bucket) {
        my $rows2 = $bucket{$bucket_key};
        my %node = map { $_ => $rows2->[0]{$_} } @$cols;

        $node{'*'} = _group_rows($rows2, \@next_groups, $rest);
        push @out, \%node;
    }

    return \@out;
}

sub _expand_rows {
    my ($rows, $cols, $base) = @_;
    my @out;

    for my $row (@$rows) {
        croak "grouped row must be HASH ref" unless ref($row) eq 'HASH';

        my %merged = (%$base);

        for my $key (CORE::keys %$row) {
            next if $key eq '*';
            $merged{$key} = $row->{$key};
        }

        if (exists $row->{'*'}) {
            croak "group child must be ARRAY ref" unless ref($row->{'*'}) eq 'ARRAY';
            push @out, @{ _expand_rows($row->{'*'}, $cols, \%merged) };
            next;
        }

        for my $key (@$cols) {
            croak "expand missing key: $key" unless exists $merged{$key};
            croak "expand undef value: $key" unless defined $merged{$key};
        }

        my %flat;
        @flat{@$cols} = @merged{@$cols};
        push @out, \%flat;
    }

    return \@out;
}

1;
