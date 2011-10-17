#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Bot::BasicBot::Pluggable::TranslateBot' );
}

diag( "Testing Bot::BasicBot::Pluggable::TranslateBot $Bot::BasicBot::Pluggable::TranslateBot::VERSION, Perl $], $^X" );
