package Math::Vector::Real::XS;

our $VERSION = '0.03';

use strict;
use warnings;

require XSLoader;
XSLoader::load('Math::Vector::Real::XS', $VERSION);

1;

__END__

=head1 NAME

Math::Vector::Real::XS - Real vector arithmetic in fast XS

=head1 SYNOPSIS

  use Math::Vector::Real;
  ...

=head1 DESCRIPTION

This module reimplements most of the functions in
L<Math::Vector::Real> in XS for a great performance boost.

Once this module is installed, L<Math::Vector::Real> will load and use
it automatically.

=head1 SUPPORT

In order to report bugs you can send me and email to the address that
appears below or use the CPAN RT bugtracking system available at
L<http://rt.cpan.org>.

The source for the development version of the module is hosted at
GitHub: L<https://github.com/salva/p5-Math-Vector-Real-XS>.

=head2 My wishlist

If you like this module and you're feeling generous, take a look at my
Amazon Wish List: L<http://amzn.com/w/1WU1P6IR5QZ42>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Salvador Fandiño (sfandino@yahoo.com).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
