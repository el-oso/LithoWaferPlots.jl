# Getting Started

## Installation

```julia
using Pkg
Pkg.add("LithoWaferPlots")
```

Add a Makie backend for rendering (GLMakie for desktop, WGLMakie for notebooks):

```julia
Pkg.add("GLMakie")
```

## Step 1 — Define the wafer (optional)

Every data constructor uses `WaferSpec()` — a 300 mm wafer with the notch at 270°
(bottom) — unless you pass a different one. Build a `WaferSpec` only for other wafers:

```julia
using LithoWaferPlots

wafer = WaferSpec(200.0, 0.0)      # 200mm, notch at 3 o'clock (0°, standard math angle)

# notch depth/width/shape are independently configurable keywords:
wafer = WaferSpec(300.0, 270.0, 3.0, 2.0; notch_shape = :flat, notch_width_mm = 8.0)
```

## Step 2 — Load measurement data

### From a DataFrame (mm coordinates)

```julia
using DataFrames
df = DataFrame(x=meas_x, y=meas_y, value=meas_v)
data = WaferData(df)
data = WaferData(df, wafer)        # on a non-default wafer
```

### From die indices

```julia
grid = DieGrid(-75.0, -75.0, 5.0, 5.0)   # origin mm, die pitch mm
df = DataFrame(col=col_idx, row=row_idx, value=vals)
data = WaferData(df, grid)
```

### From plain arrays

```julia
data = WaferData(xs, ys, vs)
data = WaferData(xs, ys, vs; wafer)   # on a non-default wafer
```

Rows with a non-finite `x`, `y`, or `value` (`NaN`/`Inf`) are dropped automatically at
construction, with a one-time warning — a bad measurement point can't silently corrupt an
entire colorbar or KPI.

## Step 3 — Plot

For a quick look, the non-mutating recipes create their own correctly proportioned axis:

```julia
using GLMakie

waferheatmap(data)
```

[`wafer_figure`](@ref) adds a side panel for a colorbar and KPIs. `plot_type` picks
`:heatmap` (default), `:scatter`, or `:contour`, and other keywords go to the plot:

```julia
fig, ax, p = wafer_figure(data; label = "Overlay (a.u.)", colormap = :plasma)
```

To customize the side panel, build the same figure step by step:

```julia
fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :plasma)
add_colorbar!(side, p; label = "Overlay (a.u.)")
add_kpi_panel!(side, data; sigdigits = 3)
```

Any Makie attribute the underlying primitive supports (`marker`, `strokewidth`, `alpha`,
`linestyle`, `interpolate`, ...) can be passed straight through, e.g.
`waferscatter!(ax, data; marker=:diamond, alpha=0.7)` — no need to memorize a curated list.

![Heatmap](assets/example_heatmap.png)

## Step 4 — Add field overlays

Pass a `fields` vector when constructing `WaferData` to overlay rectangular
exposure fields on any plot type. [`field_grid`](@ref) builds the grid and drops fields
that don't overlap the wafer disk in one call:

```julia
centers = [((ci - 0.5) * 26.0, (ri - 5) * 33.0) for ri in 1:9, ci in -5:6]   # 12 × 9 grid
fields = field_grid(centers, (26.0, 33.0); wafer = WaferSpec())

data = WaferData(df; fields)
```

![Heatmap with field overlay](assets/example_heatmap_fields.png)

## Step 5 — Vector field plots

```julia
vdata = WaferVectorData(df)   # df has :x, :y, :vx, :vy columns

# Arrows
waferarrows!(ax, vdata; lengthscale=2.0)
```

![Arrow plot](assets/example_arrows.png)

```julia
# Streamlines
waferstreamlines!(ax, vdata; n_seeds=12, max_steps=80)
```

![Streamlines](assets/example_streamlines.png)

```julia
# Derived scalar fields
waferdivergence!(ax, vdata)
wafervorticity!(ax, vdata)
```

See the [Gallery](@ref) for divergence and vorticity examples.
