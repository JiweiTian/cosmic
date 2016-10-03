function [ps] = simgrid_interval2(depth, ps, t,t_next, opt)

% C = psconstants;
% angle_ref = opt.sim.angle_ref;                 % angle reference: 0:delta_sys,1:delta_coi
% 
% % get number of buses, machines and branches
% n   = size(ps.bus,1);   n_macs  = size(ps.mac,1);   m   = size(ps.branch,1);
% 
% nxsmac = 7;				% number of differential variables per machine 
% 
% % Allocate space for results
% X = zeros( nxsmac*n_macs + m, 1 );
% if ~angle_ref
%     Y   = zeros( 2*n + 1, 1 );
% else
%     Y   = zeros( 2*n, 1 );
% end

% [hostetje] FIXME is there any need for the wrapper?
[ps] = simgrid_split( depth, ps, t, t_next, opt );

end % Function
