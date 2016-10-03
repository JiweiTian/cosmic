function [ opt ] = apply_jopt( opt, jopt )
%APPLY_JOPT Summary of this function goes here
%   Detailed explanation goes here

    % Merge options from Java into 'opt'
    opt.verbose = jopt.verbose;
    opt.simgrid_max_recursion = jopt.simgrid_max_recursion;
    opt.simgrid_method = jopt.simgrid_method;
    % TODO: Make these configurable in Java
    warning( 'off', 'backtrace' );
    warning( 'off', 'verbose' );
end

