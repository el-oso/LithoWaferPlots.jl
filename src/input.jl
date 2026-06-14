"""
Input constructors for `WaferData` and `WaferVectorData`.

Accepts any Tables.jl-compatible source (Arrays, DataFrames, NamedTuples, CSV rows, etc.).
Two coordinate modes are supported — the caller chooses explicitly:

  - **mm mode**: pass `(table, wafer)` with columns `:x`, `:y`, `:value` / `:vx`, `:vy`
  - **die-index mode**: pass `(table, grid, wafer)` with columns `:col`, `:row`, `:value` / `:vx`, `:vy`
"""

function _extract_cols(table, names::Symbol...)
    cols = Tables.columns(table)
    return map(n -> Float64.(Tables.getcolumn(cols, n)), names)
end

function _die_to_mm(col::AbstractVector, row::AbstractVector, grid::DieGrid)
    x = grid.origin_x_mm .+ (col .- 1) .* grid.die_width_mm
    y = grid.origin_y_mm .+ (row .- 1) .* grid.die_height_mm
    return x, y
end

# --- WaferData constructors ---

"""
    WaferData(table, wafer::WaferSpec; fields=[])

Construct from mm-coordinate data. `table` must have columns `:x`, `:y`, `:value`.
"""
function WaferData(table, wafer::WaferSpec; fields::Vector{WaferField} = WaferField[])
    cols = Tables.columns(table)
    x = Float64.(Tables.getcolumn(cols, :x))
    y = Float64.(Tables.getcolumn(cols, :y))
    v = Tables.getcolumn(cols, :value)
    return WaferData(x, y, collect(v), wafer, fields)
end

"""
    WaferData(table, grid::DieGrid, wafer::WaferSpec; fields=[])

Construct from die-index data. `table` must have columns `:col`, `:row`, `:value`.
Die indices are converted to mm using `grid`.
"""
function WaferData(table, grid::DieGrid, wafer::WaferSpec; fields::Vector{WaferField} = WaferField[])
    cols = Tables.columns(table)
    col = Tables.getcolumn(cols, :col)
    row = Tables.getcolumn(cols, :row)
    v = Tables.getcolumn(cols, :value)
    x, y = _die_to_mm(col, row, grid)
    return WaferData(x, y, collect(v), wafer, fields)
end

# --- WaferVectorData constructors ---

"""
    WaferVectorData(table, wafer::WaferSpec; fields=[])

Construct from mm-coordinate vector data. `table` must have columns `:x`, `:y`, `:vx`, `:vy`.
"""
function WaferVectorData(table, wafer::WaferSpec; fields::Vector{WaferField} = WaferField[])
    cols = Tables.columns(table)
    x = Float64.(Tables.getcolumn(cols, :x))
    y = Float64.(Tables.getcolumn(cols, :y))
    vx = Float64.(Tables.getcolumn(cols, :vx))
    vy = Float64.(Tables.getcolumn(cols, :vy))
    return WaferVectorData(x, y, vx, vy, wafer, fields)
end

"""
    WaferVectorData(table, grid::DieGrid, wafer::WaferSpec; fields=[])

Construct from die-index vector data. `table` must have columns `:col`, `:row`, `:vx`, `:vy`.
"""
function WaferVectorData(table, grid::DieGrid, wafer::WaferSpec; fields::Vector{WaferField} = WaferField[])
    cols = Tables.columns(table)
    col = Tables.getcolumn(cols, :col)
    row = Tables.getcolumn(cols, :row)
    vx = Float64.(Tables.getcolumn(cols, :vx))
    vy = Float64.(Tables.getcolumn(cols, :vy))
    x, y = _die_to_mm(col, row, grid)
    return WaferVectorData(x, y, vx, vy, wafer, fields)
end
