#!/usr/bin/perl

use strict;
use warnings;

unless ($ENV{TRAVIS}) {
    die "This script is only intended to be run from Travis CI platform\n";
}

for my $test ("Math-Vector-Real", "warnings") {
    my $target = "t/$test.t";
    my $src = "dependencies/p5-Math-Vector-Real/$target";
    unlink $target;
    symlink $src, $target
    or die "unable to symlink ${target}: $!";
}

mkdir "dependencies";
chdir "dependencies" or die "unable to chdir to dependencies: $!";
system "git clone https://github.com/salva/p5-Math-Vector-Real";
