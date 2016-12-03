function [ psprime, optprime ] = take_action2( context, ps, opt, t, a, delta_t )
%TAKE_ACTION Executes a single action and then simulates 'delta_t' forward.
%   This is essentially an adaptation of the part of 'simgrid.m' that
%   calls 'simgrid_interval.m'. We've changed it so that it doesn't expect
%   an "end" event, as this is handled by Java.

    psprime = ps;
	psprime.event_queue = java.util.LinkedList;
	psprime.event_queue.addAll( ps.event_queue );
	C = psconstants;
	
	% FIXME: Debugging code
	% if opt.verbose
		% disp( '----- BEFORE -----' );
		% disp( psprime.shunt(:, C.sh.current_P) );
		% disp( psprime.shunt(:, C.sh.factor) );
	% end
	
	optprime = opt;
	if opt.verbose
		fprintf( 'take_action2(): context = %s\n', context );
	end
	if strcmp('deterministic', context)
		optprime.random.loads = false;
		optprime.random.relays = false;
	% else
		% optprime.random.loads = true;
		% optprime.random.relays = true;
	end
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
    t_end = t + delta_t; % No 'end' event
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
		if optprime.random.relays
			old_rng = rng( optprime.random.gen.(context).relays );
			psprime = simulate_transition( psprime, tprime, t_next, optprime );
			optprime.random.gen.(context).relays = rng( old_rng );
		else
			psprime = simulate_transition( psprime, tprime, t_next, optprime );
		end

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
    psprime.branch(psprime.branch(:,C.br.status)==0, C.br.var_idx) = 0;
    psprime.shunt(psprime.shunt(:,C.sh.status)==0, C.sh.var_idx)   = 0;
	
	% [20161025:hostetje] Random load fluctuations
	if optprime.random.loads
		% Push RNG
		old_rng = rng( optprime.random.gen.(context).loads );
	
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
			
		% Pop RNG
		optprime.random.gen.(context).loads = rng( old_rng );
	end
	
	% FIXME: Debugging code
	% if opt.verbose
		% disp( '----- AFTER -----' );
		% disp( psprime.shunt(:, C.sh.current_P) );
		% disp( psprime.shunt(:, C.sh.factor) );
	% end
end

