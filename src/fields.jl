"""
Field-resolved analysis: associate each measurement with an exposure field and its
intrafield (field-local) coordinate, then filter, stack, and average over fields.

Measurements often arrive as **field center + intrafield offset**. Summing them to an
absolute position compounds error (text files store fixed decimal precision, so accuracy
degrades at large radius). We therefore preserve the intrafield coordinate and match/stack
on it with a tolerance rather than recovering it by subtraction.
"""

# ── tolerance clustering ──────────────────────────────────────────────────────
# Snap coordinates to a grid of size `tol` and group by the integer cell key. This
# aligns naturally with fixed-precision (already-quantized) input data.

function _cluster_xy(x::AbstractVector, y::AbstractVector, tol::Real)
    inv = 1.0 / tol
    groups = Dict{Tuple{Int, Int}, Vector{Int}}()
    for i in eachindex(x)
        key = (round(Int, x[i] * inv), round(Int, y[i] * inv))
        push!(get!(groups, key, Int[]), i)
    end
    return groups
end

function _cluster_1d(z::AbstractVector, tol::Real)
    inv = 1.0 / tol
    groups = Dict{Int, Vector{Int}}()
    for i in eachindex(z)
        push!(get!(groups, round(Int, z[i] * inv), Int[]), i)
    end
    return groups
end

# ── FieldedData ───────────────────────────────────────────────────────────────

"""
    FieldedData{T}

A `WaferData` enriched with a per-point exposure-field association and intrafield
coordinate. `data` is the ordinary absolute-coordinate view used for plotting;
`field_id[i]` indexes into `fields` (0 = unassigned); `(ifx[i], ify[i])` is the
field-local position of point `i`.
"""
struct FieldedData{T <: Real}
    data::WaferData{T}
    fields::Vector{WaferField}
    field_id::Vector{Int}
    ifx::Vector{Float64}
    ify::Vector{Float64}
end

"""
    fielded(table, fields; field_x=:fx, field_y=:fy, dx=:dx, dy=:dy, value=:value,
            wafer=WaferSpec(300.0), tol=1e-3) -> FieldedData

Preferred constructor: `table` carries the field centre (`field_x`, `field_y`) and the
intrafield offset (`dx`, `dy`) per measurement. The intrafield coordinate is stored
directly (no subtraction error); absolute coordinates `x = fx + dx`, `y = fy + dy` are
built for plotting. Each point's `field_id` is found by matching its centre to a field in
`fields` within `tol` mm.
"""
function fielded(
        table, fields::Vector{WaferField};
        field_x::Symbol = :fx, field_y::Symbol = :fy,
        dx::Symbol = :dx, dy::Symbol = :dy, value::Symbol = :value,
        wafer::WaferSpec = WaferSpec(300.0), tol::Real = 1.0e-3
    )
    cols = Tables.columns(table)
    fx = Float64.(Tables.getcolumn(cols, field_x))
    fy = Float64.(Tables.getcolumn(cols, field_y))
    ifx = Float64.(Tables.getcolumn(cols, dx))
    ify = Float64.(Tables.getcolumn(cols, dy))
    v = collect(Tables.getcolumn(cols, value))
    x = fx .+ ifx
    y = fy .+ ify
    data = WaferData(x, y, v, wafer, fields)
    field_id = _match_centers(fx, fy, fields, tol)
    return FieldedData(data, fields, field_id, ifx, ify)
end

"""
    fielded(data::WaferData, fields) -> FieldedData

Fallback constructor when only absolute coordinates are available. Assigns each point to
the field whose bounding box contains it (`assign_to_fields`) and derives the intrafield
coordinate by subtracting the field centre — the lossy path; prefer the table constructor
when the intrafield offset is known directly.
"""
function fielded(data::WaferData, fields::Vector{WaferField})
    fid = assign_to_fields(data.x, data.y, fields)
    ifx = fill(NaN, length(data.x))
    ify = fill(NaN, length(data.y))
    for i in eachindex(data.x)
        j = fid[i]
        j == 0 && continue
        ifx[i] = data.x[i] - fields[j].x_center_mm
        ify[i] = data.y[i] - fields[j].y_center_mm
    end
    return FieldedData(data, fields, fid, ifx, ify)
