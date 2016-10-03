function [ps, t_end] = simulate_component( ps, t, t_next, opt )
%SIMULATE_COMPONENT Simulate one component from 't' until either 't_next'
%or a relay event occurs.
%   If the return value t_end < t_next, then a relay event interrupte the
%   simulation.

% constants and data
C           = psconstants;
n           = size(ps.bus,1);
n_macs      = size(ps.mac,1);
m           = size(ps.branch,1);
n_shunts    = size(ps.shunt,1);
j = 1i;

% [hostetje] t_end == t_next unless there is a relay event
t_end = t_next;

angle_ref = opt.sim.angle_ref;                 % angle reference: 0:delta_sys,1:delta_coi
COI_weight = opt.sim.COI_weight;               % weight of center of inertia

if COI_weight
    weight     = ps.mac(:,C.ma.M);
else
    weight     = ps.gen(:,C.ge.mBase);
end

% [hostetje] "nbus = 1" is not a valid condition because there still might
% be both a generator and a load on the bus. 
% || ps.blackout
% || size(ps.bus(:,1),1) == 1)
if n_macs == 0 || n_shunts == 0 ...
        || (ps.shunt(:,C.sh.P)'*ps.shunt(:,C.sh.factor) == 0)
    if opt.verbose
        fprintf( '  t = %.4f: Blackout or trivial island\n', t );
    end
    
    ps = onBlackout( ps, t );
else
    % nothing special (for now), try to integrate the network DAEs from t to t_next
    ix          = get_indices(n,n_macs,m,n_shunts,opt);
    mac_bus_i   = ps.bus_i(ps.mac(:,1));
    ref         = 0;
    temp_ref    = 0;

    % create a temp reference bus if the subgrid doesn't have one
    if ~any(ps.bus(:,C.bu.type) == C.REF)
        [~,ref] = max(ps.gen(:,C.ge.Pmax));
        temp_ref = ps.bus(ismember(ps.bus(:,1),ps.gen(ref,1)),C.bu.type);
        ps.bus(ismember(ps.bus(:,1),ps.gen(ref,1)),C.bu.type) = C.REF;
    end
    
    % recalculate algebraic variables according to the updated Ybus
    try
        y_new = solve_algebraic(t, ps.x, ps.y, ps,opt);
    catch % [hostetje] TODO: Catch particular errors
        y_new = [];
    end
    
    if isempty(y_new)
        if opt.verbose
            fprintf( '  t = %.4f: solve_algebraic failure\n', t );
        end
        % remove temp reference bus, if needed
        ps = removeTempRef( ps, temp_ref, ref );
        ps = onBlackout( ps, t );
        return;
    end
    
    % we should be able to start integrating the DAE for this subgrid
    % [20160113:hostetje] Wrapped in try/catch. Solver failure now
    % sets 'ps.blackout' and returns.
    try
        % trapezoidal rule
        clear fn_f; clear fn_g; clear fn_h;
        fn_f = @(t,x,y) differential_eqs(t,x,y,ps,opt);
        fn_g = @(t,x,y) algebraic_eqs(t,x,y,ps,opt);
        fn_h = @(ps, t,xy,dt) endo_event(t,xy,ix,ps,dt,opt);
        % Note: auxilliary_function() just handles indexing
        fn_aux= @(local_id,ix) auxiliary_function(local_id,ix,ps,opt);
        % [20160126:hostetje] Added 'ps' argument
        % Note: 'y0', *not* 'ps.y', because 'y0' seems to be a *list* of
        % vectors and we don't want to assign that to 'ps.y' yet
        [t_ode,X,Y,Z, ps] = solve_dae( ...
            ps, fn_f,fn_g,fn_h,fn_aux, ps.x, y_new, t:opt.sim.dt_default:t_next,opt);
        XY_ode = [X;Y]';
    catch ex
        switch ex.identifier
            case 'Cosmic:NotConverged'
                if opt.verbose
                    fprintf( '  t = %.4f: Cosmic:NotConverged in solve_dae\n', t );
                end
                ps = removeTempRef( ps, temp_ref, ref );
                ps = onBlackout( ps, t );
                return;
            otherwise
                rethrow( ex );
        end
    end

    % organize data from the DAE output
    t_out       = t_ode';
    x_rows      = (1:ix.nx);
    y_rows      = (ix.nx+1):(ix.nx+ix.ny);
    X           = XY_ode(:,x_rows)';
    Y           = XY_ode(:,y_rows)';
    x_end       = X(:,end);
    y_end       = Y(:,end);

    % store DAE data back into the ps structure
    mac_Thetas  = y_end(ix.y.theta(mac_bus_i));
    deltas      = x_end(ix.x.delta);
    if ~angle_ref
        delta_sys   = y_end(ix.y.delta_sys);
        delta_m     = deltas + delta_sys - mac_Thetas;
    else
        delta_coi   = sum(weight.*deltas,1)/sum(weight,1);
        delta_m     = deltas - delta_coi - mac_Thetas;   % Revisit this
    end
    % [hostetje] We completely overwrite x/y because 'ps' is a subgrid and
    % we will merge it later.
    ps.x = x_end;
    ps.y = y_end;

    ps.mac(:,C.mac.delta_m)     = delta_m;
    ps.mac(:,C.mac.omega)       = x_end(ix.x.omega_pu)*2*pi*ps.frequency;
    ps.mac(:,C.mac.Pm)          = x_end(ix.x.Pm);
    ps.mac(:,C.mac.Eap)         = x_end(ix.x.Eap);
    ps.exc(:,C.ex.E1)       	= x_end(ix.x.E1);
    ps.exc(:,C.ex.Efd)      	= x_end(ix.x.Efd);
    ps.gov(:,C.go.P3)          	= x_end(ix.x.P3);
    ps.bus(:,C.bus.Vmag)        = y_end(ix.y.Vmag);
    ps.bus(:,C.bus.Vang)        = y_end(ix.y.theta)*180/pi;
    ps.relay(ix.re.temp,C.re.state_a) = x_end(ix.x.temp);

    % branch results
    Vmag = y_end(ix.y.Vmag);
    Theta = y_end(ix.y.theta);
    V = Vmag.*exp(j.*Theta);
    If = ps.Yf*V; % branch status is accounted for in Yf
    It = ps.Yt*V; % branch status is accounted for in Yt
    F = ps.bus_i(ps.branch(:,1));
    T = ps.bus_i(ps.branch(:,2));
    Sf = V(F) .* conj(If);
    St = V(T) .* conj(It);
    ps.branch(:,C.br.Imag_f) = abs(If);
    ps.branch(:,C.br.Imag_t) = abs(It);
    ps.branch(:,C.br.Pf) = real(Sf) * ps.baseMVA;
    ps.branch(:,C.br.Qf) = imag(Sf) * ps.baseMVA;
    ps.branch(:,C.br.Pt) = real(St) * ps.baseMVA;
    ps.branch(:,C.br.Qt) = imag(St) * ps.baseMVA;        

    % branch power loss
    Yft = - ps.Yft;
    sh_ft = ps.sh_ft;
    Sft = V(F).*conj((V(F)-V(T)).*Yft + V(F).*sh_ft);
    Stf = V(T).*conj((V(T)-V(F)).*Yft + V(T).*sh_ft);
    lineloss = Sft + Stf;
    negvalue = real(lineloss)<0;
    lineloss(negvalue) = lineloss(negvalue) * -1;
    % FIXME: [hostetje] in case 39, there is a large discrepancy between
    % lineloss for the recursive and iterative simulator implementations,
    % but it occurs only in the imaginary part of 'lineloss' and only on
    % the branch from bus 2 -> bus 30. As a temporary fix, I assign only
    % the real part of lineloss to the 'ps' structure.
    ps.branch(:,C.br.lineloss) = real( lineloss*ps.baseMVA );

    % preparation work for the emergency control
    % calculate resulting ZIPE load after the powerflow
    % get the load bus injections with a ZIPE model
    D               = ps.bus_i(ps.shunt(:,1));
    S_load_base     = (ps.shunt(:,C.sh.P) + j*ps.shunt(:,C.sh.Q)).*ps.shunt(:,C.sh.factor)/ps.baseMVA;
    S_load_P        = S_load_base.*ps.shunt(:,C.sh.frac_S);
    Sd              = sparse(D,3,S_load_P,n,5);
    S_load_Z        = S_load_base.*ps.shunt(:,C.sh.frac_Z);
    Sd              = Sd + sparse(D,1,S_load_Z,n,5);
    S_load_I        = S_load_base.*(1-(ps.shunt(:,C.sh.frac_Z)+ps.shunt(:,C.sh.frac_S)+ps.shunt(:,C.sh.frac_E)));
    Sd              = Sd + sparse(D,2,S_load_I,n,5);
    S_load_E        = S_load_base.*ps.shunt(:,C.sh.frac_E);
    Sd              = Sd + sparse(D,4,S_load_E,n,5);
    S_load_E_gamma  = ps.shunt(:,C.sh.gamma);
    Sd              = Sd + sparse(D,5,S_load_E_gamma,n,5);
    zipe_cols       = 5;   % assuming it is ZIPE model for now
    if zipe_cols == 1
        S_zipe = Sd;
    elseif zipe_cols == 5
        S_Z = Sd(:,1) .* Vmag.^2;
        S_I = Sd(:,2) .* Vmag;
        S_P = Sd(:,3);
        S_E = Sd(:,4) .* Vmag.^Sd(:,5);
        S_zipe = S_Z + S_I + S_P + S_E;
    else
        error('zipe load model matrix is not the right size');
    end

    % [20160107:hostetje] Fixed indexing error: needed to translate
    % shunt id to bus id when looking in 'S_zipe'
    ps.shunt(:,C.sh.current_P) = ...
        real(S_zipe(ps.bus_i(ps.shunt(ps.shunt(:,C.sh.type)==1, C.sh.bus))))* ps.baseMVA ;
    ps.shunt(:,C.sh.current_Q) = ...
        imag(S_zipe(ps.bus_i(ps.shunt(ps.shunt(:,C.sh.type)==1, C.sh.bus))))* ps.baseMVA ;

    % remove temp reference bus, if needed
    ps = removeTempRef( ps, temp_ref, ref );

    relay_event = Z;
    % if there was a relay event, apply it.
    if ~isempty(relay_event)
        t_event = t_out(end);
        % process reley event
        [ps] = process_relay_event(t_event,relay_event,ps,opt);
        % [hostetje] Added min() here to ensure that t_down <= t_next
        % [hostetje] If t_end < t_next, caller will enqueue another
        % simulation step.
        t_end = min( t_event + opt.sim.t_eps, t_next );
    end
end % Big if

end

% -----------------------------------------------------------------------

function ps = removeTempRef( ps, temp_ref, ref )
    C = psconstants;
    if temp_ref
        ps.bus(ismember(ps.bus(:,1),ps.gen(ref,1)),C.bu.type) = temp_ref;
    end
end

function [ps] = onBlackout( ps, t )
    C = psconstants;
    
    ps.x = nan(size(ps.x));
    ps.y = nan(size(ps.y));
    
    % [20160111:hostetje] Zero out branch power flow so that we don't
    % have to look in x/y to find out if they're dead.
    if ~isempty( ps.branch )
        ps.branch(:, C.br.var_idx) = 0;
    end
    if ~isempty( ps.shunt )
        ps.shunt(:, C.sh.var_idx) = 0;
        % FIXME: It's not really correct to set factor to 0, since we
        % didn't turn off the shunts, they're just out of power. I'm
        % leaving it because I suspect other code relies on it and we
        % never try to re-connect anyway.
        ps.shunt(:,C.sh.factor) = 0;
    end
    ps.blackout = true;
end
