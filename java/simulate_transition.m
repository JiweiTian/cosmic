function [ps] = simulate_transition( ps, t, t_next, opt )
% Integrate PS DAEs from t to t_next, recursively if endogenous events
%
% [hostetje] This is a new implementation that tries to reduce the amount
% of recursion. The old version always did a 1-vs-all split when dealing with
% multiple connected components, which produces very deep recursive call
% trees. This version calculates all of the connected components and then
% iterates over them. It calls the new 'simgrid_component()' function on
% each component, then checks if that subgrid had a relay event and if so
% recomputes and requeues the components of the subgrid.
%
% inputs:
%  ps - power system structure, see psconstants.
%  t  - initial simulation time
%  t_next - end simulation time
%  opt - options inherited from simgrid
%
% outputs:
%  ps - the power systems structure at the end of the simulation

C = psconstants;

%% Find the initial connected component set
% Get closed branches
br_status           = ps.branch(:,C.br.status) == C.CLOSED;
% Get connected components
[components, Ncomponents] = findSubGraphs( ...
    ps.bus(:,C.bu.id), ps.branch(br_status,C.br.f:C.br.t) );

comp_queue = java.util.LinkedList;
partitioned = Ncomponents > 1;
for i = 1:Ncomponents
    comp_queue.push( [i, t, partitioned] ); %comp_queue.add( [i, t] );
end

%% Process the component queue
blackout = true;
while ~comp_queue.isEmpty()    
    qelem = comp_queue.pop(); %comp_queue.poll();
    comp = qelem(1);
    comp_t = qelem(2);
    comp_partitioned = qelem(3);
    
    subnet = logical(components == comp);
    sub_ps = subsetps( ps, subnet, opt );
    if size(sub_ps, 1) < 1
        disp( 'ERROR: No buses in sub_ps:' );
        disp( sub_ps );
        assert( size(sub_ps, 1) > 0 );
    end
    
    if opt.verbose