end

function _match_centers(fx, fy, fields::Vector{WaferField}, tol::Real)
    inv = 1.0 / tol
    lut = Dict{Tuple{Int, Int}, Int}()
    for (j, f) in enumerate(fields)
        lut[(round(Int, f.x_center_mm * inv), round(Int, f.y_center_mm * inv))] = j
    end
    return [get(lut, (round(Int, fx[i] * inv), round(Int, fy[i] * inv)), 0) for i in eachindex(fx)]
end

"""
    assign_to_fields(x, y, fields) -> Vector{Int}

For each point, the index of the first field in `fields` whose bounding box contains it,
or 0 if none.
"""
function assign_to_fields(x::AbstractVector, y::AbstractVector, fields::Vector{WaferField})
    fid = zeros(Int, length(x))
    for i in eachindex(x)
        for (j, f) in enumerate(fields)
            xmin, xmax, ymin, ymax = field_bounds(f)
            if xmin <= x[i] <= xmax && ymin <= y[i] <= ymax
                fid[i] = j
                break
            end
        end
    end
    return fid
end

# ── fullness (partial vs full fields/dies) ─────────────────────────────────────

function _wafer_radius(wafer::WaferSpec, boundary::Symbol)
    boundary === :active && return wafer.diameter_mm / 2.0 - wafer.edge_exclusion_mm
    boundary === :edge && return wafer.diameter_mm / 2.0
    error("boundary must be :edge or :active, got :$boundary")
end

_corners_inside(xmin, xmax, ymin, ymax, r2) =
    all(cx^2 + cy^2 <= r2 for cx in (xmin, xmax), cy in (ymin, ymax))

# overlap = the rectangle's nearest point to the wafer centre is inside the disk
function _overlaps_wafer(xmin, xmax, ymin, ymax, r2)
    nx = clamp(0.0, xmin, xmax)
    ny = clamp(0.0, ymin, ymax)
    return nx^2 + ny^2 <= r2
end

"""
    is_full_field(f::WaferField, wafer; boundary=:edge) -> Bool

`true` when all four corners of the field lie within the wafer boundary
(`:edge` = `D/2`; `:active` = `D/2 − edge_exclusion_mm`).
"""
function is_full_field(f::WaferField, wafer::WaferSpec; boundary::Symbol = :edge)
    r2 = _wafer_radius(wafer, boundary)^2
    xmin, xmax, ymin, ymax = field_bounds(f)
    return _corners_inside(xmin, xmax, ymin, ymax, r2)
end

"""
    is_full_die(d::WaferDie, wafer; boundary=:edge) -> Bool

As `is_full_field` but for a `WaferDie` (uses `die_bounds`).
"""
function is_full_die(d::WaferDie, wafer::WaferSpec; boundary::Symbol = :edge)
    r2 = _wafer_radius(wafer, boundary)^2
    xmin, xmax, ymin, ymax = die_bounds(d)
    return _corners_inside(xmin, xmax, ymin, ymax, r2)
end

"Fields whose four corners all lie within the wafer boundary."
full_fields(fields::Vector{WaferField}, wafer::WaferSpec; boundary::Symbol = :edge) =
    filter(f -> is_full_field(f, wafer; boundary), fields)

"Fields that overlap the wafer but are not full (clipped by the edge)."
function partial_fields(fields::Vector{WaferField}, wafer::WaferSpec; boundary::Symbol = :edge)
    r2 = _wafer_radius(wafer, boundary)^2
    return filter(fields) do f
        xmin, xmax, ymin, ymax = field_bounds(f)
        _overlaps_wafer(xmin, xmax, ymin, ymax, r2) && !_corners_inside(xmin, xmax, ymin, ymax, r2)
    end
