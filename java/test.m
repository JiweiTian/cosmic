function test()
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    jopt.verbose = true;
    jopt.simgrid_max_recursion = 200;
    jopt.simgrid_method = 'iterative';
    [ C, ps, index, opt, t, event ] = init_case39( jopt );

    %% Run simulation using our new machinery
    delta_t = 1;
    for t = 1:10
        [ps] = simgrid_split(ps, t, t + delta_t, opt);
    end
    
%     delta_t = 1;
%     while t < t_end
%         a = [];
%         [ps, t, x, y, event] = take_action( ps, opt, t, x, y, event, a, delta_t );
%     end
end
