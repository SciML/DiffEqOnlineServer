using JuliaWebAPI, Logging, Compat, ZMQ, DifferentialEquations, Plots
exstr = """begin
dx = a*x - b*x*y
dy = -c*y + d*x*y
end
"""
ex = parse(exstr)
name = Symbol(exstr)
params = [parse(p) for p in ["a=>1.5", "b=>1", "c=3", "d=1"]]
tspan = (0.0,10.0)
u0 = [1.0,1.0];
opts = Dict{Symbol,Bool}(
    :build_tgrad => true,
    :build_jac => true,
    :build_expjac => false,
    :build_invjac => true,
    :build_invW => true,
    :build_hes => false,
    :build_invhes => false,
    :build_dpfuncs => true)
f = ode_def_opts(name, opts, ex, params...)

prob = ODEProblem(f,u0,tspan)
sol = solve(prob);
println(sol)
