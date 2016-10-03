function [ psprime, tprime, xprime, yprime, eventprime ] = take_action( ps, opt, t, x, y, event, a, delta_t )
%TAKE_ACTION Executes a single action and then simulates 'delta_t' forward.
%   This is essentially an adaptation of the part of 'simgrid.m' that
%   calls 'simgrid_interval.m'. We've changed it so that it doesn't expect
%   an "end" event, as this is handled by Java.

    psprime = ps;
    tprime = t;
    xprime = x;
    yprime = y;
    eventprime = event;
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
    event_no = 1;
    discrete = false;
    %t_end = min( t + delta_t, event(end, 1) );
    t_end = tprime + delta_t; % No 'end' event
    while tprime < t_end
        % process exogenous discrete events at this time period
        while event_no <= size(eventprime, 1) && eventprime(event_no,1) <= tprime
            [psprime,new_discrete] = process_event(psprime,eventprime(event_no,:),opt);
            event_no = event_no+1;
            discrete = discrete | new_discrete;     % for simultaneous events
        end
        if discrete
            tprime = tprime + opt.sim.t_eps;
        end
        % find the next time interval
%         t_next = min( t_end, event(event_no,1) );
        t_next = t_end; % No 'end' event
        % try to simulate between t and t_next
        if opt.verbose
            fprintf('\n Simulating from t=%g s to t=%g s\n',tprime,t_next);
        end
        
        if strcmp( 'recursive', opt.simgrid_method )
            [psprime,t_out,X,Y] = simgrid_interval(0, psprime,tprime,t_next,xprime,yprime,opt);
        elseif strcmp( 'iterative', opt.simgrid_method )
            t_out = [t_next];
            [psprime,X,Y] = simgrid_interval_iterative( ...
                0, psprime,tprime,t_next,xprime,yprime,opt);
        else
            error( 'Cosmic:IllegalArgument', 'opt.simgrid_method' );
        end
        
%         fprintf( 'Shunts:\n' );
%         disp(ps.shunt);
        if opt.verbose
            fprintf(' Completed simulation up until t=%g\n',t_out(end));
        end

        % log to files
        if opt.sim.writelog
            if opt.verbose
                fprintf(' Writing simulation results to %s\n',opt.outfilename);
            end
            write_state(opt.outfilename,t_out,X,Y);
        end;

        % update time and solutions for next interval
        tprime = t_next;
        xprime = X(:,end);
        yprime = Y(:,end);
        % Drop old events from 'event' list
        eventprime = eventprime(event_no:end,:);
        % record events
        %event_record            = [event_record; ps.event_record]; %#ok<AGROW>
        psprime.event_record         = [];
    end
    % 't' will have been set to the next event time in the loop, so we
    % reset it
    tprime = t_end;
    
    % [20160112:hostetje] Ensure that open branches/shunts are zero'd out
    % even if simulation failed
    C = psconstants;
    psprime.branch(psprime.branch(:,C.br.status)==0, C.br.var_idx) = 0;
    psprime.shunt(psprime.shunt(:,C.sh.status)==0, C.sh.var_idx)   = 0;
end

