#!/bin/env bash
rm -rf cover_db/
PERL5OPT=-MDevel::Cover prove -Ilib -r t/
/home/clive/perl5/perlbrew/perls/perl-5.40.1/bin/perl \
    /home/clive/perl5/perlbrew/perls/perl-5.40.1/bin/cover
