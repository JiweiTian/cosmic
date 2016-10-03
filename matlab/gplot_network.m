function gplot_network( ps )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    C = psconstants;
    Nbus = size( ps.bus, 1 );
    A = zeros( Nbus, Nbus );
    Nbranch = size( ps.branch, 1 );
    from = ps.branch(:, 1);
    to = ps.branch(:, 2);
    for i = 1:Nbranch
        A(from(i), to(i)) = 1;
        A(to(i), from(i)) = 1;
    end
    
    G = graph(A);
    plot( G, 'Layout', 'force' );
    
end

