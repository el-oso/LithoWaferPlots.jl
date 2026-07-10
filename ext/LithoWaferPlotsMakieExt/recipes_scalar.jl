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
    field_color = (:steelblue, 0.15)
    field_strokecolor = :steelblue
    field_strokewidth = 0.8f0
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
    field_color = (:steelblue, 0.12)
    field_strokecolor = :steelblue
    field_strokewidth = 0.8f0
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
    tree = KDTree(pts)

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
            W = 0.0
            acc = 0.0
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
    field_color = (:steelblue, 0.12)
    field_strokecolor = :steelblue
    field_strokewidth = 0.8f0
    draw_boundary = true
    draw_fields = true
end

function Makie.plot!(p::WaferContour)
    data = p[:data][]
    grid_n = p[:grid_n][]
    r = data.wafer.diameter_mm / 2.0

    # interpolate to regular grid
    xs = LinRange(-r, r, grid_n)
    ys = LinRange(-r, r, grid_n)
    pts = permutedims(hcat(data.x, data.y))
    tree = KDTree(pts)
    r_active2 = (r - data.wafer.edge_exclusion_mm)^2

    k = 4
    idxs = Vector{Int}(undef, k)
    dists = Vector{Float64}(undef, k)
    q = Vector{Float64}(undef, 2)

    vals_src = data.values
    Z = Matrix{Float32}(undef, grid_n, grid_n)
    for (j, y) in enumerate(ys), (i, x) in enumerate(xs)
        if x^2 + y^2 <= r_active2
            q[1] = x
            q[2] = y
            knn!(idxs, dists, tree, q, k, true)
            @inbounds if dists[1] < 1.0e-10
                Z[i, j] = Float32(vals_src[idxs[1]])
            else
                W = 0.0
                acc = 0.0
                for n in 1:k
                    wgt = inv(dists[n] * dists[n])
                    W += wgt
                    acc += wgt * Float64(vals_src[idxs[n]])
                end
                Z[i, j] = Float32(acc / W)
            end
        else
            Z[i, j] = NaN32
        end
    end

    contour!(p, p.attributes, xs, ys, Z)

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
