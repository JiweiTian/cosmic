function [ sub_x, sub_y ] = subset_xy( ps, sub_ps, opt )
%SUBSET_XY Summary of this function goes here
%   Detailed explanation goes here

    C = psconstants;
    angle_ref = opt.sim.angle_ref;                 % angle reference: 0:delta_sys,1:delta_coi

    % get number of buses, machines and branches
    n   = size(ps.bus,1);   n_macs  = size(ps.mac,1);   m   = size(ps.branch,1);
    n1  = size(sub_ps.bus,1);  n_macs1 = size(sub_ps.mac,1);  m1  = size(sub_ps.branch,1);

    nxsmac = 7;				% number of differential variables per machine 

    % merge the machine portion of X vectors
    sub_x = zeros( n_macs1 * nxsmac + m1, 1 );
    if n_macs1>0
        for i = 1:n_macs1
            j = find(ps.mac(:,1) == sub_ps.mac(i,1));
            ind     = nxsmac*j-(nxsmac-1) : 1 : nxsmac*j ;
            ind1    = nxsmac*i-(nxsmac-1) : 1 : nxsmac*i ;
            sub_x(ind1, :) = ps.x(ind,:);
        end
    end

    % merge the temperature portion of X vectors
    pars1   = false;
    if m1>0
        for i = 1:m1
            j = find(ismember(ps.branch(:,1:2),sub_ps.branch(i,1:2),'rows'));
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
            sub_x(nxsmac*n_macs1 + i, :) = ps.x(nxsmac*n_macs + j, :);
        end
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
    if ~angle_ref
        sub_y = zeros( 2*n1 + 1, 1 );
        sub_y( end, 1 ) = ps.y( end, 1 );
    else
        sub_y = zeros( 2*n1, 1 );
    end
    for i = 1:n1
        j = find(ps.bus(:,1) == sub_ps.bus(i,1));
        sub_y(((2*i)-1):(2*i), :) = ps.y((2*j)-1:2*j,:);
    end
end

