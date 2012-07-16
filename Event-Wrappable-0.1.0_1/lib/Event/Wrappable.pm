# ABSTRACT: Sugar to let you instrument event listeners at a distance
package Event::Wrappable;
{
  $Event::Wrappable::VERSION = '0.1.0_1';
}
use strict;
use warnings;
use Scalar::Util qw( refaddr weaken );
use Sub::Exporter -setup => {
    exports => [qw( event )],
    groups => { default => [qw( event )] },
    };
use Sub::Clone qw( clone_sub );

our %INSTANCES;

our @EVENT_WRAPPERS;


sub add_event_wrapper {
    my( $wrapper ) = @_[1..$#_];
    push @EVENT_WRAPPERS, $wrapper;
    return $wrapper;
}


sub remove_event_wrapper {
    my( $wrapper ) = @_[1..$#_];
    @EVENT_WRAPPERS = grep { $_ != $wrapper } @EVENT_WRAPPERS;
    return;
}

my $LAST_ID;

sub new {
    my $class = shift;
    my( $event, $raw_event ) = @_;
    bless $event, $class;
    my $storage = $INSTANCES{refaddr $event} = {};
    weaken( $storage->{'wrapped'} = $event );
    weaken( $storage->{'base'}    = $raw_event );
    $storage->{'wrappers'} = [ @EVENT_WRAPPERS ];
    $storage->{'id'} = ++ $LAST_ID;
    return $event;
}


sub event(&) {
    my( $raw_event ) = @_;
    my $event = clone_sub $raw_event;
    if ( @EVENT_WRAPPERS ) {
        for (reverse @EVENT_WRAPPERS) {
            $event = $_->($event);
        }
    }
    return __PACKAGE__->new( $event, $raw_event );
}

sub wrap_events {
    my $class = shift;
    my( $todo, @wrappers ) = @_;
    local @EVENT_WRAPPERS = ( @EVENT_WRAPPERS, @wrappers );
    $todo->();
}

sub get_unwrapped {
    my $self = shift;
    return $INSTANCES{refaddr $self}->{'base'};
}

sub get_wrappers {
    my $self = shift;
    my $wrappers = ref $self
                 ? $INSTANCES{refaddr $self}->{'wrappers'}
                 : \@EVENT_WRAPPERS;
    return wantarray ? @$wrappers : $wrappers;
}

sub object_id {
    my $self = shift;
    return $INSTANCES{refaddr $self}->{'id'};
}

sub DESTROY {
    my $self = shift;
    delete $INSTANCES{refaddr $self};
}

sub CLONE {
    my $self = shift;
    foreach (keys %INSTANCES) {
        my $object = $INSTANCES{$_}{'wrapped'};
        $INSTANCES{refaddr $object} = $INSTANCES{$_};
        delete $INSTANCES{$_};
    }
}

1;

__END__
=pod

=encoding utf-8

=head1 NAME

Event::Wrappable - Sugar to let you instrument event listeners at a distance

=head1 VERSION

version 0.1.0_1

=head1 SYNOPSIS

    use Event::Wrappable;
    use AnyEvent;
    use EV;
    my $wrapper = Event::Wrappable->add_event_wrapper( sub {
        my( $event ) = @_;
        return sub { say "Calling event..."; $event->(); say "Done with event" };
        } );
    my $w = AE::timer 1, 0, event { say "First timer triggered" };
    Event::Wrappable->remove_event_wrapper($wrapper);
    my $w2 = AE::timer 2, 0, event { say "Second timer triggered" };
    EV::loop;

    # Will print:
    #     Calling event...
    #     First timer triggered
    #     Done with event
    #     Second timer triggered

=head1 DESCRIPTION

This is a helper for creating globally wrapped events listeners.  This is a
way of augmenting all of the event listeners registered during a period of
time.  See L<AnyEvent::Collect> and L<MooseX::Event> for examples of its
use.  A lexically scoped variant might be desirable, however I'll have to
explore the implications of that for my own use cases first.

=head1 CLASS METHODS

=head2 method add_event_wrapper( CodeRef $wrapper ) returns CodeRef

Wrappers are called in reverse declaration order.  They take a the event
to be added as an argument, and return a wrapped event.

=head2 method remove_event_wrapper( CodeRef $wrapper )

Removes a previously added event wrapper.

=head2 method wrap_events( CodeRef $code, @wrappers )

Adds @wrappers to the event wrapper list for the duration of $code.

   Event::Wrappable->wrap_events(sub { setup_some_events() }, sub { wrapper() });

=head2 method get_wrappers() returns Array|ArrayRef

In list context returns an array of the current event wrappers.  In scalar
context returns an arrayref of the wrappers used on this event.

=head1 METHODS

=head2 method get_unwrapped() returns CodeRef

Returns the original, unwrapped event handler from the wrapped version.

=head2 method get_wrappers() returns Array|ArrayRef

In list context returns an array of the wrappers used on this event.  In
scalar context returns an arrayref of the wrappers used on this event.

=head2 method object_id() returns Int

Returns an invariant unique identifier for this event.  This will not change
even across threads and is suitable for hashing based on an event.

=head1 HELPERS

=head2 sub event( CodeRef $code ) returns CodeRef

Returns the wrapped code ref, to be passed to be an event listener.  This
code ref will be blessed as Event::Wrappable.

=for test_synopsis use v5.10.0;

=head1 SOURCE

The development version is on github at L<http://https://github.com/iarna/Event-Wrappable>
and may be cloned from L<git://https://github.com/iarna/Event-Wrappable.git>

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<http://metacpan.org/release/Event-Wrappable>

=back

=head2 Bugs / Feature Requests

Please report any bugs at L<https://github.com/iarna/Event-Wrappable/issues>.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/iarna/Event-Wrappable>

  git clone https://github.com/iarna/Event-Wrappable.git

=head1 AUTHOR

Rebecca Turner <becca@referencethis.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Rebecca Turner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT
WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER
PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE
SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME
THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE
TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

=cut

