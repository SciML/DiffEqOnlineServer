tic()
using DiffEqBase, DiffEqWebBase, OrdinaryDiffEq, ParameterizedFunctions, Plots, Mux, JSON, HttpCommon
plotly()

println("Package loading took this long: ", toq())

# Handy functions
expr_has_head(s, h) = false
expr_has_head(e::Expr, h::Symbol) = expr_has_head(e, Symbol[h])
function expr_has_head(e::Expr, vh::Vector{Symbol})
    in(e.head, vh) || any(a -> expr_has_head(a, vh), e.args)
end
has_function_def(s::String) = has_function_def(parse(s; raise=false))
has_function_def(e::Expr) = expr_has_head(e, Symbol[:(->), :function])

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

# The ODE endpoint
function solveit(req::Dict{Any,Any})
    b64 = convert(String, req[:path][1])
    solveit(b64)
end

function solveit(b64::String)
    tic()

    setup_time = @elapsed begin
        strObj = String(base64decode(b64))
        obj = JSON.parse(strObj)
        # println(obj)
        # println(" ")

        exstr = string("begin\n", obj["diffEqText"], "\nend")
        if has_function_def(exstr)
            error("Don't define functions in your system of equations...")
        end
        ex = parse(exstr)
        # Need a way to make sure the expression only calls "safe" functions here!!!
        println("Diff equ: ", ex)
        name = Symbol(strObj)
        params = [parse(p) for p in obj["parameters"]]
        println("Params: ", params)
        # Make sure these are always floats
        tspan = (Float64(obj["timeSpan"][1]),Float64(obj["timeSpan"][2]))
        println("tspan: ", tspan)
        u0 = [parse(Float64, u) for u in obj["initialConditions"]]
        println("u0: ", u0)
        # Also need sanitization here!
        if has_function_def(obj["vars"])
            error("Don't define functions in your vars...")
        end
        vars = eval(parse(obj["vars"]))
        println("vars: ", vars, " type: ", typeof(vars))
        algstr = obj["solver"]  #Get this from the reqest in the future!
        algs = Dict{Symbol,OrdinaryDiffEq.OrdinaryDiffEqAlgorithm}(
                    :Tsit5 => Tsit5(),
                    :Vern6 => Vern6(),
                    :Vern7 => Vern7(),
                    :Feagin14 => Feagin14(),
                    :BS3 => BS3(),
                    :Rosenbrock23 => Rosenbrock23())
        opts = Dict{Symbol,Bool}(
            :build_tgrad => false,
            :build_jac => false,
            :build_expjac => false,
            :build_invjac => false,
            :build_invW => false,
            :build_hes => false,
            :build_invhes => false,
            :build_dpfuncs => false)
        f = ode_def_opts(name, opts, ex, params...)
        prob = QuickODEProblem{Vector{Float64},Float64,true}(f,u0,tspan)
        alg = algs[parse(algstr)]
    end
    println("Setup time: $setup_time")

    init_dt_time = @elapsed begin
      dtmax = tspan[end]-tspan[1]
      tdir = sign(dtmax)
      abstol = 1e-6; reltol = 1e-3
      ## Compute initdt without JIT lag
      t = tspan[1]
      f₀ = similar(u0./t); f₁ = similar(u0./t); u₁ = similar(u0)
      sk = abstol+abs.(u0)*reltol
      d₀ = OrdinaryDiffEq.ODE_DEFAULT_NORM(u0./sk)
      f(t,u0,f₀)
      d₁ = OrdinaryDiffEq.ODE_DEFAULT_NORM(f₀./sk)
      if d₀ < 1/10^(5) || d₁ < 1/10^(5)
        dt₀ = 1/10^(6)
      else
        dt₀ = (d₀/d₁)/100
      end
      dt₀ = min(dt₀,tdir*dtmax)
      @inbounds for i in eachindex(u0)
         u₁[i] = u0[i] + tdir*dt₀*f₀[i]
      end
      f(t+tdir*dt₀,u₁,f₁)
      tmp = (f₁.-f₀)./(abstol+abs.(u0)*reltol)
      d₂ = OrdinaryDiffEq.ODE_DEFAULT_NORM(tmp)/dt₀
      if max(d₁,d₂)<=1/10^(15)
        dt₁ = max(1/10^(6),dt₀*1/10^(3))
      else
        dt₁ = 10.0^(-(2+log10(max(d₁,d₂)))/OrdinaryDiffEq.alg_order(alg))
      end
      dt = tdir*min(100dt₀,dt₁)
    end
    println("Init dt time: $init_dt_time")

    maxiters = 1e4

    solve_time = @elapsed sol = solve(prob,alg,Vector{Vector{Float64}}(),Vector{Float64}(),[],Val{false},dt=dt,maxiters=maxiters);
    println("Solve time: $solve_time")

    length(sol)>= maxiters && error("Max iterations reached. The equation may be stiff or blow up to infinity. Try the stiff solver (Rosenbrock23) or make sure that the equation has a valid solution.")

    # Build the plot
    sol_handle_time = @elapsed begin
        plotdensity = 10*length(sol)

        vars = DiffEqBase.interpret_vars(vars,sol)
        newt = collect(linspace(sol.t[1],sol.t[end],plotdensity))
        newu = sol(newt)

        dims = length(vars[1])
        for var in vars
          @assert length(var) == dims
        end
        # Should check that all have the same dims!
        plot_vecs,labels = DiffEqBase.solplot_vecs_and_labels(dims,vars,newu,newt,sol,false)

        xflip = (sol.t[end]-sol.t[1]) < 0
    end
    println("Solution handling time: $sol_handle_time")

    plot_time = @elapsed p = plot(plot_vecs...,labels=reshape(labels,1,length(labels)),lw=3,xflip=xflip)
    println("Plot time: $plot_time")

    layout = Plots.plotly_layout_json(p)
    series = Plots.plotly_series_json(p)

    # Destroy some methods and objects
    ex = 0
    name = 0
    params = 0

    #res = Dict("u" => newu, "t" => newt, "layout" =>layout, "series"=>series)
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
