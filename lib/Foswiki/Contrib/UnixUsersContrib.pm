# Module of Foswiki Collaboration Platform, http://Foswiki.org/
#
# Copyright (C) 2012 Joenio Costa, joenio@perl.org.br
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

package Foswiki::Contrib::UnixUsersContrib;
use vars qw( $VERSION );
$VERSION = '0.1.0';
use strict;

=pod

---++ ClassMethod openPipe($string) -> $pipe

Run command-line in $string and return pipe.

=cut

sub openPipe {
    my @command_line = @_;
    open my $PIPE, "-|", @command_line;
    return $PIPE;
}

=begin pod

---++ ClassMethod finish()

Do nothing.

=cut

sub finish {
    return;
}

=begin pod

---++ ClassMethod camelize($string) -> $string

admins_group -> AdminsGroup

=cut

sub camelize {
    my $string = shift;
    $string =~ s/^(\S)|_(\S)/uc($1||$2)/ge;
    return $string;
}

=begin pod

---++ ClassMethod decamelize($string) -> $string

AdminsGroup -> admins_group

=cut

sub decamelize {
    my $string = shift;
    $string =~ s/(\S)([[:upper:]])/$1_$2/g;
    return lc $string;
}

1;
