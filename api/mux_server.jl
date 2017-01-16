tic()
using DiffEqBase, DiffEqWebBase, OrdinaryDiffEq, StochasticDiffEq, Calculus, ParameterizedFunctions, Plots, Mux, JSON, HttpCommon
include("sanitation.jl")
plotly()

const algs = Dict{Symbol,DEAlgorithm}(
            :Tsit5 => Tsit5(),
            :Vern6 => Vern6(),
            :Vern7 => Vern7(),
            :BS3 => BS3(),
            :Rosenbrock23 => Rosenbrock23(),
            :SRIW1 => SRIW1(),
            :SRA1 => SRA1())
const opts = Dict{Symbol,Bool}(
    :build_tgrad => false,
    :build_jac => false,
    :build_expjac => false,
    :build_invjac => false,
    :build_invW => false,
    :build_hes => false,
    :build_invhes => false,
    :build_dpfuncs => false)

println("Package loading took this long: ", toq())

# Headers -- set Access-Control-Allow-Origin for either dev or prod
function withHeaders(res, req)
    println("Origin: ", get(req[:headers], "Origin", ""))
    headers  = HttpCommon.headers()
    headers["Content-Type"] = "application/json; charset=utf-8"
    if get(req[:headers], "Origin", "") == "http://localhost:4200"
        headers["Access-Control-Allow-Origin"] = "http://localhost:4200"
    else
        headers["Access-Control-Allow-Origin"] = "http://app.juliadiffeq.org"
    end
    println(headers["Access-Control-Allow-Origin"])
    Dict(
       :headers => headers,
       :body=> res
    )
end

# Better error handling
function errorCatch(app, req)
  try
    app(req)
  catch e
    println("Error occured!")

    io = IOBuffer()
    showerror(io, e)
    err_text = takebuf_string(io)
    println(err_text)
    resp = withHeaders(JSON.json(Dict("message" => err_text, "error" => true)), req)
    resp[:status] = 500
    return resp
  end
end

# A debug endpoint
function wakeup()
    return JSON.json(Dict("data" => Dict("awake" => true), "error" => false))
end

# This endpoint is used for both ODEs and SDEs
function solveit(req::Dict{Any,Any})
    b64 = convert(String, req[:path][1])
    solveit(b64)
end

function solveit(b64::String)
    tic()

    setup_time = @elapsed begin
        strObj = String(base64decode(b64))
        obj = JSON.parse(strObj)
        exstr = string("begin\n", obj["diffEqText"], "\nend")
        sanitize_string(exstr)
        ex = parse(exstr)
        # Need a way to make sure the expression only calls "safe" functions here!!!
        println("Diff equ: ", ex)
        name = Symbol(strObj)
        [sanitize_string(p) for p in obj["parameters"]]
        params = [parse(p) for p in obj["parameters"]]
        println("Params: ", params)

        # Make sure these are always floats
        tspan = (Float64(obj["timeSpan"][1]),Float64(obj["timeSpan"][2]))
        println("tspan: ", tspan)
        u0 = [parse(Float64, u) for u in obj["initialConditions"]]
        println("u0: ", u0)
        # Also need sanitization here!
        sanitize_string(obj["vars"])
        vars = eval(parse(obj["vars"]))
        println("vars: ", vars, " type: ", typeof(vars))
        algstr = obj["solver"]  #Get this from the reqest in the future!
        f = ode_def_opts(name, opts, ex, params...)

        if haskey(obj,"noiseText")
          noise_name = Symbol(strObj*"noise")
          exstr = string("begin\n", obj["noiseText"], "\nend")
          sanitize_string(exstr)
          noise_ex = parse(exstr)
          println("Noise equ: ", ex)
          [sanitize_string(p) for p in obj["noiseParameters"]]
          noise_params = [parse(p) for p in obj["noiseParameters"]]
          g = ode_def_opts(noise_name, opts, noise_ex, noise_params...)
          prob = QuickSDEProblem{Vector{Float64},Float64,true,:Diagonal,typeof(randn)}(f,g,u0,tspan,DiffEqBase.WHITE_NOISE)
        else
          prob = QuickODEProblem{Vector{Float64},Float64,true}(f,u0,tspan)
        end
        alg = algs[parse(algstr)]
    end
    println("Setup time: $setup_time")

    length(f.syms) != length(u0) && error("Initial conditions inconsistent with the differential equation. Make sure there is an initial value for every variable.")
    (maximum(isinf.(u0)) || maximum(isnan.(u0))) && error("Initial conditions must be finite values")

    maxiters = 1e4

    solve_time = @elapsed sol = solve(prob,alg,Vector{Vector{Float64}}(),Vector{Float64}(),[],Val{false},maxiters=maxiters)
    println("Solve time: $solve_time")

    length(sol)>= .9*maxiters && error("Max iterations reached. The equation may be stiff, blow up to infinity, or you choose too long of a timespan. Try the stiff solver (Rosenbrock23 for ODEs) or make sure that the equation has a valid solution. If you need more computing power/time try DifferentialEquations.jl!")

    plot_time = @elapsed p = plot(sol,vars=vars)
    println("Plot time: $plot_time")

    layout = Plots.plotly_layout_json(p)
    series = Plots.plotly_series_json(p)

    res = Dict("layout" =>layout, "series"=>series)
    println("Done, took this long: ", toq())
    return JSON.json(Dict("data" => res, "error" => false))
end

ourStack = stack(Mux.todict, errorCatch, Mux.splitquery, Mux.toresponse)

@app test = (
    ourStack,
    page(req -> withHeaders("Nothing to see here...", req)),
    route("/wakeup", req -> withHeaders(wakeup(), req)),
    route("/solveit", req -> withHeaders(solveit(req), req)),
    Mux.notfound()
)

println("About to start the server!")
@sync serve(test, port=parse(Int64, ARGS[1]))
