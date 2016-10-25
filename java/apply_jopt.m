function [ opt ] = apply_jopt( opt, jopt )
%APPLY_JOPT Summary of this function goes here
%   Detailed explanation goes here

    % Merge options from Java into 'opt'
    opt.verbose = jopt.verbose;
    opt.simgrid_max_recursion = jopt.simgrid_max_recursion;
    opt.simgrid_method = jopt.simgrid_method;
	% [20161025:hostetje] Options for adding noise to simulation
	opt.random.loads = jopt.random.loads;
	opt.random.load_max = jopt.random.load_max;
	opt.random.load_variance = jopt.random.load_variance;
    % TODO: Make these configurable in Java
    warning( 'off', 'backtrace' );
    warning( 'off', 'verbose' );
end

