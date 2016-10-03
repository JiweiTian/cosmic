%% simulate RTS-96 case
clear all; close all; clc; C = psconstants;

% do not touch path if we are deploying code
if ~(ismcc || isdeployed)
    addpath('../data');
    addpath('../numerics');
end

% simulation time
t_max = 40;

% select data case to simulate
ps = updateps(case_rts96_dyn);
ps = unify_generators(ps);  % since some buses have multiple generators.

ps.branch(ps.branch(:,C.br.tap) == 0,C.br.tap) = 1;
ps.branch(:,C.br.rateA) = ps.branch(:,C.br.rateC);

ps.branch(:,C.br.tap)       = 1;
ps.shunt(:,C.sh.frac_S)     = 1;
ps.shunt(:,C.sh.frac_E)     = 0;
ps.shunt(:,C.sh.frac_Z)     = 0;
ps.shunt(:,C.sh.gamma)      = 0.08;

% to differentiate the line MVA ratings if they are the same
rateB_rateA                     = ps.branch(:,C.br.rateB)./ps.branch(:,C.br.rateA);
rateC_rateA                     = ps.branch(:,C.br.rateC)./ps.branch(:,C.br.rateA);
ps.branch(rateB_rateA==1,C.br.rateB)    = 1.1 * ps.branch(rateB_rateA==1,C.br.rateA);
ps.branch(rateC_rateA==1,C.br.rateC)    = 1.5 * ps.branch(rateC_rateA==1,C.br.rateA);


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


% initialize the case
ps = newpf(ps,opt);
[ps.Ybus,ps.Yf,ps.Yt] = getYbus(ps,false);
ps = update_load_freq_source(ps);

% build the machine variables
% keyboard
[ps.mac,ps.exc,ps.gov] 		= get_mac_state(ps,'salient');
% keyboard
% initialize relays
ps.relay                    = get_relays(ps,'all',opt);
% keyboard

% initialize global variables
global t_delay t_prev_check dist2threshold state_a 
n    = size(ps.bus,1);     % number of buses
ng   = size(ps.mac,1);     % number of generators
m    = size(ps.branch,1);  % number of branches
n_sh = size(ps.shunt,1);   % number of loads
ix   = get_indices(n,ng,m,n_sh,opt);
t_delay = inf(size(ps.relay,1),1);
t_delay([ix.re.uvls])= opt.sim.uvls_tdelay_ini;  % 0.5
t_delay([ix.re.ufls])= opt.sim.ufls_tdelay_ini;  % 0.5
t_delay([ix.re.dist])= opt.sim.dist_tdelay_ini;  % 0.5
t_delay([ix.re.temp])= opt.sim.temp_tdelay_ini;  % 0
t_prev_check = nan(size(ps.relay,1),1);
dist2threshold = inf(size(ix.re.oc,2)*2,1);
state_a = zeros(size(ix.re.oc,2)*2,1);

%% build an event matrix
event = zeros(4,C.ev.cols);
% start:
event(1,[C.ev.time C.ev.type]) = [0 C.ev.start];

% % trip a branch:
% event(2,[C.ev.time C.ev.type]) = [10 C.ev.trip_branch];
% % define which branch to trip:
% event(2,C.ev.branch_loc) = 7;

% trip a bus:
event(2,[C.ev.time C.ev.type]) = [10 C.ev.trip_bus];
% define which bus to trip:
event(2,C.ev.bus_loc) = 124;

% end:
event(4,[C.ev.time C.ev.type]) = [t_max C.ev.finish];

%% run the simulation
[outputs,ps] = simgrid(ps,event,'sim_rts96',opt);

%% print the results
fname = outputs.outfilename;
[t,delta,omega,Pm,Eap,Vmag,theta,E1,Efd,P3,Temperature] = read_outfile(fname,ps,opt);
omega_0 = 2*pi*ps.frequency;
omega_pu = omega / omega_0;

% keyboard

figure(1); clf; hold on; 
num_plot = size(omega_pu,2); colorset = varycolor(num_plot);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xtick',[0 600 1200 1800],...
%     'Xlim',[0 50],'Ylim',[0.995 1.008]);
plot(t,omega_pu);
ylabel('\omega (pu)','FontSize',18);
xlabel('time (sec.)','FontSize',18);
% PrintStr = sprintf('OmegaPu_P_%s_%s_%s',CaseName, Contingency, Control);
% print('-dpng','-r600',PrintStr)

figure(2); clf; hold on; 
num_plot = size(theta,2); colorset = varycolor(num_plot);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[-0.2 0.5]);
plot(t,theta);
ylabel('\theta','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(3); clf; hold on; 
num_plot = size(Vmag,2); colorset = varycolor(num_plot);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Vmag);
ylabel('|V|','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(5); clf; hold on; 
num_plot = size(Pm,2); colorset = varycolor(num_plot);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Pm);
ylabel('Pm','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(6); clf; hold on; 
num_plot = size(delta,2); colorset = varycolor(num_plot);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
% plot(t',delta'.*180./pi);
plot(t,delta);
ylabel('Delta','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(7); clf; hold on; 
num_plot = size(Eap,2); colorset = varycolor(num_plot);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Eap);
ylabel('Eap','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(8); clf; hold on; 
num_plot = size(E1,2); colorset = varycolor(num_plot);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,E1);
ylabel('E1','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(9); clf; hold on; 
num_plot = size(Efd,2); colorset = varycolor(num_plot);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Efd);
ylabel('Efd','FontSize',18);
xlabel('time (sec.)','FontSize',18);    

figure(10); clf; hold on; 
num_plot = size(Temperature,2); colorset = varycolor(num_plot);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Temperature);
ylabel('Temperature ( ^{\circ}C)','Interpreter','tex','FontSize',18);
xlabel('time (sec.)','FontSize',18);