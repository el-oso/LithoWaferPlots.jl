"""
    WaferSpec(diameter_mm, notch_angle_deg, notch_depth_mm, edge_exclusion_mm;
              notch_width_mm=0.9*notch_depth_mm, notch_shape=:rounded_u)

Physical parameters of a semiconductor wafer.

Coordinate system follows SEMI M20: origin at wafer centre, units in mm, +x right, +y up.
Notch position convention: 270° = bottom (6 o'clock), per Artwork Systems glossary.

`notch_shape` selects the notch profile drawn by [`wafer_polygon`](@ref):
- `:rounded_u` (default) — two radial walls joined by a semicircular bottom of radius
  `notch_width_mm/2`. Requires `notch_width_mm <= notch_depth_mm` (a wider-than-deep rounded
  U would bulge outside the wafer rim) — use `:flat` or `:v` for a shallow, wide notch.
- `:flat` — two radial walls joined by a straight chord.
- `:v` — two straight walls meeting at a point (no rounding); no width/depth coupling.

`notch_width_mm` is the full mouth width on the rim (not the half-width).
"""
struct WaferSpec
    diameter_mm::Float64
    notch_angle_deg::Float64
    notch_depth_mm::Float64
    edge_exclusion_mm::Float64
    notch_width_mm::Float64
    notch_shape::Symbol

    function WaferSpec(
            diameter_mm::Real, notch_angle_deg::Real, notch_depth_mm::Real, edge_exclusion_mm::Real;
            notch_width_mm::Real = 0.9 * notch_depth_mm, notch_shape::Symbol = :rounded_u
        )
        notch_shape in (:rounded_u, :flat, :v) ||
            error("WaferSpec: notch_shape must be :rounded_u, :flat, or :v, got :$notch_shape")
        if notch_shape === :rounded_u && notch_width_mm > notch_depth_mm
            error(
                "WaferSpec: :rounded_u requires notch_width_mm ($notch_width_mm) <= " *
                    "notch_depth_mm ($notch_depth_mm) — a wider-than-deep rounded U bulges " *
                    "outside the wafer rim. Use notch_shape=:flat or :v for a shallow, wide notch."
            )
        end
        return new(
            Float64(diameter_mm), Float64(notch_angle_deg), Float64(notch_depth_mm),
            Float64(edge_exclusion_mm), Float64(notch_width_mm), notch_shape
        )
    end
end

# notch_depth_mm defaults to 3.0: the outline is schematic, and a physical ~1 mm notch
# is sub-pixel at plot scale. 3 mm renders as a clean, visible rounded U.
WaferSpec(diameter_mm::Real; kwargs...) = WaferSpec(Float64(diameter_mm), 270.0, 3.0, 2.0; kwargs...)
WaferSpec(diameter_mm::Real, notch_angle_deg::Real; kwargs...) =
    WaferSpec(Float64(diameter_mm), Float64(notch_angle_deg), 3.0, 2.0; kwargs...)

# 300 mm is the standard wafer size across the package's defaults (WaferData/WaferVectorData
# input constructors, precompile workloads, docs) — WaferSpec() with no diameter matches it.
WaferSpec(; kwargs...) = WaferSpec(300.0; kwargs...)

"""
    DieGrid(origin_x_mm, origin_y_mm, die_width_mm, die_height_mm)

Uniform die grid layout for converting (col, row) indices to mm coordinates.

Die (1, 1) centre is at (origin_x_mm, origin_y_mm) relative to wafer centre.
Column index increases in +x direction, row index increases in +y direction,
consistent with SEMI M21 Cartesian addressing.
"""
struct DieGrid
    origin_x_mm::Float64
    origin_y_mm::Float64
    die_width_mm::Float64
    die_height_mm::Float64
end

"""
    WaferField(x_center_mm, y_center_mm, width_mm, height_mm, col_idx, row_idx)

Rectangular exposure field on the wafer. `col_idx` and `row_idx` follow SEMI M21
Cartesian grid addressing relative to the wafer centre.
"""
struct WaferField
    x_center_mm::Float64
    y_center_mm::Float64
    width_mm::Float64
    height_mm::Float64
    col_idx::Int
    row_idx::Int
end

"""
    WaferDie(field, col_idx, row_idx)

A single die within a `WaferField`. Indices are 1-based within the field.
"""
struct WaferDie
    field::WaferField
    col_idx::Int
    row_idx::Int
end

"""
    WaferData{T}(x, y, values, wafer, fields)

Scalar measurements at spatial positions on a wafer. Coordinates are in mm from
wafer centre (SEMI M20 convention). `fields` may be empty.

Construct via `WaferData(table, wafer)` (mm coords) or
`WaferData(table, grid, wafer)` (die indices).
"""
struct WaferData{T <: Real}
    x::Vector{Float64}
    y::Vector{Float64}
    values::Vector{T}
    wafer::WaferSpec
    fields::Vector{WaferField}

    function WaferData{T}(
            x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, values::AbstractVector{<:Real},
            wafer::WaferSpec, fields::Vector{WaferField}
        ) where {T <: Real}
        x, y, values = Vector{Float64}(x), Vector{Float64}(y), Vector{T}(values)
        valid = isfinite.(x) .& isfinite.(y) .& isfinite.(values)
        if !all(valid)
            @warn "WaferData: dropping $(count(!, valid)) point(s) with non-finite x/y/value" maxlog = 1
            x, y, values = x[valid], y[valid], values[valid]
        end
        return new{T}(x, y, values, wafer, fields)
    end
end
WaferData(
    x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, values::AbstractVector{T},
    wafer::WaferSpec, fields::Vector{WaferField}
) where {T <: Real} = WaferData{T}(x, y, values, wafer, fields)

"""
    WaferVectorData(x, y, vx, vy, wafer, fields)

Vector-field measurements at spatial positions on a wafer. `vx`/`vy` are the
x- and y-components of the vector at each (x, y) point.

Construct via `WaferVectorData(table, wafer)` or `WaferVectorData(table, grid, wafer)`.
"""
struct WaferVectorData
    x::Vector{Float64}
    y::Vector{Float64}
    vx::Vector{Float64}
    vy::Vector{Float64}
    wafer::WaferSpec
    fields::Vector{WaferField}

    function WaferVectorData(
            x::AbstractVector{<:Real}, y::AbstractVector{<:Real},
            vx::AbstractVector{<:Real}, vy::AbstractVector{<:Real},
            wafer::WaferSpec, fields::Vector{WaferField}
        )
        x, y, vx, vy = Vector{Float64}(x), Vector{Float64}(y), Vector{Float64}(vx), Vector{Float64}(vy)
        valid = isfinite.(x) .& isfinite.(y) .& isfinite.(vx) .& isfinite.(vy)
        if !all(valid)
            @warn "WaferVectorData: dropping $(count(!, valid)) point(s) with non-finite x/y/vx/vy" maxlog = 1
            x, y, vx, vy = x[valid], y[valid], vx[valid], vy[valid]
        end
        return new(x, y, vx, vy, wafer, fields)
    end
end
