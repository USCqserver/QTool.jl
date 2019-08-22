@deprecate solve_davies(
    A::Annealing,
    tf::Real;
    span_unit = false, ω_hint = nothing, lvl = nothing, kwargs...
) solve_ame(
    A::Annealing,
    tf::Real;
    span_unit = false, ω_hint = nothing, lvl = nothing, kwargs...
)


function solve_ame(
    A::Annealing,
    tf::Real;
    span_unit = false, ω_hint = nothing, lvl = nothing, kwargs...
)
    if ndims(A.u0) == 1
        u0 = A.u0 * A.u0'
    else
        u0 = A.u0
    end
    u0 = prepare_u0(u0, A.control)
    tf = prepare_tf(tf, span_unit)
    #
    davies = create_davies(A.coupling, A.bath; ω_range = ω_hint)
    f = AMEDiffEqOperator(A.H, davies; lvl = lvl, control = A.control)
    p = LightAnnealingParams(tf; control = A.control)
    if typeof(A.control) <: PausingControl
        cb = DiscreteCallback(pause_condition, pause_affect!)
        kwargs = Dict{Symbol,Any}(kwargs)
        kwargs[:callback] = cb
    end
    tspan, tstops = scaling_time(tf, A.sspan, A.tstops)
    prob = ODEProblem(f, u0, tspan, p)
    solve(prob; alg_hints = [:nonstiff], tstops = tstops, kwargs...)
end


function solve_ame(
    A::Annealing,
    tf::Vector{T},
    alg,
    para_alg = EnsembleSerial();
    output_func = (sol, i) -> (sol, false),
    span_unit = false,
    ω_hint = nothing,
    lvl = nothing,
    kwargs...
) where T <: Real
    if ndims(A.u0) == 1
        u0 = A.u0 * A.u0'
    else
        u0 = A.u0
    end
    u0 = prepare_u0(u0, A.control)
    t0 = prepare_tf(1.0, span_unit)
    davies = create_davies(A.coupling, A.bath; ω_range = ω_hint)
    f = AMEDiffEqOperator(A.H, davies; lvl = lvl, control = A.control)
    p = LightAnnealingParams(t0; control = A.control)
    # trajectories numbers
    trajectories = length(tf)
    tf_arr = float.(tf)
    # resolve control
    if typeof(A.control) <: PausingControl
        cb = DiscreteCallback(pause_condition, pause_affect!)
        kwargs = Dict{Symbol,Any}(kwargs)
        kwargs[:callback] = cb
    end
    #
    if span_unit == true
        tstops = hyper_tstops(tf_arr, A.tstops)
        prob_func = (prob, i, repeat) -> begin
            tspan = (prob.tspan[1] * tf_arr[i], prob.tspan[2] * tf_arr[i])
            p = set_tf(prob.p, tf_arr[i])
            ODEProblem{true}(prob.f, prob.u0, tspan, p)
        end
    else
        tstops = A.tstops
        prob_func = (prob, i, repeat) -> begin
            p = set_tf(prob.p, tf_arr[i])
            ODEProblem{true}(prob.f, prob.u0, prob.tspan, p)
        end
    end
    prob = ODEProblem{true}(f, u0, A.sspan, p)
    ensemble_prob = EnsembleProblem(
        prob;
        prob_func = prob_func, output_func = output_func
    )
    solve(
        ensemble_prob,
        alg,
        para_alg;
        trajectories = trajectories, tstops = tstops, kwargs...
    )
end


function create_davies(coupling, bath::OhmicBath; ω_range = nothing)
    γ_loc, S_loc = davies_spectrum(bath; ω_range = ω_range)
    DaviesGenerator(coupling, γ_loc, S_loc)
end


function (D::AMEDiffEqOperator{true,T})(du, u, p, t) where T <: PausingControl
    s, a_scale, g_scale = p.control(p.tf, t)
    hmat = D.H(u, a_scale, g_scale, s)
    du.x .= -1.0im * (hmat * u.x - u.x * hmat)
    ω_ba = QTBase.ω_matrix(D.H, D.lvl)
    D.Davies(du, u, ω_ba, p.tf, s)
end


function solve_af_rwa(
    A::Annealing,
    tf::Real;
    span_unit = false, ω_hint = nothing, lvl = nothing, kwargs...
)
    if !(typeof(A.H) <: AdiabaticFrameHamiltonian)
        throw(ArgumentError("Adiabatic Frame RWA equation currently only works for adiabatic frame Hamiltonian."))
    end
    if ndims(A.u0) == 1
        u0 = A.u0 * A.u0'
    else
        u0 = A.u0
    end
    u0 = prepare_u0(u0, A.control)
    tf = prepare_tf(tf, span_unit)
    #
    davies = create_davies(A.coupling, A.bath; ω_range = ω_hint)
    f = AFRWADiffEqOperator(A.H, davies; lvl = lvl, control = A.control)
    p = LightAnnealingParams(tf; control = A.control)
    if typeof(A.control) <: PausingControl
        cb = DiscreteCallback(pause_condition, pause_affect!)
        kwargs = Dict{Symbol,Any}(kwargs)
        kwargs[:callback] = cb
    end
    tspan, tstops = scaling_time(tf, A.sspan, A.tstops)
    prob = ODEProblem(f, u0, tspan, p)
    solve(prob; alg_hints = [:nonstiff], tstops = tstops, kwargs...)
end