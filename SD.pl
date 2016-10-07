#!/usr/bin/perl -w
#	1-0	First functional version from SD.10
#	1-1	is_server,  added previous word check, ignore words and atleast one character after datacenter label
#	1-2	added dc6 to is_server sub, work on using aquery file for server name detection
#	1-3	remove_tail implemented to remove trailing [.,:] from server names
#	#	need to add Parent field for info
#	future	state files. cleanup ( keep # of old export files, prune back just new cases)
#		validate export file is valid,  get ldap group/netgroup names
use English qw( -no_match_vars );
use Carp; 
use File::Basename;
use File::Copy;
use strict;
require '/home/lowk/bin/lowlib.pl';
my $TRUE = 1;
my $FALSE = 0;

my $BASE = '/home/lowk';
my $CASES = ${BASE} . '/dev/cases';
my $AUDIT = ${BASE} . '/dev/log';
my $AUDIT_FILE = ${AUDIT} . '/case_audit.log';
my $export_file=figure_export_file(@ARGV);
print("\nEXPORT FILE ${export_file}\n");
my @export = read_file($export_file);

my %info = get_info();		# get Title, Author & Created TS
my @header = get_header();	# parse out header row
my %tickets = parse_tickets(@header);		# parse tickets from export
my $total_tickets = keys(%tickets);
print("CASES: \t${total_tickets}\t");
my @new_cases = create_cases($CASES, %tickets);
my $number_of_new_cases = @new_cases;
if ($number_of_new_cases > 0)
   { bulk_parse(@new_cases); }
audit_report(@new_cases);


### End MAIN

sub get_greatest_audit_index
{
   my ($audit_file) = @_;
   my $greatest_index = 0;
   if ( -e ${audit_file} )
   {
      my @audit = read_file(${audit_file});
      my $cur_index = 0;
      foreach my $line (@audit)
      {
         if ( $line =~ /^(\d*),/ )
         {
            $cur_index=int($1);
            if ( ${cur_index} > ${greatest_index} )
               { $greatest_index=$cur_index; }
         }
      }
   }
   else
      { print("\nNo audit file: $audit_file\n"); }
   return(${greatest_index});
}

sub get_greatest_file_index
{
   my ($log_dir) = @_;
   my $regx = qr/\.(\d+)$/;
   my $greatest_index = 0;
   opendir(DIR, ${log_dir}) or croak("\nCould not open $log_dir $!\n");
   while(defined(my $file = readdir(DIR)))
   {
      my $cur_index = 0;
      if ( ${file} =~ $regx )
         { $cur_index=int($1); }
      if ( ${cur_index} > ${greatest_index} )
         { $greatest_index=$cur_index; }
   }
   closedir(DIR);
   return(${greatest_index});
}

sub get_index
{
   my $greatest_file_index = get_greatest_file_index(${AUDIT});
   my $greatest_audit_index = get_greatest_audit_index(${AUDIT_FILE});
   if ( $greatest_file_index == $greatest_audit_index )
      { return($greatest_audit_index); }
   elsif ( $greatest_audit_index == 0)
      { croak("\n$AUDIT_FILE missing or out of sync\n"); }
   else
   {
      print("\n$AUDIT_FILE and archive files out of sync\n");
      print("INDEX F\t$greatest_file_index\n");
      print("INDEX A\t$greatest_audit_index\n");
      if ( $greatest_file_index > $greatest_audit_index )
      {
         return($greatest_file_index);
      }
      else
      {
         return($greatest_audit_index);
      }
   }
}

