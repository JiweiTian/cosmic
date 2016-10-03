function [ C, ps, index, opt, t, x, y, event ] = init_case9( jopt )
%INIT_CASE9 Summary of this function goes here
%   Detailed explanation goes here

    C = psconstants;

    % simulation time
%     t_max = 30;

    % select data case to simulate
    ps = updateps(case9_ps);
    ps.branch(:,C.br.tap)       = 1;
    ps.shunt(:,C.sh.frac_S)     = 1;
    ps.shunt(:,C.sh.frac_E)     = 0;
    ps.shunt(:,C.sh.frac_Z)     = 0;
    ps.shunt(:,C.sh.gamma)      = 0.08;
    
    %% Common initializaiton
    [ps, index, opt] = init_common( C, ps, jopt );

    %% build an event matrix
    event = zeros(4,C.ev.cols);
    % start
    event(1,[C.ev.time C.ev.type]) = [0 C.ev.start];
    % trip a branch
    event(2,[C.ev.time C.ev.type]) = [10 C.ev.trip_branch];
    event(2,C.ev.branch_loc) = 6;
    % trip a branch
    % event(3,[C.ev.time C.ev.type]) = [10 C.ev.trip_branch];
    % event(3,C.ev.branch_loc) = 6;
    % % close a branch
    % event(3,[C.ev.time C.ev.type]) = [10.1 C.ev.close_branch];
    % event(3,C.ev.branch_loc) = 7;
    % % trip a shunt
    % event(2,[C.ev.time C.ev.type]) = [10 C.ev.trip_shunt];
    % event(2,C.ev.shunt_loc) = 1;

    % set the end time
%     event(4,[C.ev.time C.ev.type]) = [t_max C.ev.finish];

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

