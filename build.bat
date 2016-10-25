echo "Building in %cd%"

REM Output directory
set outdir=dist\
if exist "%outdir%" (
	rmdir /S /Q %outdir%
)
md %outdir%

REM Matlab compiler invocation
mcc -d %outdir% -I "data" -I "matlab" -I "numerics" -W "java:jcosmic,JCosmic" "java/init_case9.m" "java/init_case39.m" "java/init_rts96.m" "java/init_case2383.m" "java/show_memory.m" "java/take_action.m" "java/take_action_iter.m" "java/take_action2.m"
