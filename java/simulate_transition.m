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
%     if ~comp_partitioned
%         [sub_ps.x, sub_ps.y] = subset_xy( ps, sub_ps, opt );
%     else
%         [sub_ps.x, sub_ps.y] = get_xy( sub_ps, opt );
%     end
    
    [sub_ps, t_end] = simulate_component( sub_ps, comp_t, t_next, opt );
    
    ps = merge_component( ps, sub_ps, opt );
    blackout = blackout && sub_ps.blackout;
    
    if t_end < t_next
        if opt.verbose
            fprintf( '\tcomp %i interrupted by relay event\n', i );
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
            comp_queue.add( [i + Ncomponents, t_end + opt.sim.t_eps, sub_partitioned] );
        end
        
        % Adjust component indices so they are unique
        sub_components = sub_components + Ncomponents;
        components(subnet) = sub_components;
        Ncomponents = Ncomponents + Nsub_components;
    end
end

% Set the master 'blackout' flag
ps.blackout = blackout;

end

