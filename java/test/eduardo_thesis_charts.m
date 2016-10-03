function [ omega_pu ] = eduardo_thesis_charts( input_args )
%EDUARDO_THESIS_CHARTS Summary of this function goes here
%   Detailed explanation goes here

    rng( 42 );
    
    jopt.verbose = false;
    jopt.simgrid_max_recursion = 200;
    jopt.simgrid_method = 'recursive';
    
    scenario = [ [50, 32]; [100, 33]; [200, 24]; [300, 23] ];
    disp( scenario );
    T = 400;
    
    I = 0.5;
    delta_t = 1/I;
    
    delete 'eduardo_thesis_charts.log';
    diary( 'eduardo_thesis_charts.log' );
    try
        t = 0;
        next_event = 1;
        [ C, ps, ix, opt, ~, ~ ] = init_case39( jopt );
%         [ C, ps_test, ~, opt, ~, ~ ] = init_case39( jopt );
%         [ C, ps_test, ~, opt, ~, ~ ] = init_case2383( jopt );

        n_macs      = size(ps.mac,1);
        omega_pu = zeros(T*I + 1, n_macs);
        
        i = 0;
        assert( length(ix.x.omega_pu) == n_macs );
        omega_pu(i+1, :) = ps.x(ix.x.omega_pu);
        i = i + 1; 

        while t < T
            fprintf( '+++++ t = %i +++++\n', t );
            
            % See if an event happens this step
            event = [];
            tend = T;
            if next_event <= size(scenario, 1)
                event_tuple = scenario(next_event, :);
                event_t = event_tuple(1);
                event_b = event_tuple(2);
                if t == event_t
                    % Instantiate the event
                    event = zeros( 1, C.ev.cols );
                    event(C.ev.time) = event_t;
                    event(C.ev.type) = C.ev.trip_branch;
                    event(C.ev.branch_loc) = event_b;

                    next_event = next_event + 1;
                end
                
                if next_event <= size(scenario, 1)
                    tend = scenario(next_event, 1);
                end
            end
            
%             delta_t = tend - t;

            % Old implementation
            disp( '+++++ Old +++++' );
            [ ps, ~, xprime, yprime, ~ ]  = take_action( ...
                ps,  opt, t, ps.x, ps.y, [], event, delta_t );
            ps.x = xprime;
            ps.y = yprime;
            
            % Apply dynamics
%             ps = take_action2( ps, opt, t, event, delta_t );
            
            t = t + delta_t;
            
            % Log results
            assert( length(ix.x.omega_pu) == n_macs );
            omega_pu(i + 1, :) = ps.x(ix.x.omega_pu);
            i = i + 1;
        end
    catch ex
        diary off;
        rethrow( ex );
    end
    diary off;
    
%     figure;
%     plot( 0:T, omega_pu, 'LineWidth', 2 );

end

