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

The code for this bot module is available on GitHub:
https://github.com/bigpresh/Bot-BasicBot-Pluggable-Module-TranslateBot
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
            return "Unrecognised language code $_\n"
                . "The following language codes are available: " 
                . join(', ', keys %{ $self->{translate}{languages} }) . "\n"
                . "(/msg the bot with 'help translatebot' for a list with"
                . " language names - too long to show here!\n";
        }
    }
    my $lt = Lingua::Translate->new(src => $from, dest => $to);
    if (!$lt) {
        warn "No Lingua::Translate object to translate $from -> $to";
        return;
    }

    # If the message contains channel names, Google will try to translate them.
    # We don't want that.  Replace all channel names with numeric placeholders,
    # which we can change back after translation...
    my %placeholders;
    $phrase =~ s{(#{1,2}\S+)}
                {
                    my $token = join '', map { int rand 10 } 0..6;
                    $placeholders{$token} = $1;
                    "ctoken$token";
                }ge;

    my $phrase = HTML::Entities::encode_entities($phrase);
    my $translation = 
        Encode::decode_utf8(HTML::Entities::decode_entities($lt->translate($phrase)));
    if (!$translation) {
        warn "No translation";
        return;
    }

    warn "Translated to $translation";
    
    # Now, look for any channel name tokens we added earlier, and replace them
    # with the original channel name:
    $translation =~ s{ctoken(\d+)}{$placeholders{$1}}ge;

    warn "Translation after replacing tokens: $translation";
    return $translation;
}



1;
__END__

=head1 NAME

Bot::BasicBot::Pluggable::Module::TranslateBot - automatic translations on IRC using Google Translate


=head1 DESCRIPTION

A module for L<Bot::BasicBot::Pluggable>-powered IRC bots to provide automated
translations on IRC.

Allows one-off translations of text, and, usefully, can also be told to
automatically translate everything a user says into a specified language until
told otherwise, making it easier to have a conversation with another user when
there's no common language (subject, of course, to the vaguaries of Google
Translate's automatic translations; it will work best if you use more formal
language and avoid colloquialisms).




=head1 USAGE

Load the module as you would any other L<Bot::BasicBot::Pluggable> module, then,
on IRC, use the following commands:

=head2 Quick one-off translations

You can translate directly with: 

    translate <phrase> from <lang> to <lang>

For example:

    < bigpresh> translate This is a test of the bot from en to es
    < translatebot> Esta es una prueba de que el robot


You can also instruct the bot to automatically translate everything a given
user says until you tell it to stop - to start automatic translations, say:

    start translating for <nick> from <lang> to <lang>

(C<nick> can be your nick or the nick of another user in the channel, or C<me>
to mean your own nick)

For example:

    < bigpresh> start translating for me from en to es
    < translatebot> +OK, I'll translate everything bigpresh says 
        until you say 'stop translating for me'
    < bigpresh> This is another test.
    < translatebot> bigpresh said: 'Esta es otra prueba.'

To stop automatic translations for yourself or another user:

    stop translating for <nick>

To stop all automatic translations: 

    stop translating

In the examples above, C<<lang>> can be any one of the language codes supported
by Google Translate; the bot will determine this at runtime (via
L<Lingua::Translate::Google>).  The list will be included in the help message
presented by the bot (C</msg> the bot with C<help translatebot>).


=head1 AUTHOR

David Precious C<<davidp@preshweb.co.uk>>



