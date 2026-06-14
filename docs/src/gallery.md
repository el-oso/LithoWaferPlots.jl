# Gallery

All plots use CairoMakie. Swap in `GLMakie` for interactive desktop windows or `WGLMakie` for Jupyter/Pluto notebooks.

## Scatter

Sparse measurement points coloured by value. Good for raw probe data where point density is uneven.

```julia
fig, ax, side = wafer_figure()
p = waferscatter!(ax, data; markersize=4f0)
add_colorbar!(side, p; label="Overlay (a.u.)")
add_kpi_panel!(side, data)
```

![Scatter plot](assets/example_scatter.png)

---

## Heatmap

Dense rectangular markers produce a filled colour map. For datasets with more than 5 000 points the recipe automatically switches to an `image!` GPU texture path for faster rendering. `percentile_clip` removes colour-scale distortion from outliers.

```julia
fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap=:plasma)
add_colorbar!(side, p; label="Thickness (nm)")
add_kpi_panel!(side, data)
```

For a large regular-grid dataset (> 5 000 points), the recipe uses `imagemode=:image` automatically. Override with `imagemode=:scatter` or `imagemode=:image` explicitly.

![Heatmap](assets/example_heatmap.png)

---

## Heatmap with field overlay

Pass a `fields` vector to `WaferData` to overlay exposure-field or die boundaries on any plot type. Fields may extend beyond the wafer edge.

```julia
# 108 fields (12 columns × 9 rows) covering the full 300 mm wafer
fields = vec([WaferField((ci - 0.5)*26.0, (ri - 5)*33.0, 26.0, 33.0, ci, ri)
              for ri in 1:9, ci in -5:6])

data = WaferData(table, wafer; fields=fields)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap=:plasma,
                  field_color=(:black, 0.0),
                  field_strokecolor=:black, field_strokewidth=1.8f0)
add_colorbar!(side, p; label="Thickness (nm)")
add_kpi_panel!(side, data)
```

![Heatmap with field overlay](assets/example_heatmap_fields.png)

---

## Contour

Scattered data is interpolated to a regular grid via IDW before contouring. Adjust `grid_n` (default 256) and `levels` as needed.

```julia
fig, ax, side = wafer_figure()
p = wafercontour!(ax, data; levels=12, colormap=:viridis)
add_colorbar!(side, p; label="Overlay (a.u.)")
```

![Contour plot](assets/example_contour.png)

---

## Arrows

Arrow plot of a vector field. Subsampled to `max_arrows` (default 20 000) for legibility. Scale arrows with `lengthscale`.

```julia
fig, ax, side = wafer_figure()
waferarrows!(ax, vdata; lengthscale=8.0, arrowcolor=:steelblue)
```

![Arrow plot](assets/example_arrows.png)

---

## Streamlines

RK4-traced stream lines from a uniform seed grid. Controls: `n_seeds`, `max_steps`, and `step_size`.

```julia
fig, ax, side = wafer_figure()
waferstreamlines!(ax, vdata; n_seeds=12, max_steps=80,
                  color=:navy, linewidth=1.2f0)
```

![Streamlines](assets/example_streamlines.png)

---

## Divergence

∇·**v** = ∂vx/∂x + ∂vy/∂y, computed by IDW interpolation to a regular grid then central finite differences. A diverging colormap (`:RdBu`) centres the colour scale on zero.

```julia
fig, ax, side = wafer_figure()
p = waferdivergence!(ax, vdata; colormap=:RdBu)
add_colorbar!(side, p; label="Divergence (a.u.)")
```

![Divergence](assets/example_divergence.png)

---

## Vorticity

∇×**v** = ∂vy/∂x − ∂vx/∂y. Positive values (red) indicate counterclockwise rotation; negative (blue) indicate clockwise.

```julia
fig, ax, side = wafer_figure()
p = wafervorticity!(ax, vdata)
add_colorbar!(side, p; label="Vorticity (a.u.)")
```

![Vorticity](assets/example_vorticity.png)
