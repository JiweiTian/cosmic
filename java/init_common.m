function [ps, index, opt] = init_common( C, ps, opt, jopt )
%INIT_COMMON Perform initialization tasks that are common to all cases.
%   Detailed explanation goes here

    opt = apply_jopt( opt, jopt );
	ps.event_queue = java.util.LinkedList;
    
    % FIXME: [hostetje] Debugging code
    fprintf( 'Matlab root: ''%s''\n', matlabroot );
    fprintf( 'CTF root   : ''%s''\n', ctfroot );

    % to differentiate the line MVA ratings
    rateB_rateA                     = ps.branch(:,C.br.rateB)./ps.branch(:,C.br.rateA);
    rateC_rateA                     = ps.branch(:,C.br.rateC)./ps.branch(:,C.br.rateA);
    ps.branch(rateB_rateA==1,C.br.rateB)    = 1.1 * ps.branch(rateB_rateA==1,C.br.rateA);
    ps.branch(rateC_rateA==1,C.br.rateC)    = 1.5 * ps.branch(rateC_rateA==1,C.br.rateA);
    
    % initialize the case
    ps = newpf(ps,opt);
    [ps.Ybus,ps.Yf,ps.Yt] = getYbus(ps,false);
    ps = update_load_freq_source(ps);
    % build the machine variables
    [ps.mac,ps.exc,ps.gov] 		= get_mac_state(ps,'salient');
    % initialize relays
    ps.relay                    = get_relays(ps,'all',opt);
    
    %% Initialize global variables
    n    = size(ps.bus,1);
    ng   = size(ps.mac,1);
    m    = size(ps.branch,1);
    n_sh = size(ps.shunt,1);
    index   = get_indices(n,ng,m,n_sh,opt);
    % [20160126:hostetje] Globals now stored as field of 'ps'
    ps = init_global( ps, index, opt );
	
	%% Compute baselines for power fluctuation
	if opt.random.loads
		opt.random.load_Psigma	= opt.random.load_sigma	* ps.shunt(:, C.sh.P);
		opt.random.load_Pmin	= opt.random.load_min	* ps.shunt(:, C.sh.P);
		opt.random.load_Pmax	= opt.random.load_max	* ps.shunt(:, C.sh.P);
		opt.random.load_Qsigma	= opt.random.load_sigma	* ps.shunt(:, C.sh.Q);
		opt.random.load_Qmin	= opt.random.load_min	* ps.shunt(:, C.sh.Q);
		opt.random.load_Qmax	= opt.random.load_max	* ps.shunt(:, C.sh.Q);
	end
end

