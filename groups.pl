#!//usr/bin/perl

use warnings;
require '/home/lowk/bin/lowlib.pl';

my @DISTROS = ('linux','aix','solaris');
my %groups_list = get_groups(@DISTROS);

for my $key (keys(%groups_list))
{
   print("$key\n");
}
#my %users_list = get_users(@DISTROS);


sub get_logins
{
   my @users = @_;
   my %logins_list = ();
   for my $line (@users)
   {
      if ( ${line} =~ m/ uid:\s+(\S+)/ )
      {
         my $login = ${1};
         $logins_list{$login} = 1;
      }
   }
   return %logins_list;
}

sub get_group_names
{
   my @groups = @_;
   my %groups_list = ();
   for my $line (@groups)
   {
      if ( ${line} =~ m/dn:cn=([^,]+),/ )
      {
         my $group = ${1};
         $groups_list{$group} = 1;
      }
   }
   return %groups_list;
}

sub get_groups
{
   my (@distros) = @_;
   my %groupss_list = ();
   for my $os (@distros)
   {
      my @groups = `/usr/local/ldap/bin/ldap_group_query.pl \\* ${os}`;
      my %groups = get_group_names(@groups);
      %groups_list = (%groups_list, %groups);
   }
   return(%groups_list);
}

sub get_users
{
   my (@distros) = @_;
   my %users_list = ();
   for my $os (@distros)
   {
      my @users = `/usr/local/ldap/bin/ldap_user_query.pl \\* ${os}`;
      my %users = get_logins(@users);
      %users_list = (%users_list, %users);
   }
   return(%users_list);
}

sub remove_tail
{
   my ($word) = @_;
   ${word} =~ s/[.,:]$//; 
   print("$word\n");
   return $word;
}

