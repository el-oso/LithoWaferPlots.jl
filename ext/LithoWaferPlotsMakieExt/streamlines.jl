"""
RK4 streamline tracer for `WaferVectorData`.

Integrates forward and backward from each seed point using a 4th-order
Runge-Kutta scheme. Velocity at arbitrary positions is looked up via
k-nearest-neighbour inverse-distance weighting (NearestNeighbors.jl).

Reference approach: standard RK4 streamline integration, independent derivation.
"""

function _field_interp(tree, vx_src, vy_src, x::Real, y::Real; k::Int=4, power::Float64=2.0)
    idxs, dists = knn(tree, Float64[x, y], k, true)
    dists[1] < 1e-10 && return vx_src[idxs[1]], vy_src[idxs[1]]
    w = dists .^ (-power)
    W = sum(w)
    return sum(w .* vx_src[idxs]) / W, sum(w .* vy_src[idxs]) / W
end

function _rk4_step(tree, vx_src, vy_src, x::Float64, y::Float64, h::Float64)
    k1x, k1y = _field_interp(tree, vx_src, vy_src, x, y)
    k2x, k2y = _field_interp(tree, vx_src, vy_src, x + h/2*k1x, y + h/2*k1y)
    k3x, k3y = _field_interp(tree, vx_src, vy_src, x + h/2*k2x, y + h/2*k2y)
    k4x, k4y = _field_interp(tree, vx_src, vy_src, x + h*k3x,   y + h*k3y)
    nx = x + h/6*(k1x + 2k2x + 2k3x + k4x)
    ny = y + h/6*(k1y + 2k2y + 2k3y + k4y)
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
function trace_streamlines(data::WaferVectorData;
                            n_seeds::Int=20,
                            max_steps::Int=300,
                            step_size::Union{Float64,Nothing}=nothing)
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

    for (sx, sy) in seeds
        seg = Point2f[]
        # forward integration
        x, y = Float64(sx), Float64(sy)
        for _ in 1:max_steps
            push!(seg, Point2f(x, y))
            x, y = _rk4_step(tree, data.vx, data.vy, x, y, h)
            x^2 + y^2 > r_active^2 && break
        end
        # backward integration (prepend)
        x, y = Float64(sx), Float64(sy)
        back = Point2f[]
        for _ in 1:max_steps
            x, y = _rk4_step(tree, data.vx, data.vy, x, y, -h)
            x^2 + y^2 > r_active^2 && break
            pushfirst!(back, Point2f(x, y))
        end
        full = vcat(back, seg)
        length(full) >= 2 && push!(lines, full)
    end
    return lines
end
