function ps = init_global( ps, ix, opt )
%INIT_GLOBAL Initialize global variables common to all problems.

    % [20160126:hostetje] Moved globals to field of 'ps'
%     global t_delay t_prev_check dist2threshold state_a
    ps.t_delay = inf(size(ps.relay,1),1);
    ps.t_delay([ix.re.uvls])= opt.sim.uvls_tdelay_ini;
    ps.t_delay([ix.re.ufls])= opt.sim.ufls_tdelay_ini;
    ps.t_delay([ix.re.dist])= opt.sim.dist_tdelay_ini;
    ps.t_delay([ix.re.temp])= opt.sim.temp_tdelay_ini;
    ps.t_prev_check = nan(size(ps.relay,1),1);
    
    % [hostetje] These arrays are indexed by relay ID in the code. This is
    % inconsistent with the size they are initialized to. The 'oc' relay
    % IDs occupy only the second half of 'dist2threshold' and 'state_a', so
    % the other entries always have their default values. In 'temp', the
    % relay IDs aren't even in the allocated part of 'temp', and the code
    % only works because Matlab implicitly resizes the array.
    %
    % For consistency, I'm initializing these arrays to the number of
    % relays, so that they are explicitly set to their proper default
    % values for relays they don't apply to. 
    % Note: This is memory inefficient, so we might want to use sparse
    % arrays here.
    ps.dist2threshold   = inf(size(ps.relay,1),1);
    ps.state_a          = zeros(size(ps.relay,1),1);
    ps.temp             = zeros(size(ps.relay,1), 1);
    
%     ps.dist2threshold = inf(size(ix.re.oc,2)*2,1);
%     ps.state_a = zeros(size(ix.re.oc,2)*2,1);
%     % The 'temp' global is used by 'endo_event.m', but is never 
%     % explicitly initialized.
%     ps.temp = zeros( size(ix.re.temp,2), 1 );
end
