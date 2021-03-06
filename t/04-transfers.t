use Test::Modern;
use t::lib::Common qw(:constants skip_unless_has_secret stripe);
use JSON qw(from_json);

skip_unless_has_secret;

my $account = stripe->create_account({
    managed => 'true',
    country => 'CA',
});
my $bank = stripe->add_bank(
    {
        'bank_account[country]'        => 'CA',
        'bank_account[currency]'       => 'cad',
        'bank_account[routing_number]' => STRIPE_BANK_US_ROUTING_NO,
        'bank_account[account_number]' => STRIPE_BANK_ACCOUNT,
    },
    account_id => $account->{id},
);
cmp_deeply $bank => TD->superhashof({ last4 => 6789 }), 'created bank';

subtest 'create a transfer and do stuff with it' => sub {
    my $transfer = stripe->create_transfer({
        amount      => 100,
        currency    => 'cad',
        destination => $account->{id},
    });
    cmp_deeply $transfer => TD->superhashof({
        id     => TD->re('^tr_'),
        amount => 100,
    });
    my $transfer_id = $transfer->{id};

    $transfer = stripe->update_transfer($transfer->{id}, data => {
        'metadata[foo]' => 'bar'
    });
    is $transfer->{id} => $transfer_id;

    $transfer = stripe->get_transfer($transfer->{id});
    cmp_deeply $transfer => TD->superhashof({
        id       => $transfer_id,
        amount   => 100,
        metadata => { foo => 'bar' },
    });

    my $exc = exception { stripe->cancel_transfer($transfer->{id}) };
    is $exc->code => 400;
};

subtest 'list transfers' => sub {
    my $transfers = stripe->get_transfers;
    ok $transfers->{data}[0]{amount};
};

done_testing;
