# Gallery

Every plot below is **rendered live during the documentation build from the exact code
shown above it**. Each example is self-contained: copy the preamble here plus any single
block and it runs as-is. All plots use CairoMakie; swap in `GLMakie` for interactive desktop
windows or `WGLMakie` for Jupyter/Pluto notebooks.

```@example gallery
using LithoWaferPlots, CairoMakie
CairoMakie.activate!(type = "png")
wafer = WaferSpec(300.0)
nothing # hide
```

## Scatter

Sparse measurement points coloured by value. Good for raw probe data where point density is uneven.

```@example gallery
θ = rand(8000) .* 2π
r = sqrt.(rand(8000)) .* 148.0
x = @. r * cos(θ); y = @. r * sin(θ)
v = @. 2.5 * exp(-((x - 60)^2 + (y + 40)^2) / 4000) + 0.15 * $(randn(8000))
data = WaferData((x = x, y = y, value = v), wafer)

fig, ax, side = wafer_figure()
p = waferscatter!(ax, data; markersize = 4.0f0)
add_colorbar!(side, p; label = "Overlay (a.u.)")
add_kpi_panel!(side, data)
fig
```

---

## Heatmap

Dense rectangular markers produce a filled colour map. Above 5 000 points the recipe switches
to an `image!` GPU texture path automatically; override with `imagemode = :scatter` or `:image`.
`percentile_clip` reduces outlier distortion of the colour scale.

```@example gallery
xs = range(-148.0, 148.0; step = 3.0); ys = range(-148.0, 148.0; step = 3.0)
pts = [(x, y) for x in xs, y in ys if x^2 + y^2 <= 148.0^2]
x = first.(pts); y = last.(pts)
v = @. sin(x / 40) * cos(y / 40) + 0.5 * exp(-(x^2 + y^2) / 8000) + 0.08 * $(randn(length(x)))
data = WaferData((x = x, y = y, value = v), wafer)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :plasma)
add_colorbar!(side, p; label = "Thickness (nm)")
add_kpi_panel!(side, data)
fig
```

---

## Heatmap with field overlay

Pass a `fields` vector to `WaferData` to overlay exposure-field or die boundaries on any plot
type. Fields may extend beyond the wafer edge.

```@example gallery
fw, fh = 26.0, 33.0
centers = [((c - 0.5) * fw, (rw - 5) * fh) for rw in 1:9, c in -5:6]
fields = field_grid(centers, (fw, fh); wafer = wafer)

xs = range(-148.0, 148.0; step = 3.0); ys = range(-148.0, 148.0; step = 3.0)
pts = [(x, y) for x in xs, y in ys if x^2 + y^2 <= 148.0^2]
x = first.(pts); y = last.(pts)
v = @. sin(x / 40) * cos(y / 40) + 0.08 * $(randn(length(x)))
data = WaferData((x = x, y = y, value = v); fields = fields)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :plasma,
                  field_color = (:black, 0.0),
                  field_strokecolor = :black, field_strokewidth = 1.8f0)
add_colorbar!(side, p; label = "Thickness (nm)")
add_kpi_panel!(side, data)
fig
```

---

## Contour

Scattered data is interpolated to a regular grid via IDW before contouring. Adjust `grid_n`
(default 256) and `levels` as needed.

```@example gallery
xs = range(-148.0, 148.0; step = 5.0); ys = range(-148.0, 148.0; step = 5.0)
pts = [(x, y) for x in xs, y in ys if x^2 + y^2 <= 148.0^2]
x = first.(pts); y = last.(pts)
v = @. sin(x / 40) * cos(y / 40) + 0.5 * exp(-(x^2 + y^2) / 8000) + 0.08 * $(randn(length(x)))
data = WaferData((x = x, y = y, value = v), wafer)

fig, ax, side = wafer_figure()
p = wafercontour!(ax, data; levels = 12, colormap = :viridis)
add_colorbar!(side, p; label = "Overlay (a.u.)")
fig
```

