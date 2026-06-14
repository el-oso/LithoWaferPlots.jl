"""
Makie recipes for scalar wafer plots: WaferScatter, WaferHeatmap, WaferContour.

All recipes automatically overlay the wafer boundary and optional field patches.
Performance target: 300 000 points rendered in < 0.3s (GLMakie GPU path).
"""

# ── WaferScatter ────────────────────────────────────────────────────────────

@recipe(WaferScatter, data) do scene
    Attributes(
        colormap = :viridis,
        markersize = 3.0f0,
        boundary_color = :black,
        boundary_linewidth = 1.5f0,
        field_color = (:steelblue, 0.15),
        field_strokecolor = :steelblue,
        field_strokewidth = 0.8f0,
    )
end

function Makie.plot!(p::WaferScatter)
    data = p[:data][]
    mask = inside_wafer(data.x, data.y, data.wafer)
    x, y, vals = data.x[mask], data.y[mask], data.values[mask]
    cs = ColorScale(vals)

    scatter!(
        p, x, y;
        color = vals,
        colormap = p[:colormap],
        colorrange = (Float32(cs.vmin), Float32(cs.vmax)),
        markersize = p[:markersize]
    )

    draw_wafer_boundary!(
        p, data.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    draw_fields!(
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

@recipe(WaferHeatmap, data) do scene
    Attributes(
        colormap = :inferno,
        markersize = 4.0f0,
        boundary_color = :black,
        boundary_linewidth = 1.5f0,
        field_color = (:steelblue, 0.12),
        field_strokecolor = :steelblue,
        field_strokewidth = 0.8f0,
        percentile_clip = 0.0,
        imagemode = :auto,
        grid_n = 256,
    )
end

function Makie.plot!(p::WaferHeatmap)
    data = p[:data][]
    mask = inside_wafer(data.x, data.y, data.wafer)
    x, y, vals = data.x[mask], data.y[mask], data.values[mask]
    cs = ColorScale(vals; percentile_clip = p[:percentile_clip][])
    mode = p[:imagemode][]
    use_image = mode === :image || (mode === :auto && length(x) >= IMAGE_THRESHOLD)

    if use_image
        _heatmap_image!(p, data, x, y, vals, cs)
    else
        scatter!(
            p, x, y;
            color = vals,
            colormap = p[:colormap],
            colorrange = (Float32(cs.vmin), Float32(cs.vmax)),
            markersize = p[:markersize],
            marker = :rect
        )
    end

    draw_wafer_boundary!(
        p, data.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    draw_fields!(
        p, data.fields;
        color = p[:field_color][],
        strokecolor = p[:field_strokecolor][],
        strokewidth = p[:field_strokewidth][]
    )

    return p
end

function _heatmap_image!(p, data, x, y, vals, cs)
    grid_n = p[:grid_n][]
    r = data.wafer.diameter_mm / 2.0
    r_active2 = (r - data.wafer.edge_exclusion_mm)^2
    xs = LinRange(-r, r, grid_n)
    ys = LinRange(-r, r, grid_n)

    cmap = Makie.to_colormap(p[:colormap][])
    pts = permutedims(hcat(Float64.(data.x), Float64.(data.y)))
    tree = KDTree(pts)

    img = fill(RGBAf(0.0f0, 0.0f0, 0.0f0, 0.0f0), grid_n, grid_n)
    for (j, yg) in enumerate(ys), (i, xg) in enumerate(xs)
        xg^2 + yg^2 > r_active2 && continue
        idxs, dists = knn(tree, Float64[xg, yg], 4, true)
        v = if dists[1] < 1.0e-10
            Float64(vals[idxs[1]])
        else
            w = dists .^ -2.0
            sum(w .* Float64.(vals[idxs])) / sum(w)
        end
        cn = clamp(Float32((v - cs.vmin) / (cs.vmax - cs.vmin)), 0.0f0, 1.0f0)
        img[i, j] = Makie.interpolated_getindex(cmap, cn)
    end

    # Makie 0.22+ requires interval notation (start..stop) for image! axes.
    image!(p, (-r) .. r, (-r) .. r, img)
    return nothing
end

# ── WaferContour ────────────────────────────────────────────────────────────
# Interpolates scattered data to a regular grid, then calls contour!.

@recipe(WaferContour, data) do scene
    Attributes(
        colormap = :viridis,
        levels = 10,
        grid_n = 256,
        boundary_color = :black,
        boundary_linewidth = 1.5f0,
        field_color = (:steelblue, 0.12),
        field_strokecolor = :steelblue,
        field_strokewidth = 0.8f0,
    )
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

    Z = Matrix{Float32}(undef, grid_n, grid_n)
    for (j, y) in enumerate(ys), (i, x) in enumerate(xs)
        if x^2 + y^2 <= r_active2
            idxs, dists = knn(tree, Float64[x, y], 4, true)
            if dists[1] < 1.0e-10
                Z[i, j] = Float32(data.values[idxs[1]])
            else
                w = dists .^ -2.0
                W = sum(w)
                Z[i, j] = Float32(sum(w .* data.values[idxs]) / W)
            end
        else
            Z[i, j] = NaN32
        end
    end

    contour!(
        p, xs, ys, Z;
        colormap = p[:colormap],
        levels = p[:levels]
    )

    draw_wafer_boundary!(
        p, data.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    draw_fields!(
        p, data.fields;
        color = p[:field_color][],
        strokecolor = p[:field_strokecolor][],
        strokewidth = p[:field_strokewidth][]
    )

    return p
end
