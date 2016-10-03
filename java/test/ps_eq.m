function equal = ps_eq( ps_a, ps_b )
%PS_EQ Compares two 'ps' structures for value equality.
%   Detailed explanation goes here

    old_format = get(0, 'format');
%     format('long');

    tolerance = 1e-3;
    a = orderfields( ps_a );
    b = orderfields( ps_b );
    equal = true;
    F = fieldnames( a );
    for i = 1:length(F)
        % isequaln() (note the 'n') compares NaNs equal to each other
%         equal = isequaln( a, b );
        f = F{i};
        if strcmp( f, 'event_record' ) %... % || strcmp( f, 'Ebus' ) 
                %|| strcmp( f, 'Ybus' ) ...
                %|| strcmp( f, 'Yf' ) || strcmp( f, 'Yt' )
            continue
        end
        fprintf( '>%s<\n', f );
        af = a.(f);
        bf = b.(f);
        if iscell( af ) && iscell( bf )
            equal_f = isequaln( af, bf );
        else 
            nf = ~isfinite( af );
            fn = ~nf;
%             disp( fn );
            nfb = ~isfinite( bf );
            fnb = ~nfb;
%             disp( fnb );
            same_finite = isequal( nf, nfb );
            if ~same_finite
                disp( '! Finite ~= non-finite' );
                disp( find( xor(nf, nfb) ) );
            end
            % Intersection of index sets
            nf = and( nf, nfb );
            fn = and( fn, fnb );
            equal_nf = isequaln( af(nf), bf(nf) );
            if ~equal_nf
                disp( '! Different non-finite values' );
            end
            
%             disp( fn );
            
            % Compute relative error, with 'bf' taken as "truth"
            fn = find(fn);
            df = abs( af(fn) - bf(fn) );    % |df| < |af|
            scale = abs( bf(fn) );          % |scale| = |df| < |af|
            absolute = scale < 1e-6;        % |absolute| = |scale|
            relative = ~absolute;
            % Compare absolute error if "true" value is near 0
            df_absolute = df(absolute);
            df_absolute(df_absolute < 1e-6) = 0;
            % Compare relative error otherwise
            df_relative = df(relative) ./ scale(relative);
            df_relative(df_relative < 1e-2) = 0;
            
            equal_fn_abs = isequal( df_absolute, zeros(size(df_absolute)) );
            if ~equal_fn_abs
                disp( '! Absolute error' );
                fni = fn(absolute);
                disp( fni(df_absolute ~= 0) );
            end
            equal_fn_rel = isequal( df_relative, zeros(size(df_relative)) );
            if ~equal_fn_rel
                disp( '! Relative error' );
                fni = fn(relative);
                disp( fni(df_relative ~= 0) );
            end
%             equal_fn = isequal( df, zeros(size(df)) );
%             equal_f = equal_nf && equal_fn;
            equal_f = same_finite && equal_nf && equal_fn_abs && equal_fn_rel;
        end
        if ~equal_f
            fprintf( 'neq: %s\n', f );
%             disp( [af, bf] );
            disp( af - bf );
            disp( '----------' );
            disp( af );
            disp( '----------' );
            disp( bf );
        end
        equal = equal && equal_f;
    end
    
    set(0,'format', old_format);
end