---

## Arrows

Arrow plot of a vector field. Subsampled to `max_arrows` (default 4 000) for legibility, and
drawn as a single batched `lines!` call (shaft plus a V arrowhead) for low memory use. Scale
with `lengthscale`; tune the head with `head_frac` and `head_angle`.

```@example gallery
θ = rand(600) .* 2π
r = sqrt.(rand(600)) .* 130.0
x = @. r * cos(θ); y = @. r * sin(θ)
vdata = WaferVectorData((x = x, y = y, vx = -y ./ 80 .+ x ./ 300, vy = x ./ 80 .+ y ./ 300), wafer)

fig, ax, side = wafer_figure()
waferarrows!(ax, vdata; lengthscale = 8.0, arrowcolor = :steelblue)
fig
```

---

## Streamlines

RK4-traced stream lines from a uniform seed grid. The velocity field is interpolated once to a
`grid_n × grid_n` grid and sampled bilinearly during integration, so tracing is fast even for
large datasets. Controls: `n_seeds`, `max_steps`, `step_size`, and `grid_n`.

```@example gallery
θ = rand(15_000) .* 2π
r = sqrt.(rand(15_000)) .* 130.0
x = @. r * cos(θ); y = @. r * sin(θ)
vdata = WaferVectorData((x = x, y = y, vx = -y ./ 80 .+ x ./ 300, vy = x ./ 80 .+ y ./ 300), wafer)

fig, ax, side = wafer_figure()
waferstreamlines!(ax, vdata; n_seeds = 12, max_steps = 80, color = :navy, linewidth = 1.2f0)
fig
```

---

## Divergence

∇·**v** = ∂vx/∂x + ∂vy/∂y, computed by IDW interpolation to a regular grid then central finite
differences. A diverging colormap (`:RdBu`) centres the colour scale on zero.

```@example gallery
# a source at (+60, +40) and a sink at (−50, −50)
θ = rand(30_000) .* 2π
r = sqrt.(rand(30_000)) .* 140.0
x = @. r * cos(θ); y = @. r * sin(θ)
src(cx, cy, a) = (w = @.(a * exp(-((x - cx)^2 + (y - cy)^2) / 2500));
                  (@.(w * (x - cx)), @.(w * (y - cy))))
vx1, vy1 = src(60.0, 40.0, 1.0)
vx2, vy2 = src(-50.0, -50.0, -1.0)
vdata = WaferVectorData((x = x, y = y, vx = vx1 .+ vx2, vy = vy1 .+ vy2), wafer)

fig, ax, side = wafer_figure()
p = waferdivergence!(ax, vdata; colormap = :RdBu, markersize = 3.0f0)
add_colorbar!(side, p; label = "Divergence (a.u.)")
fig
```

---

## Vorticity

∇×**v** = ∂vy/∂x − ∂vx/∂y. Positive values (red) indicate counterclockwise rotation; negative
(blue) indicate clockwise.

```@example gallery
# differential rotation: fast core, slow rim
θ = rand(30_000) .* 2π
r = sqrt.(rand(30_000)) .* 140.0
x = @. r * cos(θ); y = @. r * sin(θ)
speed = @. exp(-(x^2 + y^2) / 5000.0)
vdata = WaferVectorData((x = x, y = y, vx = -y .* speed ./ 40, vy = x .* speed ./ 40), wafer)

fig, ax, side = wafer_figure()
p = wafervorticity!(ax, vdata; markersize = 3.0f0)
add_colorbar!(side, p; label = "Vorticity (a.u.)")
fig
```

---

## Die-level yield map

Per-die yield across ~100 exposure fields (3×3 = 9 dies each). Field boundaries are overlaid as
thin gray strokes. The 2 mm edge-exclusion ring dims the outer annulus where yield data is
typically not trusted.

