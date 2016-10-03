function whos_test( )
%WHOS_TEST Summary of this function goes here
%   Detailed explanation goes here

    baz = 5;
    S = evalin( 'base', 'whos' );
    S.name

end