%        memory(); % FIXME: Debugging code
        fprintf( 'comp: %i, comp_t: %f\n', comp, comp_t );
        fprintf( ' %i', sub_ps.bus(:, C.bu.id)' );
        fprintf( '\n' );
    end
	
	% Find all soonest scheduled events that belong to this subgrid
	ev_itr = ps.event_queue.listIterator();
	min_idx = [];
	t_ev = t_next; % Simulation end defaults to t_next if there are no events
	while ev_itr.hasNext()
		ev = ev_itr.next();
		e1 = ev(1);
		e2 = ev(2);
		e3 = ev(3);
		shunt = any(sub_ps.shunt(:, C.sh.id) == e2);
		branch = any(sub_ps.branch(:, C.br.id) == e2);
		
		if opt.verbose
			disp( e1 );
			disp( e2 );
			disp( e3 );
			disp( shunt );
			disp( branch );
		end
		
		% If event applies to this subgrid
		if (strcmp( e1, 'shunt' ) && shunt) || (strcmp( e1, 'branch' ) && branch)
			% If event occurs before the earliest event found so far
			ti = e3(C.ev.time);
			if ti <= t_ev
				if ti < t_ev
					min_idx = [];
					t_ev = ti;
				end
				min_idx(end + 1) = ev_itr.previousIndex();
			end
		end
	end
	min_idx = sort(min_idx); % Should be sorted already, but just in case
	if opt.verbose
		fprintf( 'simulate_transition(): min_idx =' );
		fprintf( ' %d', min_idx );
		fprintf( '\n' );
		
		fprintf( 'simulate_transition(): min_ev =' );
		itr = ps.event_queue.listIterator();
		for i = 1:numel(min_idx)
			idx = min_idx(i);
			while itr.nextIndex() ~= idx
				itr.next();
			end
			ev = itr.next();
			fprintf( '\t%d: %s %d', idx, ev(1), ev(2) );
			fprintf( ' %f', ev(3) );
		end
		fprintf( '\n' );
	end
    
    % [hostetje] These next two statements used to happen in reversed order
    % in simgrid_interval(), leaving update_load_freq_source() to rely on
    % values for Ybus that had been initialized elsewhere. I changed the
    % order for uniformity, because getYbus() does not depend on
    % update_load_freq_source().
    [sub_ps.Ybus, sub_ps.Yf, sub_ps.Yt, sub_ps.Yft, sub_ps.sh_ft] = getYbus( sub_ps, false );
    sub_ps = update_load_freq_source( sub_ps );
    % [hostetje] We combine subgrid 'blackout' flags using &&, so they must
    % be initialized to false.
    sub_ps.blackout = false;
    % [hostetje] We always calculate X and Y from scratch, whereas the old
    % code re-used the old vectors if the grid did not split.
    [sub_ps.x, sub_ps.y] = get_xy( sub_ps, opt );
    
	% Do simulation to next event time
	if comp_t > t_ev
		fprintf( 'cosmic: WARNING: comp_t (%f) >= t_ev (%f)\n', comp_t, t_ev );
	end
	comp_t = min( comp_t, t_ev );
    [sub_ps, t_end] = simulate_component( sub_ps, comp_t, t_ev, opt );
    
	% Update global state
    ps = merge_component( ps, sub_ps, opt );
    blackout = blackout && sub_ps.blackout;
    
    if t_end < t_ev
		% A new relay event was enqueued in simulate_component() prior to the
		% time t_ev when the next event was going to occur. We need to
		% re-schedule this component because the new event might preempt the
		% current event. We know that the component did not split because we
		% haven't processed any events.
		
		if opt.verbose
            fprintf( '\tcomp %i triggered relay\n', i );
        end
	
		% Keep same component index, 0 indicates that subgrid did not split
		comp_queue.add( [comp, t_end, 0] );
		% comp_queue.add( [comp, t_end + opt.sim.t_eps, 0] );
	elseif ~isempty(min_idx)
		% Simulation reached t_ev. If there were events, then process them,
		% check for grid splitting, and reschedule all sub-components. If there
		% was no event, then t_ev == t_next and we're done with this component.
		
		rm_itr = ps.event_queue.listIterator();
		for i = 1:numel(min_idx)
			idx = min_idx(i);
			% Adjust index to account for previously-removed events
			while rm_itr.nextIndex() ~= idx - i + 1
				rm_itr.next();
			end
			
			min_ev = rm_itr.next();
			fprintf( 'simulate_transition(): relay event %d:', idx );
			fprintf( '\t%d: %s %d', idx, min_ev(1), min_ev(2) );
			fprintf( ' %f', min_ev(3) );
			fprintf( '\n' );
			% rm_itr points to min_ev in the event queue
			rm_itr.remove();
			
			% Apply the event
			% Note: process_event() insists on having a *row* vector for the event
			% FIXME: I'VE DELIBERATELY PUT THE BUG BACK!!!
			ps = process_event( ps, min_ev(3)', opt ); % <- Correct
			% process_event( ps, min_ev(3)', opt ); % <- INCORRECT!!!
		end
        
        % Compute new connected components
        sub_br_status = sub_ps.branch(:, C.br.status) == C.CLOSED;
        [sub_components, Nsub_components] = findSubGraphs( ...
            sub_ps.bus(:, C.bu.id), sub_ps.branch(sub_br_status, C.br.f:C.br.t) );
        assert( sum(subnet) == length(sub_components) );
        
        % Schedule all components in the subgraph
        sub_partitioned = Nsub_components > 1;
        if opt.verbose
            fprintf( '\tcomp %i ->', comp );
            fprintf( ' %i', (1:Nsub_components) + Ncomponents );
            fprintf( '\n' );
        end
        for i = 1:Nsub_components
			comp_queue.add( [i + Ncomponents, t_end, sub_partitioned] );
            % comp_queue.add( [i + Ncomponents, t_end + opt.sim.t_eps, sub_partitioned] );
        end
        
        % Adjust component indices so they are unique
        sub_components = sub_components + Ncomponents;
        components(subnet) = sub_components;
        Ncomponents = Ncomponents + Nsub_components;
	else
		assert( t_end == t_next );
    end
end

% Set the master 'blackout' flag
ps.blackout = blackout;

end

