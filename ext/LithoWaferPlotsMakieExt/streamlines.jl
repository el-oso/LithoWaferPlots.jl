"""
RK4 streamline tracer for `WaferVectorData`.

Integrates forward and backward from each seed point using a 4th-order
Runge-Kutta scheme. Velocity at arbitrary positions is looked up via
k-nearest-neighbour inverse-distance weighting (NearestNeighbors.jl).

Reference approach: standard RK4 streamline integration, independent derivation.
"""

function _field_interp(
        tree, vx_src, vy_src, x::Real, y::Real,
        idxs::Vector{Int}, dists::Vector{Float64}, q::Vector{Float64};
        k::Int = 4, power::Float64 = 2.0
    )
    q[1] = Float64(x)
    q[2] = Float64(y)
    knn!(idxs, dists, tree, q, k, true)
    @inbounds begin
        dists[1] < 1.0e-10 && return vx_src[idxs[1]], vy_src[idxs[1]]
        W = 0.0
        ax = 0.0
        ay = 0.0
        for n in 1:k
            wgt = power == 2.0 ? inv(dists[n] * dists[n]) : dists[n]^(-power)
            W += wgt
            ax += wgt * vx_src[idxs[n]]
            ay += wgt * vy_src[idxs[n]]
        end
        return ax / W, ay / W
    end
end

function _rk4_step(
        tree, vx_src, vy_src, x::Float64, y::Float64, h::Float64,
        idxs::Vector{Int}, dists::Vector{Float64}, q::Vector{Float64}
    )
    k1x, k1y = _field_interp(tree, vx_src, vy_src, x, y, idxs, dists, q)
    k2x, k2y = _field_interp(tree, vx_src, vy_src, x + h / 2 * k1x, y + h / 2 * k1y, idxs, dists, q)
    k3x, k3y = _field_interp(tree, vx_src, vy_src, x + h / 2 * k2x, y + h / 2 * k2y, idxs, dists, q)
    k4x, k4y = _field_interp(tree, vx_src, vy_src, x + h * k3x, y + h * k3y, idxs, dists, q)
    nx = x + h / 6 * (k1x + 2k2x + 2k3x + k4x)
    ny = y + h / 6 * (k1y + 2k2y + 2k3y + k4y)
    return nx, ny
end

"""
    trace_streamlines(data::WaferVectorData; n_seeds=20, max_steps=300, step_size=nothing)
    -> Vector{Vector{Point2f}}

Trace streamlines through `data`. Returns a vector of point sequences,
one per streamline (forward + backward from each seed).

`n_seeds` seeds are placed on a uniform grid inside the active wafer area.
`step_size` defaults to `diameter_mm / 200`.
"""
function trace_streamlines(
        data::WaferVectorData;
        n_seeds::Int = 20,
        max_steps::Int = 300,
        step_size::Union{Float64, Nothing} = nothing
    )
    r = data.wafer.diameter_mm / 2.0
    r_active = r - data.wafer.edge_exclusion_mm
    h = something(step_size, data.wafer.diameter_mm / 200.0)

    pts = permutedims(hcat(data.x, data.y))
    tree = KDTree(pts)

    # uniform grid seeds inside active area
    seed_xs = LinRange(-r_active * 0.9, r_active * 0.9, n_seeds)
    seed_ys = LinRange(-r_active * 0.9, r_active * 0.9, n_seeds)
    seeds = [(x, y) for x in seed_xs, y in seed_ys if x^2 + y^2 <= r_active^2]

    lines = Vector{Vector{Point2f}}()
    sizehint!(lines, length(seeds))

    # scratch buffers reused across every RK4 sub-step (k = 4 nearest neighbours)
    k = 4
    idxs = Vector{Int}(undef, k)
    dists = Vector{Float64}(undef, k)
    q = Vector{Float64}(undef, 2)

    for (sx, sy) in seeds
        seg = Point2f[]
        # forward integration
        x, y = Float64(sx), Float64(sy)
        for _ in 1:max_steps
            push!(seg, Point2f(x, y))
            x, y = _rk4_step(tree, data.vx, data.vy, x, y, h, idxs, dists, q)
            x^2 + y^2 > r_active^2 && break
        end
        # backward integration (prepend)
        x, y = Float64(sx), Float64(sy)
        back = Point2f[]
        for _ in 1:max_steps
            x, y = _rk4_step(tree, data.vx, data.vy, x, y, -h, idxs, dists, q)
            x^2 + y^2 > r_active^2 && break
            pushfirst!(back, Point2f(x, y))
        end
        full = vcat(back, seg)
        length(full) >= 2 && push!(lines, full)
    end
    return lines
end
