function [ psprime ] = take_action2( ps, opt, t, a, delta_t )
%TAKE_ACTION Executes a single action and then simulates 'delta_t' forward.
%   This is essentially an adaptation of the part of 'simgrid.m' that
%   calls 'simgrid_interval.m'. We've changed it so that it doesn't expect
%   an "end" event, as this is handled by Java.

    psprime = ps;
    tprime = t;
    %% Execute action
    % We're using the Event mechanism to implement actions
    % A "logical" action may consist of a sequence of Events
    for i = 1:size(a, 1)
        [psprime, discrete] = process_event( psprime, a(i,:), opt );
        if discrete
            tprime = tprime + opt.sim.t_eps;
        end
    end

    %% step through the simulation
    %t_end = min( t + delta_t, event(end, 1) );
    t_end = tprime + delta_t; % No 'end' event
    while tprime < t_end
        % find the next time interval
%         t_next = min( t_end, event(event_no,1) );
        t_next = t_end; % No 'end' event
        % try to simulate between t and t_next
        if opt.verbose
            fprintf('Simulating from t=%g s to t=%g s\n',tprime,t_next);
        end
        
        % [hostetje] This take_action calls 'simulate_transition()', which 
        % is a re-implementation of 'simgrid_interval()' that does *not*
        % attempt to preserve the original behavior.
        psprime = simulate_transition( psprime, t, t_next, opt );

%         fprintf( 'Shunts:\n' );
%         disp(ps.shunt);
        if opt.verbose
            fprintf( '...Completed simulation up until t=%g\n', t_next );
        end

        % log to files
        if opt.sim.writelog
            if opt.verbose
                fprintf(' Writing simulation results to %s\n',opt.outfilename);
            end
            write_state( opt.outfilename, t_out, s.x, s.y );
        end;

        % update time and solutions for next interval
        tprime = t_next;
    end
    
    % [20160112:hostetje] Ensure that open branches/shunts are zero'd out
    % even if simulation failed
    C = psconstants;
    psprime.branch(psprime.branch(:,C.br.status)==0, C.br.var_idx) = 0;
    psprime.shunt(psprime.shunt(:,C.sh.status)==0, C.sh.var_idx)   = 0;
	
	% [20161025:hostetje] Random load fluctuations
	if opt.random.loads
		disp( 'Randomizing loads...' );
		active = psprime.shunt(:, C.sh.factor) > 0;
		Nactive = sum( active );
		r = normrnd( 0, sqrt(opt.random.load_variance), Nactive, 1 );
		% Add random perturbation and ensure result is in bounds
		psprime.shunt(active, C.sh.factor) = ...
			max( 0, min( opt.random.load_max, psprime.shunt(active, C.sh.factor) + r ) );
	end
end

