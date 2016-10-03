function index = get_index_for_ps( ps, opt )
%GET_INDEX_FOR_PS Convenience wrapper for 'get_indices()' that takes 'ps'
%as its argument.

    %% Initialize global variables
    n    = size(ps.bus,1);
    ng   = size(ps.mac,1);
    m    = size(ps.branch,1);
    n_sh = size(ps.shunt,1);
    index   = get_indices(n,ng,m,n_sh,opt);
end

