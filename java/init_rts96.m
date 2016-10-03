function [ C, ps, index, opt, t, event ] = init_case39( jopt )
%INIT_CASE39 Summary of this function goes here
%   Detailed explanation goes here

	C = psconstants;

	% simulation time
	t_max = 40;

	% select data case to simulate
	% [hostetje] Note we use the '_java' version
	ps = updateps(case_rts96_dyn_java);
	ps = unify_generators(ps);  % since some buses have multiple generators.

	ps.branch(ps.branch(:,C.br.tap) == 0,C.br.tap) = 1;
	ps.branch(:,C.br.rateA) = ps.branch(:,C.br.rateC);

	ps.branch(:,C.br.tap)       = 1;
	ps.shunt(:,C.sh.frac_S)     = 1;
	ps.shunt(:,C.sh.frac_E)     = 0;
	ps.shunt(:,C.sh.frac_Z)     = 0;
	ps.shunt(:,C.sh.gamma)      = 0.08;

	% set some options
	opt = psoptions;
	opt.sim.integration_scheme = 1;
	opt.sim.dt_default = 1/30;
	opt.nr.use_fsolve = true;
	% opt.pf.linesearch = 'cubic_spline';
	opt.verbose = true;
	opt.sim.gen_control = 1;        % 0 = generator without exciter and governor, 1 = generator with exciter and governor
	opt.sim.angle_ref = 0;          % 0 = delta_sys, 1 = center of inertia---delta_coi
									% Now, center of inertia doesn't work when having islanding
	opt.sim.COI_weight = 0;         % 1 = machine inertia, 0 = machine MVA base(Powerworld) 
	% COI doesn't work for islanding scenario for now
	opt.sim.uvls_tdelay_ini = 0.5;  % 1 sec delay for uvls relay.
	opt.sim.ufls_tdelay_ini = 0.5;  % 1 sec delay for ufls relay.
	opt.sim.dist_tdelay_ini = 0.5;  % 1 sec delay for dist relay.
	opt.sim.temp_tdelay_ini = 0;    % 0 sec delay for temp relay.
	% Don't forget to change this value (opt.sim.time_delay_ini) in solve_dae.m

	%% Common initializaiton
    [ps, index, opt] = init_common( C, ps, opt, jopt );

	%% build an event matrix
	event = zeros(4,C.ev.cols);
	% start:
	event(1,[C.ev.time C.ev.type]) = [0 C.ev.start];

	%% -------------------------------------------------
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
