function [ps] = simgrid_split(ps, t,t_next, opt)
% usage: [ps,t_out,X,Y] = simgrid_interval(ps,t,t_next,x0,y0,opt)
% integrate PS DAEs from t to t_next, recursively if endogenous events
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
%  t  - initial simulation time.
%  t_next - end simulation time assuming no relay events.
%  x0 and y0 - current state of the system
%  opt - options inherited from simgrid
%
% outputs:
%  ps - the power systems structure at the end of the simulation.
%   .endo_events   - matrix that logs endogenous events during the simulation.
%  t_out - vector with times where the system was evaluated at
%  X and Y - state of the system during the integration period

% memory_data = struct2cell( whos() );
% whos

% fprintf( '>>>>> simgrid_interval2( %i )\n', depth );
% memory();

% if depth > opt.simgrid_max_recursion
% %     if opt.verbose
%         disp( '! Recursion limit exceeded' );
% %     end
%     [ps, t_out, X, Y] = onBlackout( ps, t, x0, y0 );
%     return;
% end

C = psconstants;

%% check whether the last relay event split the system
% Get closed branches
br_status           = ps.branch(:,C.br.status) == C.CLOSED;
% Get connected components
[components, Ncomponents] = findSubGraphs( ...
    ps.bus(:,C.bu.id), ps.branch(br_status,C.br.f:C.br.t) );

comp_queue = java.util.LinkedList;
Ybus_queue = {};
% FIXME: Store triples instead, where the third element indicates whether
% to call subset_xy() or get_xy()
partitioned = Ncomponents > 1;
for i = 1:Ncomponents
    comp_queue.add( [i, t, partitioned] );
    Ybus_queue{i} = ps.Ybus;
%     disp( '1 -----' );
%     disp( ps.Ybus );
end

blackout = true;
while ~comp_queue.isEmpty()    
    qelem = comp_queue.poll();
    comp = qelem(1);
    comp_t = qelem(2);
    comp_partitioned = qelem(3);
    
    comp_Ybus = Ybus_queue{comp};
    Ybus_queue{comp} = [];
    
    if true || opt.verbose
%        memory(); % FIXME: Debugging code
       fprintf( 'comp: %i, comp_t: %f\n', comp, comp_t );
       
    end
    
    subnet = logical(components == comp);
    sub_ps = subsetps( ps, subnet, opt );
%     disp( sub_ps.Ybus );
    sub_ps.Ybus = comp_Ybus;
%     disp( sub_ps.Ybus );
    % FIXME: [hostetje] Debugging code
    fprintf( ' %i', sub_ps.bus(:, C.bu.id)' );
    fprintf( '\n' );
    % [hostetje] merge_odeout() uses && to combine subgrid blackouts, so we
    % need to initialize to 'true' or else ps.blackout will always end up
    % false.
    sub_ps.blackout = false;
    % FIXME: [hostetje] Ncomponents can be > 1 even if there is only one
    % component, if there was a relay event that did not cause a
    % disconnect.
    % FIXME: This is still not right. We need to call subset_xy() whenever
    % sub_ps is *not* the result of splitting some component C, even if C
    % is not the entire grid. Only call get_xy() if sub_ps is the result of
    % splitting a (sub-)grid. 
    if ~comp_partitioned %Ncomponents == 1 % FIXME: This doesn't reliably detect single-component grids
        % FIXME: [hostetje] Move 'subset_xy()' into 'subsetps()'
        [sub_ps.x, sub_ps.y] = subset_xy( ps, sub_ps, opt );
        %sub_ps = ps;
    else
        [sub_ps.x, sub_ps.y] = get_xy( sub_ps, opt );
    end
    
    % FIXME: [hostetje] Debugging code
    if true
        [sub_ps, t_end] = simgrid_component( sub_ps, comp_t, t_next, opt );
    else
        [sub_ps, t_out, X, Y] = simgrid_interval( ...
            0, sub_ps, comp_t, t_next, sub_ps.x, sub_ps.y, opt );
        t_end = t_out(:, end);
        sub_ps.x = X(:, end);
        sub_ps.y = Y(:, end);
    end
    
    ps = merge_odeout( ps, sub_ps, opt );
    blackout = blackout && sub_ps.blackout;
    
    if t_end < t_next
        fprintf( 'simgrid interrupted by relay event\n' );
        
        sub_br_status = sub_ps.branch(:, C.br.status) == C.CLOSED;
        [sub_components, Nsub_components] = findSubGraphs( ...
            sub_ps.bus(:, C.bu.id), sub_ps.branch(sub_br_status, C.br.f:C.br.t) );
        assert( sum(subnet) == length(sub_components) );
        
        sub_partitioned = Nsub_components > 1;
        
        % FIXME: Next we partition the subgraph and add the components to
        % the queue. Make sure they have the right global indices!
        
        % Schedule all components in the subgraph
        fprintf( '\tcomp %i ->', comp );
        for i = 1:Nsub_components
            fprintf( ' %i', (i + Ncomponents) );
            comp_queue.add( [i + Ncomponents, t_end + opt.sim.t_eps, sub_partitioned] );
            
            Ybus_queue{Ncomponents + i} = sub_ps.Ybus;
        end
        fprintf( '\n' );
        
        % Adjust component indices so they are unique
        sub_components = sub_components + Ncomponents;
        components(subnet) = sub_components;
        Ncomponents = Ncomponents + Nsub_components;
    else
        % FIXME: [hostetje] This avoids a special case where outputs would
        % otherwise differ for trivial reasons. I'd prefer to treat all
        % cases uniformly.
        
%         disp( 'Merging:' );
%         disp( sub_ps.y );
%         disp( '...into:' );
%         disp( ps.y );
%         disp( '=====' );
        
%         ps = merge_odeout( ps, sub_ps, opt );
    end
end

ps.blackout = blackout;

% FIXME: [hostetje] Should we merge component Ybus/etc in 'merge_odeout()'?
% ps = update_load_freq_source( ps );
% [ps.Ybus,ps.Yf,ps.Yt,ps.Yft,ps.sh_ft] = getYbus(ps,false);


% %% Simulate each component
% if Ncomponents == 1
%     [ps] = simgrid_component(depth, ps, t,t_next, opt);
% else % Multiple islands
%     for comp = 1:Ncomponents
%         subnet = logical(components == comp);
%         sub_ps = subsetps( ps, subnet );
%         % [hostetje] happens in 'subsetps()' now
% %         [sub_x, sub_y] = get_xy( sub_ps, opt ); 
%         [sub_ps] = simgrid_component( depth, sub_ps, t, t_next, opt );
%         [ps] = merge_odeout( ps, sub_ps, opt );
%     end % for each component
% end

end

