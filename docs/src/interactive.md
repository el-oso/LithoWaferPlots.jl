# Interactive plots

The plots on this page are rendered with **WGLMakie** and are fully interactive in your
browser — drag to pan, scroll to zoom, and use the axis toolbar. They are self-contained
(no server needed), but each carries a WebGL scene and is a few MB, so they live on this
dedicated page rather than the main [Gallery](@ref) (which stays light and static).

To produce interactive output yourself, swap the backend:

```julia
using LithoWaferPlots, WGLMakie   # instead of CairoMakie
```

```@setup interactive
using LithoWaferPlots, WGLMakie, Bonito
Page(exportable = true, offline = true)
WGLMakie.activate!()
wafer = WaferSpec(300.0)
```

## Interactive scatter

A sparse measurement cloud. Scroll to zoom into a region, drag to pan.

```@example interactive
θ = rand(3000) .* 2π
r = sqrt.(rand(3000)) .* 148.0
data = WaferData((x = r .* cos.(θ), y = r .* sin.(θ),
                  value = sin.(r ./ 30) .+ 0.2 .* randn(3000)), wafer)
fig, ax, side = wafer_figure()
p = waferscatter!(ax, data; markersize = 6.0f0)
add_colorbar!(side, p; label = "Overlay (a.u.)")
fig
```

## Interactive vector field

A vortex flow drawn as arrows — zoom in to inspect individual vectors near the centre.

```@example interactive
n = 1500
θ = rand(n) .* 2π
r = sqrt.(rand(n)) .* 130.0
x = r .* cos.(θ); y = r .* sin.(θ)
vdata = WaferVectorData((x = x, y = y, vx = -y ./ 80, vy = x ./ 80), wafer)
fig, ax, side = wafer_figure()
waferarrows!(ax, vdata; lengthscale = 8.0, arrowcolor = :steelblue)
fig
```
