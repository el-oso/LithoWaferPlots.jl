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
        color = (:steelblue, 0.15), strokecolor = :steelblue, strokewidth = 0.8,
        show_numbers::Bool = false
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
    show_numbers && draw_field_numbers!(ax, fields)
    return nothing
end

# label placement within a field rectangle: position symbol → (x-fraction, y-fraction, align)
const _FIELD_LABEL_ANCHORS = Dict(
    :c => (0.5, 0.5, (:center, :center)),
    :tl => (0.0, 1.0, (:left, :top)),
    :bl => (0.0, 0.0, (:left, :bottom)),
    :tr => (1.0, 1.0, (:right, :top)),
    :br => (1.0, 0.0, (:right, :bottom)),
)

"""
    draw_field_numbers!(ax, fields; numbers=nothing, start=:bottomleft, first_row=:lr,
                        position=:c, fontsize=9, color=:black, alpha=1.0)

Label each exposure field with its shot number. When `numbers` is `nothing` the serpentine
(boustrophedon) scan order is used (`serpentine_numbers`); otherwise pass an explicit vector
aligned with `fields`.

Font/placement options:
- `position`: where the number sits within each field — `:c` (centre, default), `:tl`, `:bl`,
  `:tr`, `:br` (corners, inset slightly from the edge).
- `fontsize`: label size (default `9`).
- `color`: label colour (default `:black`).
- `alpha`: label opacity in `0..1` (default `1.0`).

Requires a Makie backend.
"""
function draw_field_numbers!(
        ax, fields::AbstractVector{WaferField};
        numbers::Union{Nothing, AbstractVector{<:Integer}} = nothing,
        start::Symbol = :bottomleft, first_row::Symbol = :lr,
        position::Symbol = :c, fontsize = 9.0f0, color = :black, alpha::Real = 1.0
    )
    isempty(fields) && return nothing
    haskey(_FIELD_LABEL_ANCHORS, position) ||
        error("position must be one of :c, :tl, :bl, :tr, :br, got :$position")
    nums = numbers === nothing ? serpentine_numbers(fields; start, first_row) : numbers
    length(nums) == length(fields) ||
        error("numbers must align with fields ($(length(nums)) vs $(length(fields)))")

    xf, yf, align = _FIELD_LABEL_ANCHORS[position]
    pad = 0.06   # inset corner labels so they don't touch the field border
    ix = xf == 0.0 ? pad : xf == 1.0 ? 1.0 - pad : 0.5
    iy = yf == 0.0 ? pad : yf == 1.0 ? 1.0 - pad : 0.5
    for (f, num) in zip(fields, nums)
        xmin, xmax, ymin, ymax = field_bounds(f)
        px = xmin + ix * (xmax - xmin)
        py = ymin + iy * (ymax - ymin)
        text!(ax, px, py; text = string(num), align, fontsize, color = (color, Float32(alpha)))
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
