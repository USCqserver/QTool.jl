function solve_redfield(A::Annealing, tf::Real, unitary; kwargs...)
    if ndims(A.u0) == 1
        u0 = A.u0*A.u0'
    else
        u0 = A.u0
    end
    opensys = create_redfield(A.coupling, unitary, tf, A.bath)
    p = AnnealingParams(A.H, float(tf); opensys=opensys)
    prob = ODEProblem(von_neumann_open_ode, u0, A.sspan, p)
    solve(prob; alg_hints = [:nonstiff], tstops=A.tstops, kwargs...)
end


function mul_ode(du, u, p, t)
    mul!(du, p.H(t), u)
    lmul!(-1.0im * p.tf, du)
end

function mul_jac(J, u, p, t)
    hmat = p.H(t)
    mul!(J, -1.0im * p.tf, hmat)
end

function von_neumann_ode(du, u, p, t)
    fill!(du, 0.0+0.0im)
    p.H(du, u, p.tf, t)
end

function von_neumann_open_ode(du, u, p, t)
    fill!(du, 0.0+0.0im)
    p.H(du, u, p.tf, t)
    p.opensys(du, u, p, t)
end

function davies_ode(du, u, p, t)
    p.opensys(du, u, p, t)
end


# function adiabatic_frame_ame(hfun, u0, inter_op, γf, sf; rtol=1e-6, atol=1e-6)
#     function f(du, u, p, t)
#         hmat = -1.0im * hfun(t)
#         mul!(du, hmat, u)
#         axpy!(-1.0, u*hmat, du)
#         ω = diag(hmat)
#         ω_ba = repeat(ω, 1, length(ω))
#         ω_ba = transpose(ω_ba) - ω_ba
#         γm = p*γf.(ω_ba)
#         sm = p*sf.(ω_ba)
#         for op in inter_op
#             adiabatic_me_update!(du, u, op(t), γm, sm)
#         end
#     end
#     prob = ODEProblem(f, u0, (0.0, 1.0), tf)
#     sol = solve(prob, Tsit5(), reltol=rtol, abstol=atol, save_everystep=false)
# end