function [ps] = merge_odeout( ps, ps1, opt )
% usage: [ps,t_out,X,Y] = superset_odeout(ps,ps1,ps2,t_out1,t_out2,X1,Y1,X2,Y2,opt)
%
% [hostetje] This is a variant of 'superset_odeout()' that merges a single
% subset into the "master" state 'ps'. It appears that mostly we can just
% delete anything with the number '2' in its name, but in a couple of
% places we need to synchronize 'ps1' with 'ps', instead of with 'ps2' as
% the old code does.

C = psconstants;
angle_ref = opt.sim.angle_ref;                 % angle reference: 0:delta_sys,1:delta_coi

is_subgrid = size(ps.bus, 1) ~= size(ps1.bus, 1);

% get number of buses, machines and branches
n   = size(ps.bus,1);   n_macs  = size(ps.mac,1);   m   = size(ps.branch,1);
n1  = size(ps1.bus,1);  n_macs1 = size(ps1.mac,1);  m1  = size(ps1.branch,1);

nxsmac = 7;				% number of differential variables per machine 

% store upstream the ps information from each island
buses1      = ismember(ps.bus(:,1),ps1.bus(:,1));
gens1       = ismember(ps.gen(:,1),ps1.gen(:,1));
shunts1     = ismember(ps.shunt(:,1),ps1.shunt(:,1));
% [20160112:hostetje] Also copy branch data
branches1   = ismember(ps.branch(:,C.br.id), ps1.branch(:,C.br.id));
relx_bu1    = ismember(ps.relay(:,C.re.bus_loc),ps1.relay(ps1.relay(:,C.re.bus_loc)~=0,C.re.bus_loc));
relx_br1    = ismember(ps.relay(:,C.re.branch_loc),ps1.relay(ps1.relay(:,C.re.branch_loc)~=0,C.re.branch_loc));
relx_ge1    = ismember(ps.relay(:,C.re.gen_loc),ps1.relay(ps1.relay(:,C.re.gen_loc)~=0,C.re.gen_loc));
relx_sh1    = ismember(ps.relay(:,C.re.shunt_loc),ps1.relay(ps1.relay(:,C.re.shunt_loc)~=0,C.re.shunt_loc));
relx1       = relx_bu1 | relx_br1 | relx_ge1 | relx_sh1;

if ~angle_ref
    ps.bus(buses1,C.bu.delta_sys)       = ps1.bus(:,C.bu.delta_sys);
end
ps.bus(buses1,C.bu.Vmag:C.bu.Vang)  = ps1.bus(:,C.bu.Vmag:C.bu.Vang);
ps.mac(gens1,C.ma.Eap:C.ma.omega)   = ps1.mac(:,C.ma.Eap:C.ma.omega);
ps.exc(gens1,C.ex.Efd:C.ex.E1)      = ps1.exc(:,C.ex.Efd:C.ex.E1);
ps.relay(relx1,C.re.setting1:C.re.timer_start) = ps1.relay(:,C.re.setting1:C.re.timer_start);
% [20160112:hostetje] Also copy branch and shunt information
% [20160303:hostetje] ...and gov
% ps.branch(ps.branch_i(ps1.branch(:,C.br.id)), C.br.status:C.br.Imag_t) ...
%     = ps1.branch(:, C.br.status:C.br.Imag_t);
ps.branch(ps.branch_i(ps1.branch(:,C.br.id)), 1:C.br.cols) ...
    = ps1.branch(:, 1:C.br.cols);
ps.shunt(ps.shunt_i(ps1.shunt(:,C.sh.id)), C.sh.var_idx) = ps1.shunt(:, C.sh.var_idx);
% [hostetje] The original code does not merge .gov information from
% subgrids. This if-statement replicates that behavior.
if ~is_subgrid
    gov1 = ismember(ps.gov(:,1), ps1.gov(:,1));
    ps.gov(gov1, :) = ps1.gov(:, :);
end
ps.blackout = ps1.blackout && ps.blackout; % Note: ps2 -> ps here

% [hostetje] The original code does not copy Ybus and friends if ps1 is the
% entire grid (ie. not a subgrid). Thus changes are seen by the caller in
% this case. Otherwise, changes are discarded after the simulation step.
if ~is_subgrid
    disp( '***** Copying Ybus' );
    ps.Ebus(:, :)   = ps1.Ebus(:, :);
    ps.Ybus(:, :)   = ps1.Ybus(:, :);
    ps.Yf(:, :)     = ps1.Yf(:, :);
    ps.Yt(:, :)     = ps1.Yt(:, :);
end
% [/20160112:hostetje]

% to avoid losing data when two time range are way differernt, during
% synchronizing time series.

% if t_next > t_out1(end)
%     nt1 = length(t_out1);
%     t_out1 = [t_out1(1:end-1),t_out1(end):opt.sim.dt_default:t_out2(end)];
%     nt1_new = length(t_out1);
%     X1 = [X1,nan(size(X1,1),nt1_new-nt1)];
%     Y1 = [Y1,nan(size(Y1,1),nt1_new-nt1)];
%     ps1.shunt(:,C.sh.factor) = 0;      % where there is a numerical issue like this, declare it blackout.
% end

% ps.shunt(shunts1,C.sh.factor)       = ps1.shunt(:,C.sh.factor);

