# Gallery

All plots use CairoMakie. For interactive desktop rendering swap in `GLMakie`.

## Scatter

Sparse measurement points coloured by value. Good for raw probe data where
point density is uneven.

```julia
fig, ax, side = wafer_figure()
p = waferscatter!(ax, data; markersize=4f0)
add_colorbar!(side, p; label="Overlay (a.u.)")
add_kpi_panel!(side, data)
```

![Scatter plot](assets/example_scatter.png)

---

## Heatmap

Dense rectangular markers produce a filled colour map. `percentile_clip`
removes colour-scale distortion from outliers.

```julia
fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; markersize=3f0, colormap=:plasma)
add_colorbar!(side, p; label="Thickness (nm)")
add_kpi_panel!(side, data)
```

![Heatmap](assets/example_heatmap.png)

---

## Heatmap with field overlay

Pass a `fields` vector to `WaferData` to overlay exposure-field or die
boundaries on any plot type.

```julia
fields = [WaferField(cx, cy, 26.0, 33.0, ci, ri)
          for (ri, cy) in zip(-1:1, [-33.0, 0.0, 33.0])
          for (ci, cx) in zip(-1:1, [-26.0, 0.0, 26.0])]

data = WaferData(table, wafer; fields=fields)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap=:plasma,
                  field_strokecolor=:black, field_strokewidth=1.5f0)
add_colorbar!(side, p; label="Thickness (nm)")
add_kpi_panel!(side, data)
```

![Heatmap with field overlay](assets/example_heatmap_fields.png)

---

## Contour

Scattered data is interpolated to a regular grid before contouring.
Adjust `grid_n` (default 256) and `levels` as needed.

```julia
fig, ax, side = wafer_figure()
p = wafercontour!(ax, data; levels=12, colormap=:viridis)
add_colorbar!(side, p; label="Overlay (a.u.)")
```

![Contour plot](assets/example_contour.png)

---

## Arrows

Arrow plot of a vector field. Subsampled to `max_arrows` (default 20 000)
for legibility. Scale arrows with `lengthscale`.

```julia
fig, ax, side = wafer_figure()
waferarrows!(ax, vdata; lengthscale=8.0, arrowcolor=:steelblue)
```

![Arrow plot](assets/example_arrows.png)

---

## Streamlines

RK4-traced stream lines from a uniform seed grid. Controls: `n_seeds`,
`max_steps`, and `step_size`.

```julia
fig, ax, side = wafer_figure()
waferstreamlines!(ax, vdata; n_seeds=12, max_steps=80,
                  color=:navy, linewidth=1.2f0)
```

![Streamlines](assets/example_streamlines.png)

---

## Divergence

∇·**v** = ∂vx/∂x + ∂vy/∂y, computed by IDW interpolation to a regular grid
then central finite differences. A diverging colormap (`:RdBu`) centres the
colourscale on zero.

```julia
fig, ax, side = wafer_figure()
p = waferdivergence!(ax, vdata; colormap=:RdBu)
add_colorbar!(side, p; label="Divergence (a.u.)")
```

![Divergence](assets/example_divergence.png)

---

## Vorticity

∇×**v** = ∂vy/∂x − ∂vx/∂y. Positive values (red) indicate counterclockwise
rotation; negative (blue) indicate clockwise.

```julia
fig, ax, side = wafer_figure()
p = wafervorticity!(ax, vdata)
add_colorbar!(side, p; label="Vorticity (a.u.)")
```

![Vorticity](assets/example_vorticity.png)
