function [ opt ] = apply_jopt( opt, jopt )
%APPLY_JOPT Summary of this function goes here
%   Detailed explanation goes here

    % Merge options from Java into 'opt'
    opt.verbose = jopt.verbose;
    opt.simgrid_max_recursion = jopt.simgrid_max_recursion;
    opt.simgrid_method = jopt.simgrid_method;
	% [20161026:hostetje] Options for controlling the random generators
	opt.random.gen = jopt.random.gen;
	gen_names = fieldnames(opt.random.gen);
	for i = 1:numel(gen_names)
		temp = rng;
		rng( opt.random.gen.(gen_names{i}).seed );
		opt.random.gen.(gen_names{i}).state = rng;
		rng( temp );
	end
	% [20161025:hostetje] Options for adding noise to simulation
	opt.random.loads		= jopt.random.loads;
	opt.random.load_min		= jopt.random.load_min;
	opt.random.load_max		= jopt.random.load_max;
	opt.random.load_sigma	= jopt.random.load_sigma;
	% TODO: Initialize from 'jopt'
	opt.random.relays		= jopt.random.relays;
	opt.random.relay_mu		= jopt.random.relay_mu;
    % TODO: Make these configurable in Java
    warning( 'off', 'backtrace' );
    warning( 'off', 'verbose' );
end

