#!/usr/bin/perl -w
#	0 	parsed header, with debug statements
#	1	removed header debug, build parse_tickets sub
#	2	added handler for empty cells
#	3	working on building tickets hash, almost done, about to assign anon hash to %tickets
#	4	%tickets built 
#	5	get_info (Title, Author, Created)
#	6	remove debug statements from parse_tickets
#	7	define config variables; BASE_DIR, CASES, export_file, initial create_cases sub
#	8	create_summary sub finished
#	9	feedback, number of cases created
#	#	Summary, Priority, Urgency, End User, Requestor, Change #
#	future	config variables, case dir creation, state files. audit logging ( who ran, number or cases created) cleanup ( keep # of old export files, prune back just new cases)
use English qw( -no_match_vars );
use Carp; 
use strict;
require '/home/lowk/bin/lowlib.pl';

print "xml brute force\n";
my $BASE = '/home/lowk';
my $CASES = ${BASE} . '/dev/cases';
#my $export_file='/home/lowk/dev/excel/export.xls';
my $export_file=${BASE} . '/dev/excel/export.xls';
my @export = read_file($export_file);

my %info = get_info();		# get Title, Author & Created TS
my @header = get_header();	# parse out header row
my %tickets = parse_tickets(@header);		# parse tickets from export
#test_tickets(%tickets);
create_cases($CASES, %tickets);
print_info();


### End MAIN

sub create_cases
{
   my ($cases, %tickets) = @_;
   my $case_dir_mode = 0770;	# allow group full access
   my (@new_cases) = ();
   print("create_cases\n");
   foreach my $key (keys(%tickets))
   {
      my $case = ${cases} . "/" . ${key};
      if ( -e $case )
      {
         print("CASE: $case\tEXISTS\n");
         # case aleady exist
      }
      else # create case
      {
         mkdir($case, $case_dir_mode) or croak("Could not create $case\n");
         chmod($case_dir_mode, $case) or croak("Could not chmod $case\n");
         my $summary = $tickets{$key}->{Summary};
         create_summary($case, $summary, $case_dir_mode);
         push(@new_cases, $key);
      }
   }
   print($#new_cases+1," cases created\n");
   print(join(',',@new_cases));
}

sub create_summary
{
   my ($case, $summary, $mode) = @_;
   print("Create summary for $case\n");
   my $summary_file = ${case} . "/summary";
   print("$summary_file\n");
   open(SUM, ">${summary_file}") or croak("${summary_file} cannot be created: $OS_ERROR.");
   printf(SUM "$summary\n");
   close(SUM);
   chmod($mode, $summary_file) or croak("Could not chmod $summary_file\n");
}


sub test_tickets
{
   my %tickets = @_;
   foreach my $key (keys(%tickets))
   {
      print("CASE: $key\tURGENCY: $tickets{$key}->{Summary}\n");
#      print("CASE: $key\tURGENCY: $tickets{$key}->{Urgency}\n");
   }
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
         if ( $row ) { croak("Row inside of a row"); }
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
         if ( ! $row ) { croak("Row ending outside  of a row"); }
         if ( $#fields == $#header ) # check proper number of fields
         {
            %tickets = build_ticket(\%tickets, \@fields, \@header);	# build ticket
         }
         else
         {
            print("fields: $#fields\n");
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
   foreach my $line (@export)
   {

      if ( $line =~ m/<Title>([^<]+)</ ) { $info{title} = $1; }
      if ( $line =~ m/<Author>([^<]+)</ ) { $info{author} = $1; }
      if ( $line =~ m/<Created>([^<]+)</ ) { $info{created} = $1; }
   }
   return(%info);
}
