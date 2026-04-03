use v5.40;
use Test2::V0;
use lib 'lib';
use Query::Builder;

subtest 'simple select' => sub {
    my $qb = Query::Builder->new(dialect => 'sqlite');
    my $select =
        $qb->select(qw(id customer_id date amount))
            ->with(
                $qb->select(qw(company_id company_name))
                    ->from('companies')
                    ->as('c'),
                $qb->select()
                    ->columns(qw(company_id contact))
                    ->from('contacts')
                    ->as('contacts'))
            ->from('invoices AS i')
            ->joins(
                'JOIN c USING (company_id)',
                $qb->join(contacts => using => 'company_id') )
            ->where($qb->compare(date => '2026-01-01', comparator => '>'));
    is $select, 'WITH ( SELECT company_id, company_name FROM companies ) AS c, ( SELECT company_id, contact FROM contacts ) AS contacts SELECT id, customer_id, date, amount FROM invoices AS i WHERE date > ?', 'select generated';
    is [$select->params()], ['2026-01-01'], 'params generated';
};

done_testing();
