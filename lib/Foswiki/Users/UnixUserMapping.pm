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

=begin pod

---+ package Foswiki::Users::UnixUserMapping

=cut

package Foswiki::Users::UnixUserMapping;
use base qw( Foswiki::Users::TopicUserMapping );
use strict;
use Foswiki::ListIterator;
use Foswiki::Contrib::UnixUsersContrib;
use Authen::Simple::PAM;
use Error qw( :try );

sub debug {
    print STDERR "# $_[0]\n";
}

=pod

---++ ClassMethod new($session) -> $object

Constructs a new password handler of this type, referring to $session
for any required Foswiki services.

=cut

sub new {
    my ($class, $session) = @_;
    my $this = bless($class->SUPER::new($session, 'UnixUserMapping_'), $class);
    $this->{mapping_id} = 'UnixUserMapping_';
    $this->{error} = undef;

    my %groups = map { $_ => {
          wikiname => Foswiki::Contrib::UnixUsersContrib::camelize($_) . 'Group',
       } } $this->unixGroups();
    $this->{groups} = \%groups;

    return $this;
}

=begin pod

---++ ObjectMethod finish()

Break circular references.

Note to developers; please undef *all* fields in the object explicitly,
whether they are references or not. That way this method is "golden
documentation" of the live fields in the object.

=cut

sub finish {
    my $this = shift;
    Foswiki::Contrib::UnixUsersContrib::finish();
    $this->{groups} = undef;
    $this->SUPER::finish();
    return;
}

=pod

---++ ObjectMethod supportsRegistration() -> $boolean

Return true if the UserMapper supports registration (ie can create new users)

Default is *false*

=cut

sub supportsRegistration {
    return 0;
}

=begin pod

---++ ObjectMethod handlesUser($cUID, $login, $wikiname) -> $boolean

Called by the Foswiki::Users object to determine which loaded mapping
to use for a given user (must be fast).

=cut

sub handlesUser {
    my ($this, $cUID, $login, $wikiname) = @_;
    debug "handlesUser($cUID, $login, $wikiname)";
    return 1 if ( defined $cUID && $cUID =~ /$this->{mapping_id}.*/ );
    return 1 if ( $cUID     && $this->login2cUID($cUID) );
    return 1 if ( $login    && $this->login2cUID($login) );
    return 1 if ( $wikiname && $this->findUserByWikiName($wikiname) );
    return 0;
}

=pod

---++ ObjectMethod getLoginName($cUID) -> login

Converts an internal cUID to that user's login
(undef on failure)

Subclasses *must* implement this method.

=cut

sub getLoginName {
    my ($this, $user) = @_;
    debug "getLoginName($user)";
    return $this->canonical2login($user);
}

=pod

---++ ObjectMethod addUser($login, $wikiname, $password, $emails) -> cUID

UnixUserMapping does not allow creation of users.

=cut

sub addUser {
    throw Error::Simple('UnixUserMapping does not allow creation of users ');
    return 0;
}

=pod

---++ ObjectMethod removeUser($user) -> $boolean

UnixUserMapping does not allow removeal of users.

=cut

sub removeUser {
    throw Error::Simple('UnixUserMapping does not allow removeal of users ');
    return 0;
}

=pod

---++ ObjectMethod getWikiName($cUID) -> wikiname

Map a canonical user name to a wikiname.

Returns the $cUID by default.

The WikiName of an unix user is its Full Name in camel case mode. In the
example below the WikiName of joao is "JoaoSilva".

# getent passwd joao
joao:x:1003:1004:Joao Silva,,,:/home/joao:/bin/bash

=cut

sub getWikiName {
    my ($this, $user) = @_;
    $user =~ s/^$this->{mapping_id}//;
    chomp $user;
    debug "getWikiName($user)";

    #TODO (see Taint mode)
    $user =~ m/(\S+)/; $user = $1;
    $ENV{PATH} =~ m/(.+)/; $ENV{PATH} = $1;
    my $pipe = Foswiki::Contrib::UnixUsersContrib::openPipe(qw(getent passwd), $user);
    my $output = <$pipe>;
    close $pipe;
    if ($output && $output =~ m/[\S]+:x:(?<uid>\d+):(?<gid>\d+):(?<fullname>[^,]+),[^,]*,[^,]*,:[^,]*:[^,]*/) {
        #Make sure we're in 'ok' Wiki word territory
        (my $wikiname = $+{fullname}) =~ s/[^\w]+(\w)/uc($1)/ge;
        return ucfirst($wikiname);
    }
    else {
        return $user;
    }
}

=pod

---++ ObjectMethod eachGroupMember($group) -> Foswiki::ListIterator of cUIDs

Called from Foswiki::Users. See the documentation of the corresponding
method in that module for details.

If $group is a Unix Group then returns users members of that group.

Unix users should have "Full Name", it will be used to calculate the WikiName.

Subclasses *must* implement this method.

=cut

sub eachGroupMember {
    my ($this, $group) = @_;
    debug "eachGroupMember($group)";
    (my $unix_group) = grep { $this->{groups}{$_}{wikiname} eq $group } $this->unixGroups();
    if ($unix_group) {
       if (defined $this->{groups}{$unix_group}{members}) {
          return new Foswiki::ListIterator($this->{groups}{$unix_group}{members});
       }
       else {
          my $members = [];
          my $pipe = Foswiki::Contrib::UnixUsersContrib::openPipe(qw(getent group), $unix_group);
          (my $output = <$pipe>) =~ s/$unix_group:x:\d+://;
          foreach (grep {$_ =~ /\S/} split( /,/, $output)) {
             push @{$members}, $this->{mapping_id} . $_;
          }
          close $pipe;
          $this->{groups}{$unix_group}{members} = $members;
          return new Foswiki::ListIterator($members);
       }
    }
    else {
       return $this->SUPER::eachGroupMember($group, {expand => 0});
    }
}