end

"Dies whose four corners all lie within the wafer boundary."
full_dies(dies::Vector{WaferDie}, wafer::WaferSpec; boundary::Symbol = :edge) =
    filter(d -> is_full_die(d, wafer; boundary), dies)

"""
    filter_full(fd::FieldedData; boundary=:edge) -> FieldedData

Keep only the measurements that fall on full fields.
"""
function filter_full(fd::FieldedData; boundary::Symbol = :edge)
    fullset = Set(j for (j, f) in enumerate(fd.fields) if is_full_field(f, fd.data.wafer; boundary))
    keep = [id in fullset for id in fd.field_id]
    d = fd.data
    newdata = WaferData(d.x[keep], d.y[keep], d.values[keep], d.wafer, d.fields)
    return FieldedData(newdata, fd.fields, fd.field_id[keep], fd.ifx[keep], fd.ify[keep])
end

# ── serpentine (boustrophedon) shot numbering ──────────────────────────────────

"""
    serpentine_numbers(fields; start=:bottomleft, first_row=:lr) -> Vector{Int}

Exposure (shot) number for each field following the scanner's meandering path: the first
field is at the start corner; the first row runs in `first_row` direction (`:lr` or `:rl`);
each row up reverses direction. Returns a vector aligned with `fields`.

`start` ∈ `(:bottomleft, :topleft)` chooses whether numbering begins at the bottom or top
row (`row_idx` increases +y per SEMI M21).
"""
function serpentine_numbers(fields::Vector{WaferField}; start::Symbol = :bottomleft, first_row::Symbol = :lr)
    start in (:bottomleft, :topleft) || error("start must be :bottomleft or :topleft, got :$start")
    first_row in (:lr, :rl) || error("first_row must be :lr or :rl, got :$first_row")
    n = length(fields)
    nums = zeros(Int, n)
    rows = sort(unique(f.row_idx for f in fields))   # ascending = bottom → top
    start === :topleft && (rows = reverse(rows))
    counter = 0
    for (k, r) in enumerate(rows)
        idxs = [i for i in 1:n if fields[i].row_idx == r]
        ltr = first_row === :lr ? isodd(k) : iseven(k)   # k=1 uses first_row, then alternate
        order = sortperm([fields[i].col_idx for i in idxs]; rev = !ltr)
        for ci in order
            counter += 1
            nums[idxs[ci]] = counter
        end
    end
    return nums
end

# ── intrafield stacking & average ──────────────────────────────────────────────

"""
    AveragedField

The intrafield average of stacked fields: at each intrafield cell, `value` is the mean
over all contributing fields and `count` is how many points fell in the cell. Entries are
sorted by `(ify, ifx)`.
"""
struct AveragedField
    ifx::Vector{Float64}
    ify::Vector{Float64}
    value::Vector{Float64}
    count::Vector{Int}
end

"""
    stack_fields(fd::FieldedData; full_only=true, tol=1e-3) -> AveragedField

Stack every (full) field on top of each other by intrafield coordinate and average. Points
are clustered by their field-local position within `tol` mm, so small fixed-precision
position errors still align.
"""
function stack_fields(fd::FieldedData; full_only::Bool = true, tol::Real = 1.0e-3)
    src = full_only ? filter_full(fd) : fd
    idx = [
        i for i in eachindex(src.field_id)
            if src.field_id[i] != 0 && isfinite(src.ifx[i]) && isfinite(src.ify[i])
    ]
    ifx = src.ifx[idx]
    ify = src.ify[idx]
    vals = Float64.(src.data.values[idx])
    groups = _cluster_xy(ifx, ify, tol)
    n = length(groups)
    ox = Vector{Float64}(undef, n)
    oy = Vector{Float64}(undef, n)
    ov = Vector{Float64}(undef, n)
    oc = Vector{Int}(undef, n)
    for (k, members) in enumerate(values(groups))
        ox[k] = mean(@view ifx[members])
        oy[k] = mean(@view ify[members])
        ov[k] = mean(@view vals[members])
        oc[k] = length(members)
    end
    p = sortperm(collect(zip(oy, ox)))
    return AveragedField(ox[p], oy[p], ov[p], oc[p])
