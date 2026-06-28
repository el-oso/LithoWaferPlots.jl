"""
    WaferSpec(diameter_mm, notch_angle_deg, notch_depth_mm, edge_exclusion_mm)

Physical parameters of a semiconductor wafer.

Coordinate system follows SEMI M20: origin at wafer centre, units in mm, +x right, +y up.
Notch position convention: 270° = bottom (6 o'clock), per Artwork Systems glossary.
"""
struct WaferSpec
    diameter_mm::Float64
    notch_angle_deg::Float64
    notch_depth_mm::Float64
    edge_exclusion_mm::Float64
end

# notch_depth_mm defaults to 4.0: the outline is schematic, and a physical ~1 mm notch
# is sub-pixel at plot scale. 4 mm renders as a clean, visible rounded U.
WaferSpec(diameter_mm::Real) = WaferSpec(Float64(diameter_mm), 270.0, 4.0, 2.0)
WaferSpec(diameter_mm::Real, notch_angle_deg::Real) =
    WaferSpec(Float64(diameter_mm), Float64(notch_angle_deg), 4.0, 2.0)

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
end

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
end
