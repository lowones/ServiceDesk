#!//usr/bin/perl

use warnings;


my $word = 'kevin?';

remove_tail($word);

sub remove_tail
{
   my ($word) = @_;
   ${word} =~ s/[.,:]$//; 
   print("$word\n");
   return $word;
}