```@example gallery
fw, fh = 26.0, 33.0
rmax = wafer.diameter_mm / 2
centers = [((c - 0.5) * fw, (rw - 5) * fh) for rw in 1:9, c in -5:6]
fields = field_grid(centers, (fw, fh); wafer = wafer)

# 3×3 die centres per field
dies = [(f.x_center_mm - fw / 2 + (di + 0.5) * fw / 3,
         f.y_center_mm - fh / 2 + (dj + 0.5) * fh / 3)
        for f in fields for di in 0:2 for dj in 0:2]
yieldval(cx, cy) = clamp(clamp(1 - (cx^2 + cy^2) / (0.85 * rmax^2), 0, 1) + 0.12 * randn(), 0, 1)
data = WaferData((x = first.(dies), y = last.(dies),
                  value = [yieldval(d...) for d in dies]); fields = fields)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; markersize = 14.0f0, colormap = :RdYlGn,
                  field_color = (:black, 0.0),
                  field_strokecolor = :gray50, field_strokewidth = 0.7f0)
add_colorbar!(side, p; label = "Yield")
add_kpi_panel!(side, data)
add_exclusion_ring!(ax, wafer; mm_to_edge = 2.0, label = "2 mm EE",
                    color = :black, linestyle = :dash, dim_outside = true, dim_alpha = 0.4)
add_ring_legend!(ax; position = :lb)
fig
```

---

## Exclusion ring annotation

Draw dashed/dotted radial exclusion rings on any plot, specified as **mm to the edge** (the
natural fab unit). Optionally dim the region outside the ring with a semi-transparent overlay
that works with every recipe type.

```@example gallery
xs = range(-148.0, 148.0; step = 3.0); ys = range(-148.0, 148.0; step = 3.0)
pts = [(x, y) for x in xs, y in ys if x^2 + y^2 <= 148.0^2]
x = first.(pts); y = last.(pts)
data = WaferData((x = x, y = y, value = @.(sin(x / 40) * cos(y / 40))), wafer)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :plasma)
add_colorbar!(side, p; label = "Thickness (nm)")
add_kpi_panel!(side, data)

# inner ring — dashed white line only
add_exclusion_ring!(ax, wafer; mm_to_edge = 2.0,
    label = "2 mm EE", color = :white, linestyle = :dash)

# outer ring — dotted + dim the annular region outside it
add_exclusion_ring!(ax, wafer; mm_to_edge = 20.0,
    label = "20 mm keep-out", color = :yellow, linestyle = :dot,
    dim_outside = true, dim_alpha = 0.35)

add_ring_legend!(ax; position = :rb)
fig
```

---

## Logo & watermark

Brand a plot with a custom logo and/or a faded watermark. The image is anchored in a fixed
position (corner or centre) and keeps its aspect ratio regardless of zoom or data range.
Per-pixel alpha is honoured and a global `opacity` multiplier is applied on top, so transparent
regions let the plot show through. The image can be a **file path** (PNG with alpha) or an
**`AbstractMatrix` of colors**; target either the wafer `Axis` or the whole `Figure`. `position`
accepts `:lt :ct :rt :lc :center :rc :lb :cb :rb` or an `(fx, fy)` tuple.

```@example gallery
# a synthetic RGBA logo: brand-coloured ring with a notch + filled centre dot
logo = fill(RGBAf(0, 0, 0, 0), 160, 160)
for i in 1:160, j in 1:160
    px = (i - 0.5) / 160 - 0.5; py = (j - 0.5) / 160 - 0.5
    rr = sqrt(px^2 + py^2); a = atan(py, px)
    0.30 <= rr <= 0.46 && (logo[i, j] = RGBAf(0.10, 0.45, 0.80, 0.95))
    (rr >= 0.28 && abs(a + π / 2) < 0.22) && (logo[i, j] = RGBAf(0, 0, 0, 0))
    rr <= 0.12 && (logo[i, j] = RGBAf(0.95, 0.55, 0.05, 1.0))
end

xs = range(-148.0, 148.0; step = 3.0); ys = range(-148.0, 148.0; step = 3.0)
pts = [(x, y) for x in xs, y in ys if x^2 + y^2 <= 148.0^2]
x = first.(pts); y = last.(pts)
data = WaferData((x = x, y = y, value = @.(sin(x / 40) * cos(y / 40))), wafer)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :viridis)
add_colorbar!(side, p; label = "Thickness (nm)")
add_watermark!(ax, logo; opacity = 0.12, scale = 0.7)   # faded, centred
add_logo!(ax, logo; position = :rt, scale = 0.16)        # opaque, top-right
fig
```