sub audit_report
{
   my (@new_cases) = @_;
   my $audit_header = '';
   my $index = get_index();
   my $ts = get_timestamp();
   my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
   my @tickets = keys(%tickets);
   my $total_cases = @tickets;
   my $nc = ${number_of_new_cases};
   my $author =  $info{author};
   my $created_ts = $info{created};
   if ( $index== 0 )
      { $audit_header='INDEX,TIMESTAMP,USER,CASES,NEW CASES,AUTHOR,CREATED,REPORT,NEW CASES AUDIT'; }
   $index++;
   my $nc_file = audit_new_cases($AUDIT, $index, @new_cases);
   my $arch_export_file = archive_export_file($AUDIT, $index, $export_file);
   my $audit_entry = join(',', ($index,${ts},${username},${total_cases},${nc},${author},${created_ts},${arch_export_file},${nc_file}));
   create_audit($AUDIT_FILE, $audit_entry, $audit_header); 
   print("INDEX: \t${index}\n");
#   print_info();
}

sub archive_export_file
{
   my ($audit_dir, $index, $file) = @_;
   my $base_fn = basename($file);
   my $archive_file=${audit_dir} . '/' . ${base_fn}  . '.' . $index;
   if ( -e ${archive_file} )
      { croak("\nERROR: ${archive_file} appeared out of no where!\n"); }
   if ( ! -e ${file} )
      { croak("\nERROR: ${file} disappeared!\n"); }
   move(${file},${archive_file}) or croak("\nFile cannot be moved: $OS_ERROR");
   return(basename($archive_file));
}

sub audit_new_cases
{
   my ($audit_dir, $index, @cases) = @_;
   my $num_cases = @cases;
   if ( ${num_cases} == 0 )
      { return('NONE') }
   my $mode = 0770;	# allow group full access
   my $new_cases_file = $audit_dir . '/new_cases.' . $index;
   if ( -e ${new_cases_file} )
      { croak("\nERROR: ${new_cases_file} appeared out of no where!\n"); }
   open(NC, ">${new_cases_file}") or croak("\n${new_cases_file} cannot be created: $OS_ERROR.");
   my $new_cases = join(',', sort(@cases));
   printf(NC "%s\n", ${new_cases});
   close(NC);
   chmod($mode, $new_cases_file) or croak("\nCould not chmod $new_cases_file\n");
   return(basename($new_cases_file));
}

sub create_audit
{
   my ($file, $entry, $header) = @_;
   my $mode = 0770;	# allow group full access
   if ( ${header} ne '' )
   {
      open(AUD, ">${file}") or croak("\n${file} cannot be created: $OS_ERROR.");
      printf(AUD "%s\n", ${header});
   }
   else
      { open(AUD, ">>${file}") or croak("\n${file} cannot be created: $OS_ERROR."); }
   printf(AUD "%s\n", ${entry});
   close(AUD);
   chmod($mode, $file) or croak("\nCould not chmod $file\n");
}