=pod

---++ ObjectMethod eachGroup() -> ListIterator of groupnames

Called from Foswiki::Users. See the documentation of the corresponding
method in that module for details.

Get all unix groups that match with cfg "GroupFilter", by default match all
unix groups "*_group", like admins_group, users_group, etc.

Subclasses *must* implement this method.

=cut

sub eachGroup {
    my ($this) = @_;
    debug "eachGroup()";

    # TopicUserMapping get groups defined in Foswiki
    $this->SUPER::_getListOfGroups(1);

    # UnixUserMapping get all unix groups with name *_group (like admins_group)
    foreach (keys %{ $this->{groups} }) {
        push @{ $this->{groupsList} }, $this->{groups}{$_}{wikiname};
    }

    return new Foswiki::ListIterator( \@{ $this->{groupsList} } );
}

=pod

---++ ObjectMethod isInGroup($user, $group, $scanning) -> bool

Called from Foswiki::Users. See the documentation of the corresponding
method in that module for details.

Default is *false*

=cut

sub isInGroup {
    my ($this, $user, $group) = @_;
    debug "isInGroup($user, $group)";
    my @users;
    my $it = $this->eachGroupMember($group);
    while ($it->hasNext()) {
        my $u = $this->getWikiName($it->next());
        return 1 if $u eq $user;
        if ($this->isGroup($u)) {
            return 1 if $this->isInGroup($user, $u);
        }
    }
    return 0;
}

=pod

---++ ObjectMethod checkPassword($userName, $passwordU) -> $boolean

Finds if the password is valid for the given user.

Uses PAM to authenticate user, it is necessary to the webserver user have
read acces to /etc/shadow, in Debian system you can do:

   # adduser www-data shadow

Returns 1 on success, undef on failure.

Default behaviour is to return 1.

=cut

sub checkPassword {
    my ($this, $user, $password) = @_;
    $user = $this->canonical2login($user);
    debug "checkPassword($user, $password)";
    my $pam = Authen::Simple::PAM->new(service => 'login');
    if ($pam->authenticate($user, $password)) {
        debug "checkPassword: success!";
        return 1;
    }
    else {
        debug "checkPassword: fail!";
        $this->{error} = 'Invalid user/password';
        return;
    }
}

=pod

---++ ObjectMethod setPassword($user, $newPassU, $oldPassU) -> $boolean

UnixUserMapper does not change user passwords using.

=cut

sub setPassword {
    throw Error::Simple('Cannot change user passwords using UnixUserMapper');
    return 0;
}

=pod

---++ ObjectMethod passwordError() -> $string

Returns a string indicating the error that happened in the password handlers
TODO: these delayed errors should be replaced with Exceptions.

returns undef if no error (the default)

=cut

sub passwordError {
    my $this = shift;
    return $this->{error};
}

=pod

---++ ObjectMethod canonical2login($user) -> $string

Convert a canonical user name to the corresponding login name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.

Ex.: WikiUser -> Wiki User

return $user if couldn't convert (the default)

=cut

sub canonical2login {
    my ($this, $user) = @_;
    debug "canonical2login($user)";
    $user =~ s/^$this->{mapping_id}//;
    (my $fullname = $user) =~ s/(\S)([[:upper:]])/$1 $2/g;
    my $pipe = Foswiki::Contrib::UnixUsersContrib::openPipe(qw(getent passwd));
    while (<$pipe>) {
        if (m/(?<name>[\S]+):x:(?<uid>\d+):(?<gid>\d+):$fullname,[^,]*,[^,]*,:[^,]*:[^,]*/) {
            $user = $+{name};
        }
    }
    close $pipe;
    return $user;
}

=pod

---++ ObjectMethod unixGroups() -> @groups

Fetch all unix groups that match with "GroupFilter" configuration:

   * $Foswiki::cfg{UnixUsersContrib}{GroupFilter} = '^wiki';

By default all groups starting with "wiki" (ex: wikiadmins, wikiusers) will be
fetched. These group names will be converted to WikiName like WikiadminsGroup.

Ex.: wikiadmins -> WikiadminsGroup

=cut

sub unixGroups {
    my $this = shift;
    return keys %{ $this->{groups} } if $this->{groups};
    debug "unixGroups()";
    my $filter = $Foswiki::cfg{UnixUsersContrib}{GroupFilter} || '_group$';
    my @groups = ();
    my $pipe = Foswiki::Contrib::UnixUsersContrib::openPipe(qw(/usr/bin/getent group));
    while (<$pipe>) {
        s/^(\S+):x:\d+:.*$/$1/e;
        next unless m/$filter/;
        chomp;
        push @groups, $_;
    }
    close $pipe;
    return @groups;
}

=begin pod

---++ ObjectMethod login2cUID($login, $dontcheck) -> cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

(if dontcheck is true, return a cUID for a nonexistant user too - used for registration)

Subclasses *must* implement this method.

=cut

sub login2cUID {
    my ($this, $login, $dontcheck) = @_;
    debug "login2cUID($login)";
    #we ignore $dontcheck as this mapper does not do registration.
    return $this->getWikiName($login);
}

1;