---

## Faceted wafer grid

`wafer_facet` groups any Tables.jl-compatible source by a column and renders one wafer panel per
group. Pass `colorrange = (lo, hi)` for a shared colorscale (single colorbar below the grid);
omit it for independent per-panel scaling. Works with any `plot_type`: `:heatmap` (default),
`:scatter`, or `:contour`.

```@example gallery
patterns = [("Lot A", (cx, cy) -> 100 + 8exp(-((cx - 50)^2 + (cy + 30)^2) / 4000)),
            ("Lot B", (cx, cy) -> 100 - 8exp(-((cx + 40)^2 + (cy - 60)^2) / 5000)),
            ("Lot C", (cx, cy) -> 100 + 5sin(cx / 35) * cos(cy / 35)),
            ("Lot D", (cx, cy) -> 100 + 6 * (cx^2 + cy^2) / 150^2)]

function lot_columns((name, pat))
    θ = rand(3000) .* 2π
    r = sqrt.(rand(3000)) .* 148.0
    x = @. r * cos(θ); y = @. r * sin(θ)
    return (x = x, y = y, value = pat.(x, y) .+ 1.5 .* randn(3000), lot = fill(name, 3000))
end

cols = lot_columns.(patterns)
table = (x = reduce(vcat, c.x for c in cols),
         y = reduce(vcat, c.y for c in cols),
         value = reduce(vcat, c.value for c in cols),
         lot = reduce(vcat, c.lot for c in cols))

wafer_facet(table, wafer; by = :lot, plot_type = :heatmap,
            colormap = :plasma, colorrange = (90.0, 112.0), ncols = 2)
```

---

## Faceted wafer grid with AlgebraOfGraphics

