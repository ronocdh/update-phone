package Adb;
use strict;
use warnings;
use feature 'say';
use Moose;

my $verbose;
has 'running',    is => 'rw', isa => 'Bool', default => 0,     required => 1;
has 'adb_binary', is => 'rw', isa => 'Str',  default => 'adb', required => 1;
has 'autostart',  is => 'ro', isa => 'Bool', default => 0,     required => 1;
has 'verbose',    is => 'rw', isa => 'Bool', default => 1,     required => 1;

sub BUILD {    # initialize object before returning;
    my $self = shift;

    system( "which adb >/dev/null" ) == 0
      or die <<'MESSAGE';
Could not find 'adb' executable in \$PATH.
You can set a fullpath to the adb binary on your system
via the 'adb_binary' option, e.g.:

    my $adb = Adb->new( 
    { 
        adb_binary => '/usr/local/bin/android-sdk-linux/platform-tools/adb',
    });
MESSAGE

    $self->start if $self->autostart;
    $verbose = $self->verbose;

    return $self;    # pass back initialized object to caller;
}

sub reboot {         # restart the device via adb;
    my $self = shift;           # unpack class object from caller;
    my $mode = shift || q{};    # unpack optional reboot mode;

    my $message = "Rebooting phone";
    if ( $mode ) {              # if caller provided a mode for rebooting;
        my %supported_modes = map { $_ => 1 } qw/bootloader recovery/;    # declare possible rebooting options;
        return unless exists $supported_modes{ $mode };                   # return failure if mode not recognized;
        $message .= " (in $mode mode)";                                   # specify special mode;
    }

    say $message . '...' if $verbose;                                     # chatty output;

    return system( $self->adb, 'reboot', $mode ) == 0;                    # shell out to reboot via adb;
}

sub start {                                                               # fire up the Android SDK's Android Debugging Bridge (adb) server;
    my $self = shift;                                                     # unpack class object from caller;
    return if $self->running;                                             # don't bother starting server if it's already running;

    say "Trying to run adb now (you may be prompted for privileges)..." if $verbose;

    system( "sudo adb -d start-server >/dev/null" ) == 0 or return;       # shell out to start adb server;
    return $self->running( 1 );                                           # set 'running' to True;
}

sub sideload {                                                            # push flashable image file, in ZIP format, to device;
    my $self = shift;                                                     # unpack class object from caller;
    my $image_file = shift or return;
    return unless ( $self->running and -e $image_file );                  # don't bother trying to push image if server isn't running;

    say "Pushing image file to phone... " if $verbose;

    return system( "sudo adb -d sideload '$image_file' >/dev/null" ) == 0;    # shell out to start adb server;
}

sub stop {                                                                    # fire up the Android SDK's Android Debugging Bridge (adb) server;
    my $self = shift;                                                         # unpack class object from caller;
    say "Stopping adb server... " if $verbose;                                # chatty output;
    return unless $self->running;                                             # don't bother stopping server if it's not running;

    system( "sudo adb -d kill-server >/dev/null" ) == 0 or return;            # shell out to stop adb server;
    return $self->running( 0 );                                               # set 'running' to False;
}

sub devices {                                                                 # find attached devices;
    my $self = shift;                                                         # unpack class object from caller;
    $self->start unless $self->running;

    my @devices = `sudo adb devices`;
    shift @devices;                                                           # throw away first line, which is just headers;
    chomp @devices;                                                           # remove pesky trailing newlines from items;
    say "Found these devices: @devices";
}

1;
