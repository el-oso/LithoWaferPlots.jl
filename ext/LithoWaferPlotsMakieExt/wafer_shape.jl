"""
Draw the wafer boundary (circle + V-notch) and optional field overlays.
"""

function draw_wafer_boundary!(ax, spec::WaferSpec; color=:black, linewidth=1.5)
    pts = wafer_polygon(spec)
    xs = [p[1] for p in pts]
    ys = [p[2] for p in pts]
    lines!(ax, xs, ys; color, linewidth)
    return nothing
end

function draw_fields!(ax, fields::AbstractVector{WaferField};
                      color=(:steelblue, 0.15), strokecolor=:steelblue, strokewidth=0.8)
    isempty(fields) && return nothing
    for f in fields
        xmin, xmax, ymin, ymax = field_bounds(f)
        poly!(ax,
            Point2f[(xmin, ymin), (xmax, ymin), (xmax, ymax), (xmin, ymax)];
            color, strokecolor, strokewidth)
    end
    return nothing
end
