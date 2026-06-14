# Getting Started

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/el-oso/LithoWaferPlots.jl")
```

Add a Makie backend for rendering (GLMakie for desktop, WGLMakie for notebooks):

```julia
Pkg.add("GLMakie")
```

## Step 1 — Define the wafer

```julia
using LithoWaferPlots

wafer = WaferSpec(300.0)          # 300mm diameter, default notch at 270° (bottom)
wafer = WaferSpec(200.0, 90.0)    # 200mm, notch at 3 o'clock
```

## Step 2 — Load measurement data

### From a DataFrame (mm coordinates)

```julia
using DataFrames
df = DataFrame(x=meas_x, y=meas_y, value=meas_v)
data = WaferData(df, wafer)
```

### From die indices

```julia
grid = DieGrid(-75.0, -75.0, 5.0, 5.0)   # origin mm, die pitch mm
df = DataFrame(col=col_idx, row=row_idx, value=vals)
data = WaferData(df, grid, wafer)
```

### From plain arrays

```julia
data = WaferData((x=xs, y=ys, value=vs), wafer)
```

## Step 3 — Plot

```julia
using GLMakie

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data)
add_colorbar!(side, p; label="Overlay (a.u.)")
add_kpi_panel!(side, data)
display(fig)
```

## Step 4 — Add field overlays

```julia
fields = [
    WaferField(-25.0, 0.0, 26.0, 33.0, -1, 0),
    WaferField(  0.0, 0.0, 26.0, 33.0,  0, 0),
    WaferField( 25.0, 0.0, 26.0, 33.0,  1, 0),
]
data = WaferData(df, wafer; fields=fields)
```

## Step 5 — Vector field plots

```julia
vdata = WaferVectorData(df, wafer)   # df has :x, :y, :vx, :vy columns

# Arrows
waferarrows!(ax, vdata; lengthscale=2.0)

# Streamlines
waferstreamlines!(ax, vdata; n_seeds=15)

# Derived scalar fields
waferdivergence!(ax, vdata)
wafervorticity!(ax, vdata)
```