end

"""
    FieldProfile

A 1-D intrafield profile: `value` averaged at each `pos` (with sample `count`), sorted by
`pos`.
"""
struct FieldProfile
    pos::Vector{Float64}
    value::Vector{Float64}
    count::Vector{Int}
end

function _profile(pos::AbstractVector, value::AbstractVector, tol::Real)
    groups = _cluster_1d(pos, tol)
    ks = sort(collect(keys(groups)))
    p = Float64[]
    v = Float64[]
    c = Int[]
    for k in ks
        m = groups[k]
        push!(p, mean(@view pos[m]))
        push!(v, mean(@view value[m]))
        push!(c, length(m))
    end
    return FieldProfile(p, v, c)
end

"""
    field_average_profiles(af::AveragedField; slit=:x, scan=:y, tol=1e-3)
        -> (slit=FieldProfile, scan=FieldProfile)

Decompose an intrafield average into its scanner components: the **slit** profile is the
average value vs slit-axis position (collapsing the scan axis), and the **scan** profile is
the average value vs scan-axis position (collapsing the slit axis). Default axes: slit = x
(non-scan), scan = y (stage motion).
"""
function field_average_profiles(af::AveragedField; slit::Symbol = :x, scan::Symbol = :y, tol::Real = 1.0e-3)
    (slit in (:x, :y) && scan in (:x, :y) && slit != scan) ||
        error("slit and scan must be distinct axes from (:x, :y), got slit=:$slit scan=:$scan")
    slitpos = slit === :x ? af.ifx : af.ify
    scanpos = scan === :x ? af.ifx : af.ify
    return (slit = _profile(slitpos, af.value, tol), scan = _profile(scanpos, af.value, tol))
end

"""
    field_kpis(af::AveragedField; kpis=DEFAULT_KPIS) -> Vector{Pair{String,Float64}}

KPIs computed over the averaged-field values.
"""
field_kpis(af::AveragedField; kpis::AbstractVector{<:AbstractKPI} = DEFAULT_KPIS) =
    [name(k) => compute(k, af.value) for k in kpis]

# ── wafer averaging ────────────────────────────────────────────────────────────

# cluster points pooled from every wafer by absolute (x, y) within tol; return the
# cluster representatives plus the member index lists (sorted by (y, x)).
function _pool_clusters(xs::Vector{Float64}, ys::Vector{Float64}, tol::Real)
    groups = _cluster_xy(xs, ys, tol)
    n = length(groups)
    ox = Vector{Float64}(undef, n)
    oy = Vector{Float64}(undef, n)
    members = Vector{Vector{Int}}(undef, n)
    for (k, m) in enumerate(values(groups))
        ox[k] = mean(@view xs[m])
        oy[k] = mean(@view ys[m])
        members[k] = m
    end
    p = sortperm(collect(zip(oy, ox)))
    return ox[p], oy[p], members[p]
end

"""
    average_wafers(datas::AbstractVector{<:WaferData}; tol=1e-3) -> WaferData

Stack multiple wafers and average their values position-by-position. Points are pooled
across wafers and clustered by absolute `(x, y)` within `tol` mm, so wafers that share a
sampling layout up to small fixed-precision position errors still align. The wafer spec and
`fields` are taken from the first wafer.
"""
function average_wafers(datas::AbstractVector{<:WaferData}; tol::Real = 1.0e-3)
    isempty(datas) && error("average_wafers: need at least one wafer")
    xs = reduce(vcat, (d.x for d in datas))
    ys = reduce(vcat, (d.y for d in datas))
    vs = reduce(vcat, (Float64.(d.values) for d in datas))
    ox, oy, members = _pool_clusters(xs, ys, tol)
    ov = [mean(@view vs[m]) for m in members]
    return WaferData(ox, oy, ov, datas[1].wafer, datas[1].fields)
