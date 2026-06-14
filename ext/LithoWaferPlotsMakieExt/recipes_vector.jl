"""
Makie recipes for vector wafer plots: WaferArrows, WaferStreamlines,
WaferDivergence, WaferVorticity.
"""

# ── WaferArrows ─────────────────────────────────────────────────────────────

@recipe(WaferArrows, data) do scene
    Attributes(
        arrowcolor         = :black,
        arrowsize          = 10f0,
        lengthscale        = 1.0,
        max_arrows         = 20_000,   # subsample above this for readability
        boundary_color     = :black,
        boundary_linewidth = 1.5f0,
        field_color        = (:steelblue, 0.12),
        field_strokecolor  = :steelblue,
        field_strokewidth  = 0.8f0,
    )
end

function Makie.plot!(p::WaferArrows)
    d = p[:data][]
    n = length(d.x)
    max_n = p[:max_arrows][]

    if n > max_n
        # uniform random subsample
        idx = sort(randperm(n)[1:max_n])
        x, y, vx, vy = d.x[idx], d.y[idx], d.vx[idx], d.vy[idx]
    else
        x, y, vx, vy = d.x, d.y, d.vx, d.vy
    end

    scale = Float64(p[:lengthscale][])
    arrows!(p, x, y, vx .* scale, vy .* scale;
        color     = p[:arrowcolor],
        arrowsize = p[:arrowsize])

    draw_wafer_boundary!(p, d.wafer;
        color     = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][])

    draw_fields!(p, d.fields;
        color        = p[:field_color][],
        strokecolor  = p[:field_strokecolor][],
        strokewidth  = p[:field_strokewidth][])

    return p
end

# ── WaferStreamlines ────────────────────────────────────────────────────────

@recipe(WaferStreamlines, data) do scene
    Attributes(
        color              = :navy,
        linewidth          = 1.2f0,
        n_seeds            = 20,
        max_steps          = 300,
        step_size          = nothing,
        boundary_color     = :black,
        boundary_linewidth = 1.5f0,
        field_color        = (:steelblue, 0.12),
        field_strokecolor  = :steelblue,
        field_strokewidth  = 0.8f0,
    )
end

function Makie.plot!(p::WaferStreamlines)
    d = p[:data][]
    segs = trace_streamlines(d;
        n_seeds   = p[:n_seeds][],
        max_steps = p[:max_steps][],
        step_size = p[:step_size][])

    # render all segments as a single lines! call with NaN separators
    if !isempty(segs)
        pts = Point2f[]
        for seg in segs
            append!(pts, seg)
            push!(pts, Point2f(NaN, NaN))
        end
        lines!(p, pts; color=p[:color], linewidth=p[:linewidth])
    end

    draw_wafer_boundary!(p, d.wafer;
        color     = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][])

    draw_fields!(p, d.fields;
        color        = p[:field_color][],
        strokecolor  = p[:field_strokecolor][],
        strokewidth  = p[:field_strokewidth][])

    return p
end

# ── WaferDivergence ─────────────────────────────────────────────────────────

@recipe(WaferDivergence, data) do scene
    Attributes(
        colormap           = :RdBu,
        markersize         = 4f0,
        grid_n             = 256,
        boundary_color     = :black,
        boundary_linewidth = 1.5f0,
        field_color        = (:steelblue, 0.12),
        field_strokecolor  = :steelblue,
        field_strokewidth  = 0.8f0,
    )
end

function Makie.plot!(p::WaferDivergence)
    d    = p[:data][]
    wdat = divergence(d; grid_n=p[:grid_n][])
    cs   = ColorScale(wdat.values)
    cols = normalize(cs, wdat.values)

    scatter!(p, wdat.x, wdat.y;
        color      = cols,
        colormap   = p[:colormap],
        colorrange = (0f0, 1f0),
        markersize = p[:markersize],
        marker     = :rect)

    draw_wafer_boundary!(p, d.wafer;
        color     = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][])

    draw_fields!(p, d.fields;
        color        = p[:field_color][],
        strokecolor  = p[:field_strokecolor][],
        strokewidth  = p[:field_strokewidth][])

    return p
end

# ── WaferVorticity ──────────────────────────────────────────────────────────

@recipe(WaferVorticity, data) do scene
    Attributes(
        colormap           = :RdBu_r,
        markersize         = 4f0,
        grid_n             = 256,
        boundary_color     = :black,
        boundary_linewidth = 1.5f0,
        field_color        = (:steelblue, 0.12),
        field_strokecolor  = :steelblue,
        field_strokewidth  = 0.8f0,
    )
end

function Makie.plot!(p::WaferVorticity)
    d    = p[:data][]
    wdat = vorticity(d; grid_n=p[:grid_n][])
    cs   = ColorScale(wdat.values)
    cols = normalize(cs, wdat.values)

    scatter!(p, wdat.x, wdat.y;
        color      = cols,
        colormap   = p[:colormap],
        colorrange = (0f0, 1f0),
        markersize = p[:markersize],
        marker     = :rect)

    draw_wafer_boundary!(p, d.wafer;
        color     = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][])

    draw_fields!(p, d.fields;
        color        = p[:field_color][],
        strokecolor  = p[:field_strokecolor][],
        strokewidth  = p[:field_strokewidth][])

    return p
end
