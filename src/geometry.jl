"""
    wafer_polygon(spec::WaferSpec; n::Int=256) -> Vector{Tuple{Float64,Float64}}

Return a closed polygon approximating the wafer boundary with a notch cut at
`spec.notch_angle_deg`, in the profile selected by `spec.notch_shape` (see [`WaferSpec`](@ref)).

Reference: notch geometry derived from cap1tan/wafermap (MIT) and
Artwork Systems wafer map glossary (https://www.artwork.com/package/wmapconvert/).
"""
function wafer_polygon(spec::WaferSpec; n::Int = 256)
    r = spec.diameter_mm / 2.0
    d = spec.notch_depth_mm
    w = spec.notch_width_mm / 2.0   # half-width, as used throughout the geometry below
    θ0 = deg2rad(spec.notch_angle_deg)

    # Degenerate notch → plain circle.
    if d <= 0 || w <= 0 || w >= r || (r - d) <= 0
        return [(r * cos(θ), r * sin(θ)) for θ in range(0, 2π; length = n + 1)]
    end

    α = asin(w / r)                       # rim half-angle to each corner
    u = (cos(θ0), sin(θ0))                # outward radial at the notch
    t = (-sin(θ0), cos(θ0))               # rim tangent

    pts = Tuple{Float64, Float64}[]
    sizehint!(pts, n + 24)

    # 1) rim: corner₊ (θ0+α) counter-clockwise the long way to corner₋ (θ0-α+2π)
    for k in 0:n
        θ = (θ0 + α) + (2π - 2α) * (k / n)
        push!(pts, (r * cos(θ), r * sin(θ)))
    end

    # The rim loop above already ended exactly at corner₋, so the notch interior below
    # starts from there implicitly — its first pushed point becomes the wall to corner₋.
    corner₊ = (r * cos(θ0 + α), r * sin(θ0 + α))

    if spec.notch_shape === :v
        # notch interior: corner₋ → straight wall → apex → straight wall → corner₊.
        apex = ((r - d) * u[1], (r - d) * u[2])
        push!(pts, apex)
    elseif spec.notch_shape === :flat
        # notch interior: corner₋ → radial wall → chord → radial wall → corner₊.
        wall₋ = (r * cos(α) - d) * u[1] - w * t[1], (r * cos(α) - d) * u[2] - w * t[2]
        wall₊ = (r * cos(α) - d) * u[1] + w * t[1], (r * cos(α) - d) * u[2] + w * t[2]
        append!(pts, (wall₋, wall₊))
    else # :rounded_u — two radial walls joined by a semicircular bottom of radius w
        L = d - w                         # straight wall length (w <= d, enforced at construction)
        md = r * cos(α) - L               # radial distance of the bottom-arc centre
        Mx, My = md * u[1], md * u[2]
        # β sweeps -π/2 (B₋, matching corner₋'s tangential offset) → 0 (apex) → +π/2 (B₊).
        nb = 14
        for k in 0:nb
            β = -π / 2 + π * (k / nb)
            push!(
                pts, (
                    Mx + w * (sin(β) * t[1] - cos(β) * u[1]),
                    My + w * (sin(β) * t[2] - cos(β) * u[2]),
                )
            )
        end
    end

    push!(pts, pts[1])   # close (last notch point → corner₊ wall)
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