sub figure_export_file
{
   my @ARGS = @_;
   my $number_of_args = @ARGS;
   if ( $number_of_args > 1)
      { croak("\nToo many commandline arguments\n"); }
   my $exp_file=${BASE} . '/dev/ServiceDesk/export.xls';
   if ( $number_of_args == 1 )
   {
      my ($ex_file) = @ARGS;
      if ( -e $ex_file )
         { $exp_file = $ex_file; }
      else
         { croak("\nExport file: $ex_file DOES NOT exist!\n"); }
   }
   return $exp_file;
}
sub create_cases
{
   my ($cases, %tks) = @_;
   my $case_dir_mode = 0770;	# allow group full access
   my (@new_cases) = ();
   foreach my $key (keys(%tks))
   {
      my $case = ${cases} . "/" . ${key};
      if ( -e $case )
         {
            # case aleady exist 
         }
      else # create case
      {
         mkdir($case, $case_dir_mode) or croak("\nCould not create $case\n");
         chmod($case_dir_mode, $case) or croak("\nCould not chmod $case\n");
         my $summary = $tks{$key}->{Summary};
         create_summary($summary, $case, $case_dir_mode);
         create_info($key, $tks{$key}, $case, $case_dir_mode);
         push(@new_cases, $key);
      }
   }
   print("NEW: \t", $#new_cases+1,"\t");
   return(@new_cases);
}

sub create_info
{
   my ($key, $ticket, $case, $mode) = @_;
   my $info_file = ${case} . "/info";
   my $field = 'Requestor';
   my @info = ('Requestor', 'End User', 'Open Date', 'Priority', 'Urgency', 'Parent', 'Change #');
   open(INFO, ">${info_file}") or croak("\n${info_file} cannot be created: $OS_ERROR.");
   printf(INFO "Request:%s\n", $key);
   foreach my $field (@info)
      { printf(INFO "%s:%s\n", $field, $ticket->{$field}); }
   close(INFO);
   chmod($mode, $info_file) or croak("\nCould not chmod $info_file\n");
}

sub create_summary
{
   my ($summary, $case, $mode) = @_;
   my $summary_file = ${case} . "/summary";
   open(SUM, ">${summary_file}") or croak("\n${summary_file} cannot be created: $OS_ERROR.");
   printf(SUM "%s\n", ${summary});
   close(SUM);
   chmod($mode, $summary_file) or croak("\nCould not chmod $summary_file\n");
}


sub test_tickets
{
   my %tickets = @_;
   foreach my $key (keys(%tickets))
      { print("CASE: $key\tURGENCY: $tickets{$key}->{Summary}\n"); }
}

sub print_info
{ 
   print("Title: $info{title}\n");
   print("Author: $info{author}\n");
   print("Created: $info{created}\n");
}




sub parse_tickets
{
   my @header = @_;
   my (%tickets, @fields) = ();
   my ($field, $row) = 0;
   my $data = "";
   LINE: foreach my $line (@export)
   {
      if ( $line =~ m/<Row/ )	# find start of new row
      {
         if ( $row ) { croak("\nRow inside of a row"); }
         @fields = ();
         $field=0;
         $row=1;		# set in row flag
      }
      if ( $line =~ m/<Cell[^>]*>/ )	# find beginning of cell
         { $data = ""; }		# blank out data 
      if ( ($row) && ($line =~ m/\[CDATA\[([^\]]+)/) )
      {
         $data = $1;
         $field++;
      }
      if ( $line =~ m/<\/Cell[^>]*>/ )	# find end of cell
         { push(@fields, $data); }
      if ( $line =~ m/<\/Row>/ )
      {
         if ( ! $row ) { croak("\nRow ending outside  of a row"); }
         if ( $#fields == $#header ) # check proper number of fields
         {
            %tickets = build_ticket(\%tickets, \@fields, \@header);	# build ticket
         }
         else
         {
            print("\nfields: $#fields\n");
            print("header: $#header\n");
            croak("Data fields did not match header\n");
         }
         $row=0;		# set end of row flag
      }
   }
   return(%tickets);

}

sub build_ticket
{
   my ($t, $f, $h) = @_;
   my %tickets = %{ $t };
   my @fields = @{ $f };
   my @header = @{ $h };
   my $case = shift(@fields);	# get case # from first field
   shift(@header);		# shift off first header field
   my %ticket=();
   @ticket{@header} = @fields;
   $tickets{$case} = \%ticket;

   return(%tickets);
}

sub get_header
{
   my @header = ();
   my ($ln_num, $header)=0;
   HEADER: foreach my $line (@export)
   {
      if ( $line =~ m/<Row>/ )	# find start of header row
         { $header=1; }		# set that we are in the header row
      if ( ($header) && ($line =~ m/\[CDATA\[([^\]]+)/) )
      {
         my $header = $1;
         push(@header, $header);
      }
      if ( $line =~ m/<\/Row>/ )
      {
         $ln_num++;	# so that we trim off all the processed lines
         last HEADER;
      }
      $ln_num++;
   }
   @export = @export[$ln_num ... $#export ];
   return @header
}

sub get_info
{
   my %info = ();
   my $found = 0;
   foreach my $line (@export)
   {

      if ( $line =~ m/<Title>([^<]+)</ ) { $info{title} = $1; $found++;}
      if ( $line =~ m/<Author>([^<]+)</ ) { $info{author} = $1; $found++;}
      if ( $line =~ m/<Created>([^<]+)</ ) { $info{created} = $1; $found++;}
   }
   if ($found < 3)
      { croak("\nExport file not in proper format\n"); }
   return(%info);
}

sub bulk_parse # new
{
   my (@cases) = @_;
   my %users_list = get_users();
   my %servers_list = get_servers();
#   print_array(keys(%servers_list));
   for my $case (@cases)
   {
      my (@lines, @emails, @servers, @ips, @logins, @groups) = ();
      my $parse_file = 'Summary';
      push(@lines, $tickets{$case}->{$parse_file});
      for my $line (@lines)
      {
         @groups = get_groups($line, @groups);
         my $prev_word = '';
         for my $word (split(/\s+/, ${line}))
         {
            if ( is_email(${word}) ) { push(@emails, ${word}); }
            if ( is_server(${word}, ${prev_word}, %servers_list) ) 
            {
               $word = remove_tail($word);
               push(@servers, lc(${word}));
            }
            if ( is_ip(${word}) ) { push(@ips, ${word}); }
            if ( is_login(${word}, %users_list) ) { push(@logins, ${word}); }
            $prev_word = ${word};
         }
      }
      create_file($case, "emails", ${parse_file}, @emails);
      create_file($case, "servers", ${parse_file}, @servers);
      create_file($case, "ips", ${parse_file}, @ips);
      create_file($case, "logins", ${parse_file}, @logins);
      create_file($case, "groups", ${parse_file}, @groups);
   }
}

sub get_groups
{
   my ($line, @groups) = @_;
   if ( $line =~ m/\S*group\S*\s+(\S+)/i )
      { push(@groups, $1); }
   return(@groups);
}


sub create_file
{
   my ($case, $filename, $extension, @contents) = @{_};
   my $mode = 0770;	# allow group full access
   unless ( @contents )
      { return(); }
   my $fn = $CASES . "/" . $case . "/${filename}.${extension}";
   if ( -e ${fn} )
   {
      my $ts = get_timestamp();
      rename(${fn}, "${fn}.${ts}");
   }
   open(FILE, ">${fn}") or die("\nCouldn't open ${fn}\n");
   foreach my $line (@contents)
      { printf(FILE "%s\n", ${line}); }
   close(FILE);
   chmod($mode, $fn) or croak("\nCould not chmod $fn\n");
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
      { ${filename} = shift(@ARGV); }
   return ${filename};
}


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

sub get_servers
{
   my %hosts       = ();

   my @files = </usr/local/etc/ldap*.csv>;
   foreach my $file (@files)
   {
      my @file = read_file(${file});
      shift(@file);
      shift(@file);
      foreach my $line (@file)
      {
         (my $hostname, my $app, my $ip) = split(/,/, $line);
         $hosts{$hostname} = 1;
      }
   }
   return %hosts;

}

# login - check ldap
sub is_login
{
   my ($word, %users_list) = @_;
   if( $users_list{${word}} ) { return ${TRUE}; }
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
   my ($word, $previous, %servers_list) = @{_};
   my $ignore = 'SiteScope|FileSystems';
   if ( ${word} =~ m/$ignore/ ) { return ${FALSE}; }
   if ( ${previous} eq 'Scope:' ) { return ${FALSE}; }
   if ( $servers_list{${word}} ) { return ${TRUE}; }
   if ( ${word} =~m/^(cdl).|(dc1).|(dc2).|(dc3).|(dc6)./i ) { return $TRUE; }
   return ${FALSE};
}

sub remove_tail
{
   my ($word) = @_;
   ${word} =~ s/[.,:]$//;
   return $word;
}

# email @adp.com
sub is_email
{
   my ($word) = @{_};
   if ( ${word} =~ m/\@adp.com/i ) { return $TRUE; }
   return ${FALSE};
}

# group
