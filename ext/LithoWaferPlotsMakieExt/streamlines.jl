"""
RK4 streamline tracer for `WaferVectorData`.

The velocity field is interpolated **once** to a regular `grid_n × grid_n` grid (via
`_vector_to_grid`, inverse-distance weighting), then each streamline is integrated with a
4th-order Runge-Kutta scheme using O(1) bilinear sampling of that grid. This avoids a
nearest-neighbour search at every RK4 sub-step, which dominates the cost of scattered lookup.

Reference approach: standard RK4 streamline integration, independent derivation.
"""

"""
    _grid_velocity(xs, ys, VX, VY, x, y) -> (vx, vy, ok)

Bilinearly sample the velocity grid at `(x, y)`. `xs`/`ys` are uniform `LinRange`
coordinate vectors so the enclosing cell is found in O(1). `ok` is `false` when the point
falls outside the grid or any of the four surrounding nodes is `NaN`.
"""
@inline function _grid_velocity(
        xs::LinRange{Float64}, ys::LinRange{Float64},
        VX::Matrix{Float64}, VY::Matrix{Float64}, x::Float64, y::Float64
    )
    nx = length(xs)
    ny = length(ys)
    dx = step(xs)
    dy = step(ys)

    fx = (x - xs[1]) / dx
    fy = (y - ys[1]) / dy
    i = floor(Int, fx) + 1
    j = floor(Int, fy) + 1
    (i < 1 || i >= nx || j < 1 || j >= ny) && return 0.0, 0.0, false
    tx = fx - (i - 1)
    ty = fy - (j - 1)

    @inbounds begin
        vx00 = VX[i, j]; vx10 = VX[i + 1, j]; vx01 = VX[i, j + 1]; vx11 = VX[i + 1, j + 1]
        vy00 = VY[i, j]; vy10 = VY[i + 1, j]; vy01 = VY[i, j + 1]; vy11 = VY[i + 1, j + 1]
    end
    (isnan(vx00) || isnan(vx10) || isnan(vx01) || isnan(vx11)) && return 0.0, 0.0, false

    a = (1.0 - tx) * (1.0 - ty)
    b = tx * (1.0 - ty)
    c = (1.0 - tx) * ty
    d = tx * ty
    vx = a * vx00 + b * vx10 + c * vx01 + d * vx11
    vy = a * vy00 + b * vy10 + c * vy01 + d * vy11
    return vx, vy, true
end

"""
    _rk4_step_grid(xs, ys, VX, VY, x, y, h) -> (nx, ny, ok)

One RK4 step using bilinear grid sampling. `ok` is `false` if any of the four field
evaluations falls outside the valid grid region (the streamline is then terminated).
"""
@inline function _rk4_step_grid(
        xs::LinRange{Float64}, ys::LinRange{Float64},
        VX::Matrix{Float64}, VY::Matrix{Float64}, x::Float64, y::Float64, h::Float64
    )
    k1x, k1y, ok = _grid_velocity(xs, ys, VX, VY, x, y)
    ok || return x, y, false
    k2x, k2y, ok = _grid_velocity(xs, ys, VX, VY, x + h / 2 * k1x, y + h / 2 * k1y)
    ok || return x, y, false
    k3x, k3y, ok = _grid_velocity(xs, ys, VX, VY, x + h / 2 * k2x, y + h / 2 * k2y)
    ok || return x, y, false
    k4x, k4y, ok = _grid_velocity(xs, ys, VX, VY, x + h * k3x, y + h * k3y)
    ok || return x, y, false
    nx = x + h / 6 * (k1x + 2k2x + 2k3x + k4x)
    ny = y + h / 6 * (k1y + 2k2y + 2k3y + k4y)
    return nx, ny, true
end

"""
    trace_streamlines(data::WaferVectorData; n_seeds=20, max_steps=300, step_size=nothing, grid_n=200)
    -> Vector{Vector{Point2f}}

Trace streamlines through `data`. Returns a vector of point sequences,
one per streamline (forward + backward from each seed).

`n_seeds` seeds are placed on a uniform grid inside the active wafer area.
`step_size` defaults to `diameter_mm / 200`. `grid_n` is the resolution of the velocity
grid used for bilinear sampling (higher = more faithful, slower one-time interpolation).
"""
function trace_streamlines(
        data::WaferVectorData;
        n_seeds::Int = 20,
        max_steps::Int = 300,
        step_size::Union{Float64, Nothing} = nothing,
        grid_n::Int = 200
    )
    r = data.wafer.diameter_mm / 2.0
    r_active = r - data.wafer.edge_exclusion_mm
    r_active2 = r_active^2
    h = something(step_size, data.wafer.diameter_mm / 200.0)

    # Interpolate the field once, out to the full wafer radius so cells bordering the
    # active region have valid corners for bilinear sampling.
    xs, ys, VX, VY = _vector_to_grid(data; grid_n = grid_n, active_only = false)

    # uniform grid seeds inside active area
    seed_xs = LinRange(-r_active * 0.9, r_active * 0.9, n_seeds)
    seed_ys = LinRange(-r_active * 0.9, r_active * 0.9, n_seeds)
    seeds = [(x, y) for x in seed_xs, y in seed_ys if x^2 + y^2 <= r_active2]

    lines = Vector{Vector{Point2f}}()
    sizehint!(lines, length(seeds))

    for (sx, sy) in seeds
        seg = Point2f[]
        # forward integration
        x, y = Float64(sx), Float64(sy)
        for _ in 1:max_steps
            push!(seg, Point2f(x, y))
            x, y, ok = _rk4_step_grid(xs, ys, VX, VY, x, y, h)
            (ok && x^2 + y^2 <= r_active2) || break
        end
        # backward integration (prepend)
        x, y = Float64(sx), Float64(sy)
        back = Point2f[]
        for _ in 1:max_steps
            x, y, ok = _rk4_step_grid(xs, ys, VX, VY, x, y, -h)
            (ok && x^2 + y^2 <= r_active2) || break
            pushfirst!(back, Point2f(x, y))
        end
        full = vcat(back, seg)
        length(full) >= 2 && push!(lines, full)
    end
    return lines
end
