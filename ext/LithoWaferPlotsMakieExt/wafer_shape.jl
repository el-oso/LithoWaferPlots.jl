"""
Draw the wafer boundary (circle + rounded notch) and optional field overlays.
"""

function draw_wafer_boundary!(ax, spec::WaferSpec; color = :black, linewidth = 1.5)
    pts = wafer_polygon(spec)
    xs = [p[1] for p in pts]
    ys = [p[2] for p in pts]
    lines!(ax, xs, ys; color, linewidth)
    return nothing
end

function draw_fields!(
        ax, fields::AbstractVector{WaferField};
        color = (:steelblue, 0.15), strokecolor = :steelblue, strokewidth = 0.8
    )
    isempty(fields) && return nothing
    for f in fields
        xmin, xmax, ymin, ymax = field_bounds(f)
        poly!(
            ax,
            Point2f[(xmin, ymin), (xmax, ymin), (xmax, ymax), (xmin, ymax)];
            color, strokecolor, strokewidth
        )
    end
    return nothing
end

function _draw_ring!(
        ax, radius_mm::Real;
        label = "", color = :red, linewidth = 1.0f0, linestyle = :dash, n::Int = 256
    )
    θ = LinRange(0.0, 2π, n + 1)
    xs = radius_mm .* cos.(θ)
    ys = radius_mm .* sin.(θ)
    kw = isempty(label) ? (;) : (; label)
    lines!(ax, xs, ys; color, linewidth, linestyle, kw...)
    return nothing
end

function _draw_dim_annulus!(
        ax, r_inner::Real, r_outer::Real;
        color = :black, alpha::Real = 0.35, n::Int = 256
    )
    # GeometryBasics.Polygon with one hole: outer ring CCW, inner ring CW
    outer = [
        Point2f(r_outer * cos(t), r_outer * sin(t))
            for t in LinRange(0.0, 2π, n + 1)[1:(end - 1)]
    ]
    inner = [
        Point2f(r_inner * cos(t), r_inner * sin(t))
            for t in LinRange(2π, 0.0, n + 1)[1:(end - 1)]
    ]
    annulus = Makie.GeometryBasics.Polygon(outer, [inner])
    poly!(ax, annulus; color = (color, Float32(alpha)), strokewidth = 0)
    return nothing
end
