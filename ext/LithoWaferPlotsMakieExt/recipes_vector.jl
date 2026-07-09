"""
Makie recipes for vector wafer plots: WaferArrows, WaferStreamlines,
WaferDivergence, WaferVorticity.
"""

# ── WaferArrows ─────────────────────────────────────────────────────────────

@recipe WaferArrows (data,) begin
    Makie.documented_attributes(Lines)...
    arrowcolor = :black            # color name, or :magnitude to color by |v| via colormap
    colormap = :viridis            # used only when arrowcolor === :magnitude
    linewidth = 1.0f0
    lengthscale = 1.0
    scale = nothing                # an ArrowScale overrides lengthscale (shared scale across plots)
    max_arrows = 4_000
    arrow_sample = :magnitude      # :magnitude (largest |v| kept) or :random (uniform subsample)
    head_frac = 0.3
    head_angle = 0.45
    boundary_color = :black
    boundary_linewidth = 1.5f0
    field_color = (:steelblue, 0.12)
    field_strokecolor = :steelblue
    field_strokewidth = 0.8f0
    draw_boundary = true
    draw_fields = true
end

# Build a single NaN-separated polyline encoding every arrow as a shaft plus a
# two-segment V arrowhead. Rendering all arrows in one `lines!` call keeps the GPU
# allocation tiny compared with `arrows2d!`, which tessellates a mesh per arrow.
function _arrow_segments(x, y, vx, vy, scale::Float64, head_frac::Float64, head_angle::Float64)
    pts = Point2f[]
    mags = Float32[]                  # parallel to pts: true |v| at each vertex (for color-by-magnitude)
    sizehint!(pts, length(x) * 9)
    sizehint!(mags, length(x) * 9)
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
        m = Float32(hypot(Float64(vx[i]), Float64(vy[i])))
        base = Point2f(bx, by)
        tip = Point2f(tx, ty)
        push!(pts, base, tip, nan)               # shaft
        push!(mags, m, m, m)
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
        push!(mags, m, m, m, m, m, m)
    end
    return pts, mags
end

_resolved_lengthscale(p::WaferArrows) = (sc = p[:scale][]; sc isa ArrowScale ? sc.lengthscale : Float64(p[:lengthscale][]))

function Makie.plot!(p::WaferArrows)
    d = p[:data][]
    n = length(d.x)
    max_n = p[:max_arrows][]

    if n > max_n
        sample = p[:arrow_sample][]
        idx = if sample === :magnitude
            mag = @. hypot(d.vx, d.vy)
            partialsortperm(mag, 1:max_n; rev = true)
        elseif sample === :random
            randperm(n)[1:max_n]   # order irrelevant for arrows — no sort needed
        else
            error("arrow_sample must be :magnitude or :random, got $(repr(sample))")
        end
        x, y, vx, vy = d.x[idx], d.y[idx], d.vx[idx], d.vy[idx]
    else
        x, y, vx, vy = d.x, d.y, d.vx, d.vy
    end

    scale = _resolved_lengthscale(p)
    head_frac = Float64(p[:head_frac][])
    head_angle = Float64(p[:head_angle][])
    pts, mags = _arrow_segments(x, y, vx, vy, scale, head_frac, head_angle)
    if !isempty(pts)
        if p[:arrowcolor][] === :magnitude
            lines!(p, p.attributes, pts; color = mags)
        else
            lines!(p, p.attributes, pts; color = p[:arrowcolor])
        end
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

"""
    add_scale_arrow!(ax, arrows_plot::WaferArrows; ref_magnitude=nothing, label=nothing, position=:rb, kwargs...)

Draw a reference arrow matched to `arrows_plot`'s *actually resolved* scale — the single
source of truth is the plot object Makie already handed back from `waferarrows!`, so this
stays consistent with the drawn arrows even when `waferarrows!` was called with a raw
`lengthscale=` (no `ArrowScale`). When `ref_magnitude` is omitted it is auto-picked as the
nice-rounded median `|v|` of the plotted data (same rule as `arrow_scale_from`).
"""
function add_scale_arrow!(
        ax, arrows_plot::WaferArrows;
        ref_magnitude = nothing, label = nothing, position = :rb, kwargs...
    )
    sc = arrows_plot[:scale][]
    sc isa ArrowScale && return add_scale_arrow!(ax, sc; position, kwargs...)

    ls = _resolved_lengthscale(arrows_plot)
    d = arrows_plot[:data][]
    refmag = ref_magnitude === nothing ? _nice_magnitude(median(hypot.(d.vx, d.vy))) : Float64(ref_magnitude)
    refmag > 0 ||
        error("add_scale_arrow!: could not auto-pick a reference magnitude (vector field is all-zero); pass ref_magnitude explicitly")
    lbl = label === nothing ? string(refmag) : String(label)
    return add_scale_arrow!(ax, refmag * ls; label = lbl, position, kwargs...)
end

# ── WaferStreamlines ────────────────────────────────────────────────────────

@recipe WaferStreamlines (data,) begin
    Makie.documented_attributes(Lines)...
    color = :navy
    linewidth = 1.2f0
    n_seeds = 20
    max_steps = 300
    step_size = nothing
    grid_n = 200
    boundary_color = :black
    boundary_linewidth = 1.5f0
    field_color = (:steelblue, 0.12)
    field_strokecolor = :steelblue
    field_strokewidth = 0.8f0
    draw_boundary = true
    draw_fields = true
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
        lines!(p, p.attributes, pts)
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

# Divergence/vorticity are signed quantities meant for a diverging colormap (:RdBu and
# friends) whose neutral colour sits at the midpoint of colorrange — raw (vmin, vmax) only
# centers that midpoint on zero when the data happens to be symmetric. Force it explicitly
# so "positive = one colour, negative = the other" is actually true of the rendered plot.
_symmetric_colorrange(cs::ColorScale) = (m = Float32(max(abs(cs.vmin), abs(cs.vmax))); (-m, m))

@recipe WaferDivergence (data,) begin
    Makie.documented_attributes(Scatter)...
    colormap = :RdBu
    markersize = 4.0f0
    marker = :rect
    grid_n = 256
    k = 4
    boundary_color = :black
    boundary_linewidth = 1.5f0
    field_color = (:steelblue, 0.12)
    field_strokecolor = :steelblue
    field_strokewidth = 0.8f0
    draw_boundary = true
    draw_fields = true
end

function Makie.plot!(p::WaferDivergence)
    d = p[:data][]
    wdat = divergence(d; grid_n = p[:grid_n][], k = p[:k][])
    cs = ColorScale(wdat.values)

    scatter!(
        p, p.attributes, wdat.x, wdat.y;
        color = Float32.(wdat.values),
        colorrange = _symmetric_colorrange(cs)
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

@recipe WaferVorticity (data,) begin
    Makie.documented_attributes(Scatter)...
    colormap = Reverse(:RdBu)
    markersize = 4.0f0
    marker = :rect
    grid_n = 256
    k = 4
    boundary_color = :black
    boundary_linewidth = 1.5f0
    field_color = (:steelblue, 0.12)
    field_strokecolor = :steelblue
    field_strokewidth = 0.8f0
    draw_boundary = true
    draw_fields = true
end

function Makie.plot!(p::WaferVorticity)
    d = p[:data][]
    wdat = vorticity(d; grid_n = p[:grid_n][], k = p[:k][])
    cs = ColorScale(wdat.values)

    scatter!(
        p, p.attributes, wdat.x, wdat.y;
        color = Float32.(wdat.values),
        colorrange = _symmetric_colorrange(cs)
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
