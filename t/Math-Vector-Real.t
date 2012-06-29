#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;
use Math::Vector::Real;

is(V(1)->norm, 1);


