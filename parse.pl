#!/usr/bin/perl -w
require "/home/lowk/bin/lowlib.pl";

my $TRUE = 1;
my $FALSE = 0;

my $parse_file = check_args(@ARGV);
# set defaults
# check command line arguments and set override defaults

my @emails = @servers = @ips = @logins = @groups = ();

my @lines = read_file(${parse_file});

my %users_list = get_users();

#print_array(@lines);

for my $line (@lines)
{
   @groups = get_groups($line, @groups);
# printf("%s\n", ${line});
   for my $word (split(/\s+/, ${line}))
   {
      if ( is_email(${word}) ) { push(@emails, ${word}); }
      if ( is_server(${word}) ) { push(@servers, ${word}); }
      if ( is_ip(${word}) ) { push(@ips, ${word}); }
      if ( is_login(${word}, %users_list) ) { push(@logins, ${word}); }
   }
}

#print_array(@emails);
#print_array(@servers);
#print_array(@ips);
#print_array(@logins);
#print_array(@groups);

create_file("emails", ${parse_file}, @emails);
create_file("servers", ${parse_file}, @servers);
create_file("ips", ${parse_file}, @ips);
create_file("logins", ${parse_file}, @logins);
create_file("groups", ${parse_file}, @groups);
# backup and output files

sub get_groups
{
   my ($line, @groups) = @_;
   if ( $line =~ m/\S*group\S*\s+(\S+)/i )
   {
      push(@groups, $1);
   }
   return(@groups);
}



sub create_file
{
   my ($filename, $extension, @contents) = @{_};
   unless ( @contents )
   {
      return();
   }
   my $fn = "${filename}.${extension}";
   if ( -e ${fn} )
   {
      my $ts = get_timestamp();
      rename(${fn}, "${fn}.${ts}");
   }
   open(FILE, ">${fn}") or die("Couldn't open ${fn}\n");
   foreach my $line (@contents)
   {
      printf(FILE "${line}\n");
   }
   close(FILE);
}


sub check_args
{
   my @ARGV = @_;
   my $filename = "summary";
   if ( $#ARGV > 0 )
   {
      printf("\nUsage: %s PARSE_FILE (optional) [default file \"summary\" ]\n\n", ${0});
      exit();
   }
   elsif ( $#ARGV == 0 )
   {
      ${filename} = shift(@ARGV);
   }
   return ${filename};
}

sub get_logins
{
   my @users = @_;
   my %login_lists = ();
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

sub get_users
{
   my @users_linux = `/usr/local/ldap/bin/ldap_user_query.pl \\* linux`;
   my @users_aix = `/usr/local/ldap/bin/ldap_user_query.pl \\* aix`;
   my @users_solaris = `/usr/local/ldap/bin/ldap_user_query.pl \\* solaris`;
   my %users_linux  = get_logins(@users_linux);
   my %users_aix  = get_logins(@users_aix);
   my %users_solaris  = get_logins(@users_solaris);

   my %users_list = (%users_linux, %users_aix, %users_solaris);

   return %users_list;
}

# login - check ldap
sub is_login
{
   my ($word, %users_list) = @_;
   if( $users_list{${word}} )
   {
      return ${TRUE};
   }
   return ${FALSE};
}

# ip address
sub is_ip
{
   my ($word) = @{_};
   if ( ${word} =~ m/^(\d{1,3}\.){3}\d{1,3}/ ) { return $TRUE; }
   return ${FALSE};
}

# server dc1 dc2 cdl # ping string
sub is_server
{
   my ($word) = @{_};
   if ( ${word} =~m/^(cdl)|(dc1)|(dc2)/i ) { return $TRUE; }
   return ${FALSE};
}

# email @adp.com
sub is_email
{
   my ($word) = @{_};
   if ( ${word} =~ m/\@adp.com/i ) { return $TRUE; }
   return ${FALSE};
}

# group