For a faceted scatter/heatmap coloured by value, [AlgebraOfGraphics.jl](https://aog.makie.org)
is a more natural fit: `mapping(…; layout = :lot)` builds the panel grid, titles, shared
colour scale and colorbar automatically. The only wafer-specific touch is overlaying the
boundary, added here as a second `Lines` layer repeated per lot. Reach for `wafer_facet`
(above) when you want the full wafer-map treatment per panel — exposure fields, KPI panels,
the optimized heatmap paths, and the notch without a manual layer.

```@example gallery_aog
using LithoWaferPlots, CairoMakie, AlgebraOfGraphics, DataFrames
wafer = WaferSpec(300.0)

lots = [("Lot A", (cx, cy) -> 100 + 8exp(-((cx - 50)^2 + (cy + 30)^2) / 4000)),
        ("Lot B", (cx, cy) -> 100 - 8exp(-((cx + 40)^2 + (cy - 60)^2) / 5000)),
        ("Lot C", (cx, cy) -> 100 + 5sin(cx / 35) * cos(cy / 35)),
        ("Lot D", (cx, cy) -> 100 + 6 * (cx^2 + cy^2) / 150^2)]
lot_table((name, pat)) = begin
    θ = rand(3000) .* 2π
    r = sqrt.(rand(3000)) .* 148.0
    x = @. r * cos(θ); y = @. r * sin(θ)
    (x = x, y = y, value = pat.(x, y) .+ 1.5 .* randn(3000), lot = fill(name, 3000))
end
cols = lot_table.(lots)
df = DataFrame(x = reduce(vcat, c.x for c in cols), y = reduce(vcat, c.y for c in cols),
               value = reduce(vcat, c.value for c in cols), lot = reduce(vcat, c.lot for c in cols))

# wafer outline repeated per lot so it draws in every facet
bpts = wafer_polygon(wafer)
lotnames = unique(df.lot)
edge = DataFrame(x = repeat(first.(bpts), outer = length(lotnames)),
                 y = repeat(last.(bpts), outer = length(lotnames)),
                 lot = repeat(lotnames, inner = length(bpts)))

plt = data(df) * mapping(:x, :y; color = :value => "Thickness (nm)", layout = :lot) *
      visual(Scatter; markersize = 2, colormap = :plasma)
ring = data(edge) * mapping(:x, :y; layout = :lot) * visual(Lines; color = :black)

draw(plt + ring; axis = (aspect = DataAspect(), width = 170, height = 170))
```

---

## CFD Combined: Divergence + Streamlines

The standard CFD summary view: ∇·**v** heatmap as background, streamlines overlaid in white.
`wafer_cfd_figure` handles the layout and prevents the wafer boundary from being drawn twice.

```@example gallery
θ = rand(30_000) .* 2π
r = sqrt.(rand(30_000)) .* 140.0
x = @. r * cos(θ); y = @. r * sin(θ)
src(cx, cy, a) = (w = @.(a * exp(-((x - cx)^2 + (y - cy)^2) / 2500));
                  (@.(w * (x - cx)), @.(w * (y - cy))))
vx1, vy1 = src(60.0, 40.0, 1.0)
vx2, vy2 = src(-50.0, -50.0, -1.0)
vdata = WaferVectorData((x = x, y = y, vx = vx1 .+ vx2, vy = vy1 .+ vy2), wafer)

fig, ax, side = wafer_cfd_figure(vdata; scalar = :divergence, vector = :streamlines,
    streamline_color = :white, streamline_linewidth = 1.5f0, n_seeds = 25)
fig
```

---

## CFD Combined: Vorticity + Streamlines

Rotation intensity as background with streamlines showing the flow direction simultaneously.

```@example gallery
θ = rand(30_000) .* 2π
r = sqrt.(rand(30_000)) .* 140.0
x = @. r * cos(θ); y = @. r * sin(θ)
speed = @. exp(-(x^2 + y^2) / 5000.0)
vdata = WaferVectorData((x = x, y = y, vx = -y .* speed ./ 40, vy = x .* speed ./ 40), wafer)

fig, ax, side = wafer_cfd_figure(vdata; scalar = :vorticity, vector = :streamlines,
    streamline_color = :white, streamline_linewidth = 1.5f0, n_seeds = 25)
fig
```

### Manual composition

For full control use `draw_boundary = false` on the overlay recipe:

```@example gallery
θ = rand(30_000) .* 2π
r = sqrt.(rand(30_000)) .* 140.0
x = @. r * cos(θ); y = @. r * sin(θ)
src(cx, cy, a) = (w = @.(a * exp(-((x - cx)^2 + (y - cy)^2) / 2500));
                  (@.(w * (x - cx)), @.(w * (y - cy))))
vx1, vy1 = src(60.0, 40.0, 1.0)
vx2, vy2 = src(-50.0, -50.0, -1.0)
vdata = WaferVectorData((x = x, y = y, vx = vx1 .+ vx2, vy = vy1 .+ vy2), wafer)

fig, ax, side = wafer_figure()
p = waferdivergence!(ax, vdata; colormap = :RdBu)
waferstreamlines!(ax, vdata; draw_boundary = false, draw_fields = false,
                  color = :white, n_seeds = 30)
add_colorbar!(side, p; label = "∇·v (a.u.)")
fig
```

The same `draw_boundary` and `draw_fields` keywords are available on every recipe, so any
combination (e.g. contour + scatter overlay) is possible without duplicate boundaries.
