#!/usr/bin/perl


my @array = ("hello");

print "M @array\n";
first();

sub first
{
@array = ("first");
print "F @array\n";
second();
}

sub second
{
print "S @array\n";
}