end

"""
    average_wafers(datas::AbstractVector{<:WaferVectorData}; tol=1e-3) -> WaferVectorData

As above for vector data: averages `vx` and `vy` per matched position.
"""
function average_wafers(datas::AbstractVector{<:WaferVectorData}; tol::Real = 1.0e-3)
    isempty(datas) && error("average_wafers: need at least one wafer")
    xs = reduce(vcat, (d.x for d in datas))
    ys = reduce(vcat, (d.y for d in datas))
    vxs = reduce(vcat, (d.vx for d in datas))
    vys = reduce(vcat, (d.vy for d in datas))
    ox, oy, members = _pool_clusters(xs, ys, tol)
    ovx = [mean(@view vxs[m]) for m in members]
    ovy = [mean(@view vys[m]) for m in members]
    return WaferVectorData(ox, oy, ovx, ovy, datas[1].wafer, datas[1].fields)
end

# ── arrow reference scale ──────────────────────────────────────────────────────

"Round to a \"nice\" 1/2/5 × 10^k value (used for reference-arrow labels)."
function _nice_magnitude(v::Real)
    v <= 0 && return Float64(v)
    p = 10.0^floor(log10(v))
    m = v / p
    nice = m < 1.5 ? 1.0 : m < 3.0 ? 2.0 : m < 7.0 ? 5.0 : 10.0
    return nice * p
end

"""
    ArrowScale

A fixed arrow scale: a vector of magnitude `ref_magnitude` is drawn `ref_length_mm` long,
i.e. `lengthscale = ref_length_mm / ref_magnitude`. Build one with [`arrow_scale`](@ref) or
[`arrow_scale_from`](@ref) and pass the **same** `ArrowScale` to every plot so arrows are
directly comparable across wafers/lots.
"""
struct ArrowScale
    lengthscale::Float64
    ref_magnitude::Float64
    ref_length_mm::Float64
    label::String
end

"""
    arrow_scale(ref_magnitude, ref_length_mm; label=string(ref_magnitude)) -> ArrowScale

Define the scale explicitly: a vector of magnitude `ref_magnitude` renders `ref_length_mm`
mm long.
"""
function arrow_scale(ref_magnitude::Real, ref_length_mm::Real; label::AbstractString = string(ref_magnitude))
    ref_magnitude > 0 || error("ref_magnitude must be positive, got $ref_magnitude")
    ref_length_mm > 0 || error("ref_length_mm must be positive, got $ref_length_mm")
    return ArrowScale(ref_length_mm / ref_magnitude, Float64(ref_magnitude), Float64(ref_length_mm), label)
end

"""
    arrow_scale_from(vdata::WaferVectorData; ref_fraction=0.1, label=nothing) -> ArrowScale

Designate a scale from a reference wafer/lot: the reference magnitude is the nice-rounded
median `|v|`, drawn at `ref_fraction` of the wafer radius. Apply the result to other wafers
for a common scale.
"""
function arrow_scale_from(vdata::WaferVectorData; ref_fraction::Real = 0.1, label = nothing)
    refmag = _nice_magnitude(median(hypot.(vdata.vx, vdata.vy)))
    refmag > 0 || error("arrow_scale_from: vector field has zero median magnitude")
    ref_len = ref_fraction * (vdata.wafer.diameter_mm / 2.0)
    return ArrowScale(ref_len / refmag, refmag, ref_len, label === nothing ? string(refmag) : String(label))
end
