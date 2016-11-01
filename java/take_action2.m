function [ psprime, optprime ] = take_action2( context, ps, opt, t, a, delta_t )
%TAKE_ACTION Executes a single action and then simulates 'delta_t' forward.
%   This is essentially an adaptation of the part of 'simgrid.m' that
%   calls 'simgrid_interval.m'. We've changed it so that it doesn't expect
%   an "end" event, as this is handled by Java.

	%% Push RNG state and resume from the random stream for 'context'
	old_rng = rng( opt.random.gen.(context).state );

    psprime = ps;
	optprime = opt;
    tprime = t;
    %% Execute action
    % We're using the Event mechanism to implement actions
    % A "logical" action may consist of a sequence of Events
    for i = 1:size(a, 1)
        [psprime, discrete] = process_event( psprime, a(i,:), optprime );
        if discrete
            tprime = tprime + optprime.sim.t_eps;
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
        if optprime.verbose
            fprintf('Simulating from t=%g s to t=%g s\n',tprime,t_next);
        end
        
        % [hostetje] This take_action calls 'simulate_transition()', which 
        % is a re-implementation of 'simgrid_interval()' that does *not*
        % attempt to preserve the original behavior.
        psprime = simulate_transition( psprime, t, t_next, optprime );

%         fprintf( 'Shunts:\n' );
%         disp(ps.shunt);
        if optprime.verbose
            fprintf( '...Completed simulation up until t=%g\n', t_next );
        end

        % log to files
        if optprime.sim.writelog
            if optprime.verbose
                fprintf(' Writing simulation results to %s\n',optprime.outfilename);
            end
            write_state( optprime.outfilename, t_out, s.x, s.y );
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
	if optprime.random.loads
		% [hostetje] The 'stats' toolbox (which contains normrnd()) doesn't
		% work on the cluster, possibly due to platform incompatibility. Since
		% we only work with simple distributions, the easiest thing is to just
		% write the sampling code ourselves.
		
		% Note that Psigma and Qsigma are vectors
		Pr = randn( size(optprime.random.load_Psigma) ) .* optprime.random.load_Psigma;
		Qr = randn( size(optprime.random.load_Qsigma) ) .* optprime.random.load_Qsigma;
		% Pr = normrnd( 0, optprime.random.load_Psigma );
		% Qr = normrnd( 0, optprime.random.load_Qsigma );
		
		psprime.shunt(:, C.sh.P) = ...
			max( optprime.random.load_Pmin, min( optprime.random.load_Pmax, psprime.shunt(:, C.sh.P) + Pr ) );
		psprime.shunt(:, C.sh.Q) = ...
			max( optprime.random.load_Qmin, min( optprime.random.load_Qmax, psprime.shunt(:, C.sh.Q) + Qr ) );
	end
	
	%% Save RNG state for 'context' and pop back to old RNG
	optprime.random.gen.(context).state = rng( old_rng );
end

