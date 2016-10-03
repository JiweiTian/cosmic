function [ ps ] = init_xy( ps, opt )
%INIT_XY Calls get_xy() and stores the results in ps.x/ps.y.
%   My [hostetje] modified code assumes that x and y are stored in 'ps'
%   because this makes this easier to keep track of.

    [x, y] = get_xy( ps, opt );
    ps.x = x;
    ps.y = y;
end

