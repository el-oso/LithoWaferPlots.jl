# Field & Wafer Analysis

Beyond drawing a single wafer map, LithoWaferPlots can reason about **exposure fields**:
which measurement belongs to which field, where it sits *inside* that field, whether a field
is fully on the wafer, and how fields and whole wafers stack and average. This page walks
through that workflow end to end. Every block below runs live during the docs build.

```@example fa
using LithoWaferPlots, CairoMakie
CairoMakie.activate!(type = "png")

wafer = WaferSpec(300.0)
fields = field_grid([((c - 0.5) * 26.0, (r - 5) * 33.0) for r in 1:9, c in -5:6], (26.0, 33.0); wafer = wafer)
length(fields)
```

## Attaching measurements to fields

Metrology data usually arrives as a **field centre plus an intrafield offset** — e.g. "field
at (78, 33) mm, 2.1 µm to the right of its centre". Adding the two to an absolute position
compounds error (text files store fixed decimal places, so accuracy degrades at large
radius). [`fielded`](@ref) therefore keeps the intrafield coordinate *as given* and only adds
it for plotting:

```@example fa
# synthetic measurements: every field sampled on a 5×5 intrafield grid, with an
# intrafield signature (parabolic across slit, linear along scan) plus per-field noise
fx = Float64[]; fy = Float64[]; dx = Float64[]; dy = Float64[]; val = Float64[]
for f in fields, ix in -10.0:5.0:10.0, iy in -13.0:6.5:13.0
    push!(fx, f.x_center_mm); push!(fy, f.y_center_mm)
    push!(dx, ix); push!(dy, iy)
    push!(val, 0.02 * ix^2 + 0.1 * iy + 0.4 * randn())
end

fd = fielded((fx = fx, fy = fy, dx = dx, dy = dy, value = val), fields; wafer = wafer)
(npoints = length(fd.field_id), first_field = fd.field_id[1], first_offset = (fd.ifx[1], fd.ify[1]))
```

`fd.data` is an ordinary [`WaferData`](@ref) (absolute coordinates) you can pass to any plot;
`fd.field_id`, `fd.ifx`, `fd.ify` carry the per-point field index and intrafield offset. If
you only have absolute coordinates, `fielded(data::WaferData, fields)` assigns points by
bounding box and derives the offset by subtraction (the lossy path).

## Full vs partial fields

A field is **full** when all four corners fall inside the wafer; otherwise it is **partial**
(clipped by the edge). Use `boundary = :active` to test against the edge-exclusion radius
instead of the physical edge.

```@example fa
(full = length(full_fields(fields, wafer)),
 partial = length(partial_fields(fields, wafer)),
 full_active = length(full_fields(fields, wafer; boundary = :active)))
```

[`filter_full`](@ref) drops every measurement that lands on a partial field — the usual first
step before computing field statistics:

```@example fa
fd_full = filter_full(fd)
(kept = length(fd_full.field_id), of = length(fd.field_id))
```

## Labelling fields by shot number

[`draw_field_numbers!`](@ref) annotates each field with its exposure (shot) number. The
default follows the scanner's serpentine path — bottom-left first, left-to-right, then
reversing each row up — via [`serpentine_numbers`](@ref). Pass `numbers = ...` for an explicit
order.

```@example fa
d = WaferData((x = fd.data.x, y = fd.data.y, value = fd.data.values), wafer; fields = fields)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, d)
add_colorbar!(side, p; label = "signal (a.u.)")
draw_field_numbers!(ax, full_fields(fields, wafer))
fig
```

## The intrafield average

[`stack_fields`](@ref) lays every full field on top of each other by intrafield coordinate
and averages — so random per-field noise cancels and the systematic **intrafield signature**
emerges. Points are matched within a tolerance (`tol`, default 1 µm), which absorbs
fixed-precision jitter.

```@example fa
af = stack_fields(fd; full_only = true)
(cells = length(af.value), samples_per_cell = extrema(af.count))
```

[`plot_averaged_field`](@ref) renders the average with its **slit** and **scan** direction
profiles as margins and a KPI strip. The slit profile averages over the scan axis (and vice
versa); set `slit`/`scan` to choose which intrafield axis is which (default `slit = :x`,
`scan = :y`).

```@example fa
plot_averaged_field(af; markersize = 16.0f0)
```

KPIs over the averaged field are available directly:

```@example fa
field_kpis(af)
```

### Per-field panels

To inspect fields individually rather than stacked, [`field_facet`](@ref) draws one panel per
field in field-local coordinates:

```@example fa
field_facet(fd; full_only = true, colorrange = extrema(val), ncols = 6)
```

## Averaging wafers

[`average_wafers`](@ref) stacks several wafers and averages value-by-value, matching points
across wafers by absolute position within `tol`. It accepts scalar (`WaferData`) or vector
(`WaferVectorData`) wafers and returns the same type, so the result feeds straight back into
the plots and KPI panel.

```@example fa
# three wafers sharing a layout, each with a different offset + noise
base = (x = fd.data.x, y = fd.data.y)
wafers = [WaferData((; base..., value = fd.data.values .+ k .+ 0.2 .* randn(length(val))), wafer)
          for k in 0:2]
avg = average_wafers(wafers)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, avg)
add_colorbar!(side, p; label = "mean signal")
add_kpi_panel!(side, avg; sigdigits = 3)
fig
```

The `sigdigits` keyword on [`add_kpi_panel!`](@ref) controls the displayed precision; it
rounds before calling [`format_value`](@ref), so custom KPI formatters are honoured.

## A shared arrow scale for comparing lots

When comparing vector fields across lots or wafers, the arrows must use the **same** scale or
the comparison is meaningless. [`arrow_scale_from`](@ref) designates a scale from a reference
wafer (or build one explicitly with [`arrow_scale`](@ref)); passing the same `ArrowScale` to
every plot guarantees identical arrow scaling and an identical reference arrow.

```@example fa
θ = rand(180) .* 2π; rr = sqrt.(rand(180)) .* 140
x = @. rr * cos(θ); y = @. rr * sin(θ)
lotA = WaferVectorData((x = x, y = y, vx = -y ./ 150, vy = x ./ 150), wafer)
lotB = WaferVectorData((x = x, y = y, vx = -y ./ 75, vy = x ./ 75), wafer)   # 2× magnitude

scale = arrow_scale_from(lotA; ref_fraction = 0.12)   # designate once, reuse everywhere

fig = Figure(size = (760, 400))
for (j, (lab, vd)) in enumerate((("lot A", lotA), ("lot B", lotB)))
    pax = Axis(fig[1, j]; aspect = DataAspect(), title = lab,
               xgridvisible = false, ygridvisible = false)
    waferarrows!(pax, vd; scale = scale, arrowcolor = :magnitude)
    add_scale_arrow!(pax, scale)
end
fig
```

Lot B's arrows are visibly twice as long as lot A's, while the reference arrow is identical —
the difference is real, not a scaling artefact.
