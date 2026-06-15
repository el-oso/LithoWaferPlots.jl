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

"""
    field_grid(centers, field_size; wafer=nothing) -> Vector{WaferField}

Build exposure `WaferField`s of size `field_size` at the given `centers`.

- `centers`: any array of `(x, y)` centre coordinates in mm. When `centers` is a matrix
  (e.g. from a `[(x, y) for row in …, col in …]` comprehension) the array indices become
  each field's `(row_idx, col_idx)`; for a vector they are numbered in order.
- `field_size`: `(width, height)` in mm, or a single number for square fields.
- `wafer`: optional `WaferSpec`. When given, fields whose nearest point lies outside the
  wafer disk are dropped, keeping only fields that overlap the wafer.

```julia
centers = [((c - 0.5) * 26.0, (r - 5) * 33.0) for r in 1:9, c in -5:6]
fields = field_grid(centers, (26.0, 33.0); wafer = WaferSpec(300.0))
```
"""
function field_grid(centers::AbstractArray, field_size; wafer::Union{WaferSpec, Nothing} = nothing)
    fw, fh = field_size isa Union{Tuple, AbstractVector} ?
        (Float64(field_size[1]), Float64(field_size[2])) :
        (Float64(field_size), Float64(field_size))
    r2 = wafer === nothing ? Inf : (wafer.diameter_mm / 2.0)^2
    nd = ndims(centers)
    fields = WaferField[]
    for I in CartesianIndices(centers)
        cx, cy = centers[I]
        row = Tuple(I)[1]
        col = nd >= 2 ? Tuple(I)[2] : 1
        # nearest point of the field rectangle to the wafer centre
        nx = clamp(0.0, cx - fw / 2.0, cx + fw / 2.0)
        ny = clamp(0.0, cy - fh / 2.0, cy + fh / 2.0)
        if nx^2 + ny^2 <= r2
            push!(fields, WaferField(Float64(cx), Float64(cy), fw, fh, Int(col), Int(row)))
        end
    end
    return fields
end
