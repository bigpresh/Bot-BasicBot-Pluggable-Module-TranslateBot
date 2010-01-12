
# $Id$

package Bot::BasicBot::Pluggable::Module::TranslateBot;
use strict;
use Bot::BasicBot::Pluggable::Module;
use base 'Bot::BasicBot::Pluggable::Module';
use Encode;
use Lingua::Translate;
use Lingua::Translate::Google;
use I18N::LangTags::List;
use HTML::Entities;
use YAML;

my $config = YAML::LoadFile($ENV{HOME} . '/.translatebot')
    or die "Failed to read config file ~/.translatebot";

Lingua::Translate::config (
    back_end => 'Google',
    api_key  => $config->{api_key},
    referer  => $config->{referer} || $config->{referrer},
);


sub init {
    my $self = shift;
    # Find out from Google which languages we can support:
    my $gt = Lingua::Translate::Google->new(src => 'en', dest => 'en');
    my %languages;
    for my $lang_pair ($gt->available) {
    $languages{$_} = I18N::LangTags::List::name($_) || 'Unknown'
        for split '_', $lang_pair;
    }
    $self->{translate}{languages} = \%languages;
    $self->{translate}{lang_list} =
        join ', ', map { "$_ ($languages{$_})" } sort keys %languages;

}

sub help {
    my $self = shift;
    my $idtxt = '$Id$';
    my $lang_list = $self->{translate}{lang_list};
    <<HELP
Translate text to/from given languages.
You can translate directly with: 'translate <phrase> from <lang> to <lang>'

For example: translate This is a test of the bot from en to es

You can also instruct the bot to automatically translate everything a given
user says - to do that, say to the bot:
  - 'start translating for <nick> from <lang> to <lang>'
  - 'stop translating for <nick>' (to stop translating for a user)
  - 'stop translating' (this will stop all automatic translations)

Naturally, exclude the quotation marks, and the angle brackets show where you
should insert approprate text (don't include those, either).  Where a nick is
expected, you can also just say "me", to refer to yourself.

<lang> can be any one of:
$lang_list

This is: $idtxt
HELP
}


sub told {
    my ($self, $mess) = @_;
    my $body = $mess->{body};
    return if !$body;

    # if we've been told to translate something, do it:
    if ($body =~ m{ ^ \s*
            translate \s+ (?<phrase> .+ )
            \s+ from \s+ (?<from> \S+)
            \s+ (in)?to \s+ (?<to> \S+)
        }xi)
    {
        return $self->_translate(@+{qw(phrase from to)});
    } elsif ($body =~ m{^ \s* start \s+ translating \s+ for \s+ (?<nick> \S+)
        \s+ from \s+ (?<from> \S+ ) \s+ (in)?to \s+ (?<to> \S+ )}xi)
    {
        my $nick = $+{nick} eq 'me' ? $mess->{who} : $+{nick};
        $self->{_translate}{auto}{$mess->{channel}}{$nick} =
            { from => $+{from}, to => $+{to} };
        return "OK, I'll translate everything $nick says until you "
            . " say 'stop translating for $+{nick}'";

    } elsif ($body =~
        m{^ \s* stop \s+ translating \s+ for \s+ (?<nick> \S+)}xi)
    {
        my $nick = $+{nick} eq 'me' ? $mess->{who} : $+{nick};
        if (delete $self->{_translate}{auto}{$mess->{channel}}{$nick}) {
            return "OK, no longer translating for $nick";
        } else {
            return "I wasn't translating for $nick.";
        }
    } elsif ($body =~ m{ \s* stop \s+ translating \s* $}xi) {
        delete $self->{_translate}{auto};
        return "OK, any automatic translations have been removed.";
    }

    if (my $translating =
        $self->{_translate}{auto}{$mess->{channel}}{ $mess->{who} })
    {
        my $translation = $self->_translate(
            $mess->{body}, @$translating{ qw(from to) }
        );
        if ($translation) {
            return "$mess->{who} said: '$translation'";
        } else {
            return "Failed to translate what $mess->{who} said, sorry.";
        }
    }
}


# TODO: cache Lingua::Translate objects
sub _translate {
    my ($self, $phrase, $from, $to) = @_;
    warn "Translating '$phrase' from '$from' to '$to'";
    for ($from,$to) {
        lc $_;
        if (!$self->{translate}{languages}{$_}) {
            warn "Unknown language $_";
            return "Unrecognised language code $_";
        }
    }
    my $lt = Lingua::Translate->new(src => $from, dest => $to);
    if (!$lt) {
        warn "No Lingua::Translate object to translate $from -> $to";
        return;
    }
    my $translation = decode_utf8($lt->translate($phrase));
    if ($translation) {
        warn "Translated to $translation";
        return HTML::Entities::decode_entities($translation);
    } else {
        return;
    }
}

1;
__END__
