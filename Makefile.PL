use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Bot::BasicBot::Pluggable::Module::TranslateBot',
    AUTHOR              => q{David Precious <davidp@preshweb.co.uk>},
    VERSION_FROM        => 'lib/Bot/BasicBot/Pluggable/Module/TranslateBot.pm',
    ABSTRACT_FROM       => 'lib/Bot/BasicBot/Pluggable/Module/TranslateBot.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Bot::BasicBot::Pluggable::Module' => 0,
        'Encode' => 0,
        'Lingua::Translate' => 0,
        'Lingua::Translate::Google' => 0,
        'I18N::LangTags::List' => 0,
        'HTML::Entities' => 0,
        'YAML' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Bot-BasicBot-Pluggable-TranslateBot-*' },
);
