function [ ps ] = process_relay_event(t_event,relay_event,ps,opt)
% usage: [ ps ] = process_relay_event(t_event,relay_event,ps,opt)
% proess the relay event
C           = psconstants;
% [20160126:hostetje] Globals moved to field of 'ps'.
% global t_delay t_prev_check

[relay_type,relay_location,relay_index] = get_relay_event_info(relay_event,ps);
num_relay = size(relay_type,1);
new_event = zeros(num_relay,C.ev.cols);
for i = 1:num_relay
    if relay_type(i) == C.relay.dist
        new_event(i,C.ev.time) = t_event;
        new_event(i,C.ev.type) = C.ev.dist_relay;
        new_event(i,C.ev.branch_loc) = relay_location(i);
        if opt.verbose, fprintf('  t = %.4f: Distance relay trip at branch %d...\n',t_event,relay_location(i)); end
        ps.relay(relay_index(i),C.re.tripped) = 1;
        
    elseif relay_type(i) == C.relay.temp
        new_event(i,C.ev.time) = t_event;
        new_event(i,C.ev.type) = C.ev.temp_relay;
        new_event(i,C.ev.branch_loc) = relay_location(i);
        if opt.verbose, fprintf('  t = %.2f: Temperature relay trip at branch %d...\n',t_event,relay_location(i)); end
        ps.relay(relay_index(i),C.re.tripped) = 1;

    elseif relay_type(i) == C.relay.oc
        new_event(i,C.ev.time) = t_event;
        new_event(i,C.ev.type) = C.ev.oc_relay;
        new_event(i,C.ev.branch_loc) = relay_location(i);
        if opt.verbose, fprintf('  t = %.2f: Over current relay trip at branch %d...\n',t_event,relay_location(i)); end
        ps.relay(relay_index(i),C.re.tripped) = 1;

    elseif relay_type(i) == C.relay.uvls
        new_event(i,C.ev.time) = t_event;
        loc = find(ps.shunt(:,C.sh.bus)==relay_location(i));
        if ps.shunt(loc,C.sh.P) > 0 && ps.shunt(loc,C.sh.status) > 0;
            new_event(i,C.ev.type) = C.ev.uvls_relay;
            new_event(i,C.ev.shunt_loc) = loc;
            new_event(i,C.ev.change_by) = 1;     % 1 = by percentage, 0 = by amount
            new_event(i,C.ev.quantity) = opt.sim.uvls_delta;
            if opt.verbose, fprintf('  t = %.4f: UVLS relay trip at bus %d...\n',t_event,relay_location(i)); end
            ps.relay(relay_index(i),C.re.tripped) = 1;
            glo_id = ps.relay(relay_index(i),C.re.id);
            ps.t_delay(glo_id) = opt.sim.uvls_tdelay_ini;
            ps.t_prev_check(glo_id) = NaN;
        end

    elseif relay_type(i) == C.relay.ufls
        new_event(i,C.ev.time) = t_event;
        loc = find(ps.shunt(:,C.sh.bus)==relay_location(i));
        if ps.shunt(loc,C.sh.P) > 0 && ps.shunt(loc,C.sh.status) > 0;
            new_event(i,C.ev.type) = C.ev.ufls_relay;
            new_event(i,C.ev.shunt_loc) = loc;
            new_event(i,C.ev.change_by) = 1;     % 1 = by percentage, 0 = by amount
            new_event(i,C.ev.quantity) = opt.sim.ufls_delta;
            if opt.verbose, fprintf('  t = %.4f: UFLS relay trip at bus %d...\n',t_event,relay_location(i)); end
            ps.relay(relay_index(i),C.re.tripped) = 1;
            glo_id = ps.relay(relay_index(i),C.re.id);
            ps.t_delay(glo_id) = opt.sim.ufls_tdelay_ini;
            ps.t_prev_check(glo_id) = NaN;
        end
    end

    if new_event(i,C.ev.type)~=0
        % ps = process_event(ps,new_event(i,:),opt);
		
		if opt.random.relays
			% [hostetje] The 'stats' toolbox (which contains exprnd()) doesn't
			% work on the cluster, possibly due to platform incompatibility. Since
			% we only work with simple distributions, the easiest thing is to just
			% write the sampling code ourselves.
			r = -opt.random.relay_mu * log(rand());
			% r = exprnd( opt.random.relay_mu );
			new_event(i, C.ev.time) = new_event(i, C.ev.time) + r;
		end
		
		if new_event(i, C.ev.branch_loc) ~= 0
			q = {'branch', new_event(i, C.ev.branch_loc), new_event(i, :)};
		elseif new_event(i, C.ev.shunt_loc) ~= 0
			q = {'shunt', new_event(i, C.ev.shunt_loc), new_event(i, :)};
		end
		
		fprintf( 'process_relay_event: Enqueue %s %d ->', q{1}, q{2} );
		fprintf( ' %f', q{3} );
		fprintf( '\n' );

		ps.event_queue.add( q );
    end
end