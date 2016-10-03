function [ C, ps, index, opt, t, event ] = init_case2383( jopt )
%INIT_CASE2383 Summary of this function goes here
%   Detailed explanation goes here

    C = psconstants;

    % select data case to simulate
    case2383 = load( 'cosmic/data/case2383_mod_ps_dyn.mat' );
    ps = case2383.ps;
    ps.casename = 'poland';
    
    ps.branch(:,C.br.tap)       = 1;
    ps.shunt(:,C.sh.factor)     = 1;
    ps.shunt(:,C.sh.status)     = 1;
    ps.shunt(:,C.sh.frac_S)     = 0;
    ps.shunt(:,C.sh.frac_E)     = 1;
    ps.shunt(:,C.sh.frac_Z)     = 0;
    ps.shunt(:,C.sh.gamma)      = 0.08;

    % to differentiate the line MVA ratings
    rateB_rateA                     = ps.branch(:,C.br.rateB)./ps.branch(:,C.br.rateA);
    rateC_rateA                     = ps.branch(:,C.br.rateC)./ps.branch(:,C.br.rateA);
    ps.branch(rateB_rateA==1,C.br.rateB)    = 1.1 * ps.branch(rateB_rateA==1,C.br.rateA);
    ps.branch(rateC_rateA==1,C.br.rateC)    = 1.5 * ps.branch(rateC_rateA==1,C.br.rateA);

    ps = updateps(ps);
    
    % [hostetje] This is a difference from init_case39(). The Poland case
    % already has IDs defined, so ps.shunt has 12 columns. updateps() then
    % adds columns so there are 14. The former ID column ends up in the
    % current_P column. This is harmless because current_P is not read by
    % Cosmic, but on the Java side we'll get the wrong reward for the
    % initial state.
    % FIXME: The whole 'updateps()' monkey-patching strategy is very
    % bug-prone and you should get rid of it by updating the domain
    % definitions so that they have all the right fields to begin with.
    ps.shunt(:, [C.sh.current_P, C.sh.current_Q]) = 0;

    % initialize the case
    opt = psoptions2383;
    opt.sim.integration_scheme = 1;
    opt.sim.dt_default = 1/30;
%     opt.sim.writelog = true; % [hostetje] Controlled by 'jopt'
    opt.nr.use_fsolve = true;
%     opt.verbose = true; % [hostetje] Controlled by 'jopt'
    opt.sim.gen_control = 1;        % 0 = generator without exciter and governor, 1 = generator with exciter and governor
    opt.sim.angle_ref = 0;          % 0 = delta_sys, 1 = center of inertia---delta_coi
                                    % Center of inertia doesn't work when having islanding
    opt.sim.COI_weight = 1;         % 1 = machine inertia, 0 = machine MVA base(Powerworld)
    opt.sim.uvls_tdelay_ini = 0.5;  % 1 sec delay for uvls relay.
    opt.sim.ufls_tdelay_ini = 0.5;  % 1 sec delay for ufls relay.
    opt.sim.dist_tdelay_ini = 0.5;  % 1 sec delay for dist relay.
    opt.sim.temp_tdelay_ini = 0;    % 0 sec delay for temp relay.
    % Don't forget to change this value (opt.sim.time_delay_ini) in solve_dae.m
    
    %% Common initializaiton
    [ps, index, opt] = init_common( C, ps, opt, jopt );

    %% build an event matrix
    event = zeros(1,C.ev.cols);
    % start
    event(1,[C.ev.time C.ev.type]) = [0 C.ev.start];

    %% simgrid.m begins here
    %% clean up the ps structure
    ps = updateps(ps);

    %% edit the output file name
    start_time = datestr(now,30);
    opt.outfilename = 'cosmic.csv';

    %% prepare the outputs
    outputs.success         = false;
    outputs.t_simulated     = [];
    outputs.outfilename     = opt.outfilename;
    outputs.demand_lost     = 0;
    outputs.computer_time   = [];   ct = clock;
    outputs.start_time      = start_time;     
    ps.event_record         = [];
    event_record            = [];
    outputs.linear_solves   = [];

    %% check the event matrix
    event = sortrows(event);
    if event(1,C.ev.type)~=C.ev.start
        error('simgrid:err','first event should be a start event.');
    end
    t_0   = event(1,1);
    event = event(2:end,:); % remove the start event
%     if event(end,C.ev.type)~=C.ev.finish
%         error('simgrid:err','last event should be a finish event.');
%     end
%     t_end = event(end,1);
    t = t_0;

    %% print something
	if opt.sim.writelog % hostetje: Can disable file creation in config
		out = fopen(opt.outfilename,'w');
		if isempty(out)
			error('simgrid:err','could not open outfile: %s',opt.outfilename);
		end
		fprintf(out,'starting simulation at t = %g\n',t);
		fclose(out);
	end

    if opt.verbose
        fprintf('starting simulation at t = %g\n',t);
        fprintf('writing results to %s\n',opt.outfilename);
    end

    %% get Ybus, x, y
    % build the Ybus
    if ~isfield(ps,'Ybus') || ~isfield(ps,'Yf') || ~isfield(ps,'Yt')
        [ps.Ybus,ps.Yf,ps.Yt] = getYbus(ps,false);
    end
    % build x and y
    ps = init_xy(ps,opt);

end

