function test_merge_odeout()
%TEST_MERGE_ODEOUT Summary of this function goes here
%   Detailed explanation goes here

    jopt.verbose = true;
    jopt.simgrid_max_recursion = 200;
    jopt.simgrid_method = 'iterative';
    
    [ C, ps_0, index, opt, t, event ] = init_case39( jopt );
    [ C, ps_ref, index, opt, t, event ] = init_case39( jopt );
    [ C, ps_test, index, opt, t, event ] = init_case39( jopt );
    
    assert( ps_eq( ps_test, ps_ref ) );
    
    % merge_odeout() should be idempotent
    ps_test = merge_odeout( ps_test, ps_test, opt );
    assert( ps_eq( ps_test, ps_ref ) );
    
    % Changing properties in-place should be equivalent to changing them in
    % a subset network and then merging the result
    subnet = 10:20;
    % in-place
    ps_ref.bus(subnet, C.bus.Vmag) = 0.5;
    assert( ~ps_eq( ps_ref, ps_0 ) );
    % subset
    ps_sub = subsetps( ps_test, subnet, opt );
    ps_sub.bus(:, C.bus.Vmag) = 0.5;
    ps_test = merge_odeout( ps_test, ps_sub, opt );
    assert( ps_eq( ps_test, ps_ref ) );
    assert( ~ps_eq( ps_test, ps_0 ) );
end

