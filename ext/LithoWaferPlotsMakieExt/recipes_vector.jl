"""
Makie recipes for vector wafer plots: WaferArrows, WaferStreamlines,
WaferDivergence, WaferVorticity.
"""

# ── WaferArrows ─────────────────────────────────────────────────────────────

@recipe(WaferArrows, data) do scene
    Attributes(
        arrowcolor = :black,
        linewidth = 1.0f0,
        lengthscale = 1.0,
        max_arrows = 4_000,
        head_frac = 0.3,
        head_angle = 0.45,
        boundary_color = :black,
        boundary_linewidth = 1.5f0,
        field_color = (:steelblue, 0.12),
        field_strokecolor = :steelblue,
        field_strokewidth = 0.8f0,
        draw_boundary = true,
        draw_fields = true,
    )
end

# Build a single NaN-separated polyline encoding every arrow as a shaft plus a
# two-segment V arrowhead. Rendering all arrows in one `lines!` call keeps the GPU
# allocation tiny compared with `arrows2d!`, which tessellates a mesh per arrow.
function _arrow_segments(x, y, vx, vy, scale::Float64, head_frac::Float64, head_angle::Float64)
    pts = Point2f[]
    sizehint!(pts, length(x) * 9)
    ca = cos(head_angle)
    sa = sin(head_angle)
    nan = Point2f(NaN32, NaN32)
    @inbounds for i in eachindex(x)
        dx = Float64(vx[i]) * scale
        dy = Float64(vy[i]) * scale
        bx = Float64(x[i])
        by = Float64(y[i])
        tx = bx + dx
        ty = by + dy
        base = Point2f(bx, by)
        tip = Point2f(tx, ty)
        push!(pts, base, tip, nan)               # shaft
        L = hypot(dx, dy)
        L == 0.0 && continue
        ux = dx / L
        uy = dy / L
        hl = head_frac * L
        # barbs: backward direction (-u) rotated by ±head_angle
        h1x = tx + hl * (-ux * ca + uy * sa)
        h1y = ty + hl * (-ux * sa - uy * ca)
        h2x = tx + hl * (-ux * ca - uy * sa)
        h2y = ty + hl * (ux * sa - uy * ca)
        push!(pts, tip, Point2f(h1x, h1y), nan)  # barb 1
        push!(pts, tip, Point2f(h2x, h2y), nan)  # barb 2
    end
    return pts
end

function Makie.plot!(p::WaferArrows)
    d = p[:data][]
    n = length(d.x)
    max_n = p[:max_arrows][]

    if n > max_n
        idx = randperm(n)[1:max_n]   # order irrelevant for arrows — no sort needed
        x, y, vx, vy = d.x[idx], d.y[idx], d.vx[idx], d.vy[idx]
    else
        x, y, vx, vy = d.x, d.y, d.vx, d.vy
    end

    scale = Float64(p[:lengthscale][])
    pts = _arrow_segments(x, y, vx, vy, scale, Float64(p[:head_frac][]), Float64(p[:head_angle][]))
    isempty(pts) || lines!(p, pts; color = p[:arrowcolor], linewidth = p[:linewidth])

    p[:draw_boundary][] && draw_wafer_boundary!(
        p, d.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    p[:draw_fields][] && draw_fields!(
        p, d.fields;
        color = p[:field_color][],
        strokecolor = p[:field_strokecolor][],
        strokewidth = p[:field_strokewidth][]
    )

    return p
end

# ── WaferStreamlines ────────────────────────────────────────────────────────

@recipe(WaferStreamlines, data) do scene
    Attributes(
        color = :navy,
        linewidth = 1.2f0,
        n_seeds = 20,
        max_steps = 300,
        step_size = nothing,
        grid_n = 200,
        boundary_color = :black,
        boundary_linewidth = 1.5f0,
        field_color = (:steelblue, 0.12),
        field_strokecolor = :steelblue,
        field_strokewidth = 0.8f0,
        draw_boundary = true,
        draw_fields = true,
    )
end

function Makie.plot!(p::WaferStreamlines)
    d = p[:data][]
    segs = trace_streamlines(
        d;
        n_seeds = p[:n_seeds][],
        max_steps = p[:max_steps][],
        step_size = p[:step_size][],
        grid_n = p[:grid_n][]
    )

    # render all segments as a single lines! call with NaN separators
    if !isempty(segs)
        pts = Point2f[]
        for seg in segs
            append!(pts, seg)
            push!(pts, Point2f(NaN, NaN))
        end
        lines!(p, pts; color = p[:color], linewidth = p[:linewidth])
    end

    p[:draw_boundary][] && draw_wafer_boundary!(
        p, d.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    p[:draw_fields][] && draw_fields!(
        p, d.fields;
        color = p[:field_color][],
        strokecolor = p[:field_strokecolor][],
        strokewidth = p[:field_strokewidth][]
    )

    return p
end

# ── WaferDivergence ─────────────────────────────────────────────────────────

@recipe(WaferDivergence, data) do scene
    Attributes(
        colormap = :RdBu,
        markersize = 4.0f0,
        grid_n = 256,
        k = 4,
        boundary_color = :black,
        boundary_linewidth = 1.5f0,
        field_color = (:steelblue, 0.12),
        field_strokecolor = :steelblue,
        field_strokewidth = 0.8f0,
        draw_boundary = true,
        draw_fields = true,
    )
end

function Makie.plot!(p::WaferDivergence)
    d = p[:data][]
    wdat = divergence(d; grid_n = p[:grid_n][], k = p[:k][])
    cs = ColorScale(wdat.values)

    scatter!(
        p, wdat.x, wdat.y;
        color = Float32.(wdat.values),
        colormap = p[:colormap],
        colorrange = (Float32(cs.vmin), Float32(cs.vmax)),
        markersize = p[:markersize],
        marker = :rect
    )

    p[:draw_boundary][] && draw_wafer_boundary!(
        p, d.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    p[:draw_fields][] && draw_fields!(
        p, d.fields;
        color = p[:field_color][],
        strokecolor = p[:field_strokecolor][],
        strokewidth = p[:field_strokewidth][]
    )

    return p
end

# ── WaferVorticity ──────────────────────────────────────────────────────────

@recipe(WaferVorticity, data) do scene
    Attributes(
        colormap = Reverse(:RdBu),
        markersize = 4.0f0,
        grid_n = 256,
        k = 4,
        boundary_color = :black,
        boundary_linewidth = 1.5f0,
        field_color = (:steelblue, 0.12),
        field_strokecolor = :steelblue,
        field_strokewidth = 0.8f0,
        draw_boundary = true,
        draw_fields = true,
    )
end

function Makie.plot!(p::WaferVorticity)
    d = p[:data][]
    wdat = vorticity(d; grid_n = p[:grid_n][], k = p[:k][])
    cs = ColorScale(wdat.values)

    scatter!(
        p, wdat.x, wdat.y;
        color = Float32.(wdat.values),
        colormap = p[:colormap],
        colorrange = (Float32(cs.vmin), Float32(cs.vmax)),
        markersize = p[:markersize],
        marker = :rect
    )

    p[:draw_boundary][] && draw_wafer_boundary!(
        p, d.wafer;
        color = p[:boundary_color][],
        linewidth = p[:boundary_linewidth][]
    )

    p[:draw_fields][] && draw_fields!(
        p, d.fields;
        color = p[:field_color][],
        strokecolor = p[:field_strokecolor][],
        strokewidth = p[:field_strokewidth][]
    )

    return p
end
