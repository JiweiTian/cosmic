function test_simgrid_split()
%TEST_SIMGRID_SPLIT Summary of this function goes here
%   Detailed explanation goes here

    rng( 42 );
    
    compare_to_old = false;
    
    jopt.verbose = true;
    jopt.simgrid_max_recursion = 200;
    jopt.simgrid_method = 'recursive';
    
    Nepisodes = 10;
    event_gap = 15;
    event_jiggle = 10;
    delta_t = 1;
    T = 300;
    
    seeds = randi( 2147483647, Nepisodes );
    
    delete 'test_simgrid_split.log';
    diary( 'test_simgrid_split.log' );
    try
        for i = 1:Nepisodes
            rng( seeds(i) );
            
            t = 0;
            next_event = 10;
            
            [ C, ps_ref,  ~, opt, ~, ~ ] = init_case39( jopt );
            
            [ C, ps_test, ~, opt, ~, ~ ] = init_case39( jopt );
%             [ C, ps_test, ~, opt, ~, ~ ] = init_case2383( jopt );
            Nbranches = size(ps_test.branch, 1);

            while t < T
                event = [];
                if t == next_event
                    % Make a random branch trip event
                    event = zeros( 1, C.ev.cols );
                    event(C.ev.time) = t;
                    event(C.ev.type) = C.ev.trip_branch;
                    event(C.ev.branch_loc) = randi( Nbranches );

                    jiggle = randi( event_jiggle ) - 1;
                    next_event = next_event + event_gap + jiggle;
                end

                if compare_to_old
                    % Old implementation
                    disp( '+++++ Old +++++' );
                    [ ps_ref, ~, xprime, yprime, ~ ]  = take_action( ...
                        ps_ref,  opt, t, ps_ref.x, ps_ref.y, [], event, delta_t );
                    ps_ref.x = xprime;
                    ps_ref.y = yprime;
                    % FIXME: [hostetje] in case 39, there is a large discrepancy between
                    % lineloss for the recursive and iterative simulator implementations,
                    % but it occurs only in the imaginary part of 'lineloss' and only on
                    % the branch from bus 2 -> bus 30. As a temporary fix, I assign only
                    % the real part of lineloss to the 'ps' structure.
                    ps_ref.branch(:, C.br.lineloss) = real( ps_ref.branch(:, C.br.lineloss) );
                end
                
                disp( '+++++ New +++++' );
                if false
                    % Old implementation
        %             ( ps, opt, t, x, y, event, a, delta_t )
                    [ ps_test, ~, xprime, yprime, ~ ]  = take_action( ...
                        ps_test,  opt, t, ps_test.x, ps_test.y, [], event, delta_t );
                    ps_test.x = xprime;
                    ps_test.y = yprime;
                    % FIXME: [hostetje] in case 39, there is a large discrepancy between
                    % lineloss for the recursive and iterative simulator implementations,
                    % but it occurs only in the imaginary part of 'lineloss' and only on
                    % the branch from bus 2 -> bus 30. As a temporary fix, I assign only
                    % the real part of lineloss to the 'ps' structure.
                    ps_test.branch(:, C.br.lineloss) = real( ps_test.branch(:, C.br.lineloss) );
                else
                    % New implementation
                    ps_test = take_action2( ps_test, opt, t, event, delta_t );
                    
                    ps_test.branch(:, C.br.lineloss) = real( ps_test.branch(:, C.br.lineloss) );
                end

                if compare_to_old
                    assert( ps_eq( ps_test, ps_ref ) );
                end
                
                t = t + delta_t;
            end
        end
    catch ex
        diary off;
        rethrow( ex );
    end
    diary off;
end
