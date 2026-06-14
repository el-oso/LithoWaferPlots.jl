"""
Divergence and vorticity computation from scattered vector field data.

Both functions interpolate the scattered (x, y, vx, vy) data to a regular N×N grid
using inverse-distance weighting (k-nearest neighbours via NearestNeighbors.jl),
then apply central finite differences to compute the scalar field.
"""

"""
    _idw_interpolate(tree, src_vx, src_vy, gx, gy; k=8, power=2.0)

Inverse-distance-weighted interpolation of (vx, vy) at grid point (gx, gy).
"""
function _idw_interpolate(tree, src_vx, src_vy, gx::Real, gy::Real; k::Int = 8, power::Float64 = 2.0)
    idxs, dists = knn(tree, [Float64(gx), Float64(gy)], k, true)
    if dists[1] < 1.0e-10
        return src_vx[idxs[1]], src_vy[idxs[1]]
    end
    w = dists .^ (-power)
    W = sum(w)
    vx = sum(w .* src_vx[idxs]) / W
    vy = sum(w .* src_vy[idxs]) / W
    return vx, vy
end

"""
    _vector_to_grid(data::WaferVectorData; grid_n::Int=256)

Interpolate scattered vector data to a regular `grid_n × grid_n` grid.
Returns `(xs, ys, VX, VY)` where `xs`/`ys` are 1D coordinate vectors and
`VX`/`VY` are `grid_n × grid_n` matrices.
"""
function _vector_to_grid(data::WaferVectorData; grid_n::Int = 256)
    r = data.wafer.diameter_mm / 2.0
    xs = LinRange(-r, r, grid_n)
    ys = LinRange(-r, r, grid_n)

    pts = permutedims(hcat(data.x, data.y))  # 2 × N matrix for KDTree
    tree = KDTree(pts)

    VX = Matrix{Float64}(undef, grid_n, grid_n)
    VY = Matrix{Float64}(undef, grid_n, grid_n)

    r_active2 = (r - data.wafer.edge_exclusion_mm)^2
    for (j, y) in enumerate(ys), (i, x) in enumerate(xs)
        if x^2 + y^2 <= r_active2
            VX[i, j], VY[i, j] = _idw_interpolate(tree, data.vx, data.vy, x, y)
        else
            VX[i, j] = VY[i, j] = NaN
        end
    end
    return xs, ys, VX, VY
end

"""
    divergence(data::WaferVectorData; grid_n::Int=256) -> WaferData{Float64}

Compute ∂vx/∂x + ∂vy/∂y from scattered vector field data.
Returns a `WaferData` suitable for display as a scalar heatmap.
"""
function divergence(data::WaferVectorData; grid_n::Int = 256)
    xs, ys, VX, VY = _vector_to_grid(data; grid_n)
    dx = Float64(xs[2] - xs[1])
    dy = Float64(ys[2] - ys[1])

    D = Matrix{Float64}(undef, grid_n, grid_n)
    for j in 1:grid_n, i in 1:grid_n
        dvx_dx = i == 1 ? (VX[2, j] - VX[1, j]) / dx :
            i == grid_n ? (VX[end, j] - VX[end - 1, j]) / dx :
            (VX[i + 1, j] - VX[i - 1, j]) / (2dx)
        dvy_dy = j == 1 ? (VY[i, 2] - VY[i, 1]) / dy :
            j == grid_n ? (VY[i, end] - VY[i, end - 1]) / dy :
            (VY[i, j + 1] - VY[i, j - 1]) / (2dy)
        D[i, j] = dvx_dx + dvy_dy
    end

    gx = [x for x in xs for _ in ys]
    gy = [y for _ in xs for y in ys]
    vals = vec(D)
    mask = .!isnan.(vals)
    return WaferData(gx[mask], gy[mask], vals[mask], data.wafer, data.fields)
end

"""
    vorticity(data::WaferVectorData; grid_n::Int=256) -> WaferData{Float64}

Compute ∂vy/∂x - ∂vx/∂y (z-component of curl) from scattered vector field data.
Returns a `WaferData` suitable for display as a scalar heatmap.
"""
function vorticity(data::WaferVectorData; grid_n::Int = 256)
    xs, ys, VX, VY = _vector_to_grid(data; grid_n)
    dx = Float64(xs[2] - xs[1])
    dy = Float64(ys[2] - ys[1])

    W = Matrix{Float64}(undef, grid_n, grid_n)
    for j in 1:grid_n, i in 1:grid_n
        dvy_dx = i == 1 ? (VY[2, j] - VY[1, j]) / dx :
            i == grid_n ? (VY[end, j] - VY[end - 1, j]) / dx :
            (VY[i + 1, j] - VY[i - 1, j]) / (2dx)
        dvx_dy = j == 1 ? (VX[i, 2] - VX[i, 1]) / dy :
            j == grid_n ? (VX[i, end] - VX[i, end - 1]) / dy :
            (VX[i, j + 1] - VX[i, j - 1]) / (2dy)
        W[i, j] = dvy_dx - dvx_dy
    end

    gx = [x for x in xs for _ in ys]
    gy = [y for _ in xs for y in ys]
    vals = vec(W)
    mask = .!isnan.(vals)
    return WaferData(gx[mask], gy[mask], vals[mask], data.wafer, data.fields)
end
