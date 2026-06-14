"""
    wafer_polygon(spec::WaferSpec; n::Int=256) -> Vector{Tuple{Float64,Float64}}

Return a closed polygon approximating the wafer boundary with a V-notch.

The circle is sampled at `n` points. Three extra vertices replace the arc segment
nearest `notch_angle_deg` to form a V-notch indented by `notch_depth_mm`.

Reference: notch geometry derived from cap1tan/wafermap (MIT) and
Artwork Systems wafer map glossary (https://www.artwork.com/package/wmapconvert/).
"""
function wafer_polygon(spec::WaferSpec; n::Int = 256)
    r = spec.diameter_mm / 2.0
    notch_r = r - spec.notch_depth_mm
    θ_notch = deg2rad(spec.notch_angle_deg)

    # half-angle subtended by the notch opening on the circle (≈2° each side)
    δ = deg2rad(2.0)
    θ_left = θ_notch - δ
    θ_right = θ_notch + δ

    pts = Tuple{Float64, Float64}[]
    sizehint!(pts, n + 3)

    step = 2π / n
    θ = θ_right  # start just after right notch edge, go counter-clockwise
    while θ < θ_right + 2π - step / 2
        θn = θ + step
        # insert notch when we reach the left edge
        if θ <= θ_left + 2π < θn
            push!(pts, (r * cos(θ_left + 2π), r * sin(θ_left + 2π)))
            push!(pts, (notch_r * cos(θ_notch), notch_r * sin(θ_notch)))
            push!(pts, (r * cos(θ_right + 2π), r * sin(θ_right + 2π)))
        end
        push!(pts, (r * cos(θn), r * sin(θn)))
        θ = θn
    end

    # close polygon
    push!(pts, pts[1])
    return pts
end

"""
    inside_wafer(x, y, spec::WaferSpec) -> BitVector

Return a mask that is `true` for points within the active wafer area
(radius minus edge exclusion).
"""
function inside_wafer(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, spec::WaferSpec)
    r_active = spec.diameter_mm / 2.0 - spec.edge_exclusion_mm
    r2 = r_active^2
    return BitVector(xi^2 + yi^2 <= r2 for (xi, yi) in zip(x, y))
end

"""
    field_bounds(f::WaferField) -> (x_min, x_max, y_min, y_max)

Return the axis-aligned bounding box of a `WaferField` in mm.
"""
function field_bounds(f::WaferField)
    hw = f.width_mm / 2.0
    hh = f.height_mm / 2.0
    return (
        f.x_center_mm - hw, f.x_center_mm + hw,
        f.y_center_mm - hh, f.y_center_mm + hh,
    )
end

"""
    die_bounds(d::WaferDie) -> (x_min, x_max, y_min, y_max)

Return the axis-aligned bounding box of a `WaferDie` in mm.
"""
function die_bounds(d::WaferDie)
    f = d.field
    dw = f.width_mm  # die == field when no subdivision info available
    dh = f.height_mm
    x0 = f.x_center_mm - f.width_mm / 2.0 + (d.col_idx - 1) * dw
    y0 = f.y_center_mm - f.height_mm / 2.0 + (d.row_idx - 1) * dh
    return (x0, x0 + dw, y0, y0 + dh)
end
