"""
Makie recipes for scalar wafer plots: WaferScatter, WaferHeatmap, WaferContour.

All recipes automatically overlay the wafer boundary and optional field patches.
Performance target: 300 000 points rendered in < 0.3s (GLMakie GPU path).
"""

# ── WaferScatter ────────────────────────────────────────────────────────────

@recipe WaferScatter (data,) begin
    Makie.documented_attributes(Scatter)...
    markersize = 3.0f0
    boundary_color = :black
    boundary_linewidth = 1.5f0
    field_color = FIELD_COLOR
    field_strokecolor = FIELD_STROKECOLOR
    field_strokewidth = FIELD_STROKEWIDTH
    draw_boundary = true
    draw_fields = true
end

function Makie.plot!(p::WaferScatter)
    data = p[:data][]
    mask = inside_wafer(data.x, data.y, data.wafer)
    x, y, vals = data.x[mask], data.y[mask], data.values[mask]
    cs = ColorScale(vals)

    scatter!(
        p, p.attributes, x, y;
        color = vals,
        colorrange = (Float32(cs.vmin), Float32(cs.vmax))
    )

    p[:draw_boundary][] && draw_wafer_boundary!(
        p, data.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    p[:draw_fields][] && draw_fields!(
        p, data.fields;
        color = p[:field_color][],
        strokecolor = p[:field_strokecolor][],
        strokewidth = p[:field_strokewidth][]
    )

    return p
end

# ── WaferHeatmap ────────────────────────────────────────────────────────────
# Default: renders coloured scatter rects (fast GPU path, any point layout).
# When imagemode=:image (or :auto with n > IMAGE_THRESHOLD), interpolates to a
# regular grid and renders a single image! texture — faster for CairoMakie export
# and memory-efficient for very large datasets.

const IMAGE_THRESHOLD = 5_000

@recipe WaferHeatmap (data,) begin
    Makie.documented_attributes(Scatter)...
    Makie.filtered_attributes(Image; allow = (:interpolate,))...
    colormap = :inferno
    markersize = 4.0f0
    marker = :rect
    boundary_color = :black
    boundary_linewidth = 1.5f0
    field_color = FIELD_COLOR
    field_strokecolor = FIELD_STROKECOLOR
    field_strokewidth = FIELD_STROKEWIDTH
    percentile_clip = 0.0
    imagemode = :auto
    grid_n = 256
    draw_boundary = true
    draw_fields = true
end

function Makie.plot!(p::WaferHeatmap)
    data = p[:data][]
    mask = inside_wafer(data.x, data.y, data.wafer)
    x, y, vals = data.x[mask], data.y[mask], data.values[mask]
    cs = ColorScale(vals; percentile_clip = p[:percentile_clip][])
    # An explicitly provided colorrange (e.g. a scale shared across several wafers)
    # overrides the one computed from this dataset alone.
    cr = p[:colorrange][]
    vmin, vmax = cr === Makie.automatic ?
        (Float32(cs.vmin), Float32(cs.vmax)) : (Float32(cr[1]), Float32(cr[2]))
    mode = p[:imagemode][]
    use_image = mode === :image || (mode === :auto && length(x) >= IMAGE_THRESHOLD)

    if use_image
        _heatmap_image!(p, data, x, y, vals, vmin, vmax)
    else
        scatter!(
            p, p.attributes, x, y;
            color = vals,
            colorrange = (vmin, vmax)
        )
    end

    p[:draw_boundary][] && draw_wafer_boundary!(
        p, data.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    p[:draw_fields][] && draw_fields!(
        p, data.fields;
        color = p[:field_color][],
        strokecolor = p[:field_strokecolor][],
        strokewidth = p[:field_strokewidth][]
    )

    return p
end

function _heatmap_image!(p, data, x, y, vals, vmin::Float32, vmax::Float32)
    grid_n = p[:grid_n][]
    r = data.wafer.diameter_mm / 2.0
    xs = LinRange(-r, r, grid_n)
    ys = LinRange(-r, r, grid_n)
    cell = Float64(xs[2] - xs[1])

    # Paint out to the true wafer edge, not the (smaller) edge-exclusion radius used to
    # decide which measured points feed the interpolation — `x`/`y`/`vals` are already
    # filtered to the active region by the caller, so this only changes how far the
    # continuous IDW field is *drawn*, not which points are treated as real measurements.
    # Filtering to the exclusion radius here left an unpainted annulus between the raster
    # and the drawn wafer boundary, exposing the raster's own stair-stepped edge instead of
    # having the boundary line sit on top of (and hide) it. The last `cell` mm of coverage
    # is alpha-feathered so the circular cutoff itself is anti-aliased rather than jagged.
    cmap = Makie.to_colormap(p[:colormap][])
    pts = permutedims(hcat(Float64.(x), Float64.(y)))
    tree = KDTree(pts; leafsize = KDTREE_LEAFSIZE)

    k = 4
    idxs = Vector{Int}(undef, k)
    dists = Vector{Float64}(undef, k)
    q = Vector{Float64}(undef, 2)

    img = fill(RGBAf(0.0f0, 0.0f0, 0.0f0, 0.0f0), grid_n, grid_n)
    for (j, yg) in enumerate(ys), (i, xg) in enumerate(xs)
        rad = hypot(xg, yg)
        rad > r && continue
        q[1] = xg
        q[2] = yg
        knn!(idxs, dists, tree, q, k, true)
        v = @inbounds if dists[1] < 1.0e-10
            Float64(vals[idxs[1]])
        else
            W = zero(eltype(dists))
            acc = zero(eltype(dists))
            for n in 1:k
                wgt = inv(dists[n] * dists[n])
                W += wgt
                acc += wgt * Float64(vals[idxs[n]])
            end
            acc / W
        end
        cn = clamp(Float32((v - vmin) / (vmax - vmin)), 0.0f0, 1.0f0)
        col = Makie.interpolated_getindex(cmap, cn)
        edge_alpha = clamp(Float32((r - rad) / cell), 0.0f0, 1.0f0)
        img[i, j] = RGBAf(col.r, col.g, col.b, col.alpha * edge_alpha)
    end

    # Makie 0.22+ requires interval notation (start..stop) for image! axes. `colorrange`
    # is stored on the Image plot purely as metadata for `add_colorbar!` to read back
    # (the raster itself is already-baked RGBA, so it plays no role in rendering) —
    # passed last so it overrides whatever `p.attributes[:colorrange]` holds (possibly
    # the `Makie.automatic` sentinel).
    image!(p, p.attributes, (-r) .. r, (-r) .. r, img; colorrange = (vmin, vmax))
    return nothing
end

# ── WaferContour ────────────────────────────────────────────────────────────
# Interpolates scattered data to a regular grid, then calls contour!.

@recipe WaferContour (data,) begin
    Makie.documented_attributes(Contour)...
    colormap = :viridis
    levels = 10
    grid_n = 256
    boundary_color = :black
    boundary_linewidth = 1.5f0
    field_color = FIELD_COLOR
    field_strokecolor = FIELD_STROKECOLOR
    field_strokewidth = FIELD_STROKEWIDTH
    draw_boundary = true
    draw_fields = true
end

function Makie.plot!(p::WaferContour)
    data = p[:data][]
    grid_n = p[:grid_n][]
    r = data.wafer.diameter_mm / 2.0

    # Interpolate onto a polar grid covering exactly the active disk. A square grid would
    # need NaN outside the wafer, and NaN vertices make Makie 0.24.15's contour tracing
    # throw. The point count roughly matches the in-wafer part of a `grid_n`-wide square
    # grid; radial spacing equals that grid's, angular spacing is ~2x coarser at the rim.
    r_active = r - data.wafer.edge_exclusion_mm
    ρs = LinRange(0.0, r_active, cld(grid_n, 2) + 1)
    θs = LinRange(0.0, 2π, ceil(Int, π * grid_n / 2) + 1)
    X = [ρ * cos(θ) for ρ in ρs, θ in θs]
    Y = [ρ * sin(θ) for ρ in ρs, θ in θs]

    # Inverse-distance-squared weighting of the 4 nearest measurements. Per-point `knn!`
    # into reused buffers: the batched `knn` is no faster here and allocates two small
    # vectors per grid point. Radial-first iteration over the grid is marginally faster
    # than ring-first.
    tree = KDTree(permutedims(hcat(data.x, data.y)); leafsize = KDTREE_LEAFSIZE)
    k = 4
    idxs = Vector{Int}(undef, k)
    dists = Vector{Float64}(undef, k)
    q = Vector{Float64}(undef, 2)
    vals_src = data.values
    Z = similar(X, Float32)
    for I in eachindex(X, Y, Z)
        q[1] = X[I]
        q[2] = Y[I]
        knn!(idxs, dists, tree, q, k, true)
        if first(dists) < 1.0e-10
            Z[I] = Float32(vals_src[first(idxs)])
        else
            W = zero(eltype(dists))
            acc = zero(eltype(dists))
            for n in eachindex(idxs, dists)
                wgt = inv(dists[n]^2)
                W += wgt
                acc += wgt * vals_src[idxs[n]]
            end
            Z[I] = Float32(acc / W)
        end
    end

    contour!(p, p.attributes, X, Y, Z)

    p[:draw_boundary][] && draw_wafer_boundary!(
        p, data.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    p[:draw_fields][] && draw_fields!(
        p, data.fields;
        color = p[:field_color][],
        strokecolor = p[:field_strokecolor][],
        strokewidth = p[:field_strokewidth][]
    )

    return p
end