%{
ts1x        = timeseries(X1',t_out1); ts1y  = timeseries(Y1',t_out1);
ts2x        = timeseries(X2',t_out2); ts2y  = timeseries(Y2',t_out2);
[ts1x, ts2x] = synchronize(ts1x,ts2x,'Uniform','Interval',opt.sim.dt_default);
[ts1y, ts2y] = synchronize(ts1y,ts2y,'Uniform','Interval',opt.sim.dt_default);
X1          = ts1x.Data';   Y1  = ts1y.Data';    
X2          = ts2x.Data';   Y2  = ts2y.Data';
t_out       = ts1x.time';
tk          = length(t_out);
%}

% merge the machine portion of X vectors
if n_macs1>0
    for i = 1:n_macs1
        j = find(ps.mac(:,1) == ps1.mac(i,1));
        ind     = nxsmac*j-(nxsmac-1) : 1 : nxsmac*j ;
        ind1    = nxsmac*i-(nxsmac-1) : 1 : nxsmac*i ;
        ps.x(ind,:) = ps1.x(ind1,:);
    end
end

% merge the temperature portion of X vectors
pars1   = false;
if m1>0
    for i = 1:m1
        j = find(ismember(ps.branch(:,1:2),ps1.branch(i,1:2),'rows'));
        if length(j) > 1
            if length(j) > 2, error('three parallel branches?'); end
            % we have a pair of parallel branches
            if pars1
                % we are on the second one
                j = j(2);
                pars1 = false;
            else
                % we are on the first one
                j = j(1);
                pars1 = true;
            end
        end
        % [hostetje] This is different from 'superset_odeout' because we're
        % not building the result out of two separate vectors
        ps.x(nxsmac*n_macs + j, :)   = ps1.x(nxsmac*n_macs1 + i, :);
    end
end

% [hostetje] If a branch connects ps1 to a different component,
% then the old code will zero it out in superset_odeout() since x
% will be initialized to zeros() and the branch is not present in
% either subgrid. This section preserves that behavior.
cutset = xor( ismember(ps.branch(:, C.br.from), ps1.bus(:,C.bu.id)), ...
              ismember(ps.branch(:, C.br.to), ps1.bus(:,C.bu.id)) );
if sum(cutset) > 0
%     disp( 'Ping!' );
%     fprintf( 'br.from: %i\n', ps.branch(j, C.br.from) );
%     fprintf( 'br.to: %i\n', ps.branch(j, C.br.to) );
%     ps.x(nxsmac*n_macs + j,:) = 0;
    cutset_idx = find(cutset);
    ps.x(nxsmac*n_macs + cutset_idx, :) = 0;
end

% X = [X_macs; X_br];

% to avoid issues of synchronzing data the in the next level, since X_macs
% might be empty
% [hostetje] FIXME: This if-statement appears to do nothing. Is it supposed
% to be 'if isempty(X_macs)' ?
% if isempty(X)
%     X = [X;nan(1,size(X,2))];
% end

% merge the algebraic variables
% if ~angle_ref
%     Y   = zeros(2*n + 1,tk);
% else
%     Y   = zeros(2*n,tk);
% end
for i = 1:n1
    j = find(ps.bus(:,1) == ps1.bus(i,1));
    ps.y((2*j)-1:2*j,:) = ps1.y((2*i)-1:2*i,:);
end
if ~angle_ref
    if ~is_subgrid
        ps.y(end, :) = ps1.y(end,:);
    else
        % [hostetje] If ps1 is a subgrid, then the original code overwrites
        % ps.y with zeroes and doesn't copy the final element (delta_sys).
        % This if-clause preserves that behavior.
        ps.y(end, :) = 0;
    end
end
%{
for i = 1:n2
    j = find(ps.bus(:,1) == ps2.bus(i,1));
    Y((2*j)-1:2*j,:) = Y2((2*i)-1:2*i,:);
end
%}

% merge event record
ps.event_record = unique([ps.event_record; ps1.event_record],'rows');

% FIXME: [hostetje] There's a similar issue here to the one above about
% Ybus, except that this one happens when ps1 *is* a subgrid. This is a
% genuine error, because the relay state should always be updated, but
% apparently the old code does not update it from subgrids.
if true || ~is_subgrid
    % Merge "global" relay state variables
    ps1_relays = ps1.relay(:, C.re.id);
    % disp( 'ps1_relays = ' );
    % disp( ps1_relays );
    ps.t_delay( ps1_relays )        = ps1.t_delay( ps1_relays );
    ps.t_prev_check( ps1_relays )   = ps1.t_prev_check( ps1_relays );
    % These contain oc/temp relays only so we need to exclude other relay IDs
    ps1_d2t = ps1_relays(ps1_relays <= size(ps.dist2threshold, 1));
    % disp( 'ps1_d2t = ' );
    % disp( ps1_d2t );
    % ps1.dist2threshold( ps1_d2t ) = 999999.0; % FIXME: Debugging code
    ps.dist2threshold( ps1_d2t )    = ps1.dist2threshold( ps1_d2t );
    ps1_sa = ps1_relays(ps1_relays <= size(ps.state_a, 1));
    ps.state_a( ps1_sa )            = ps1.state_a( ps1_sa );
    ps1_temp = ps1_relays(ps1_relays <= size(ps1.temp, 1));
    ps.temp( ps1_temp )             = ps1.temp( ps1_temp );
end
