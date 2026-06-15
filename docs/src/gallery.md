# Gallery

Every plot below is **rendered live during the documentation build from the exact code
shown above it** — the code and the image can never drift apart. All plots use CairoMakie;
swap in `GLMakie` for interactive desktop windows or `WGLMakie` for Jupyter/Pluto notebooks.

```@example gallery
using LithoWaferPlots, CairoMakie
CairoMakie.activate!(type = "png")
wafer = WaferSpec(300.0)
```

The examples draw on a handful of synthetic-data helpers (hidden for brevity; they build
`WaferData` / `WaferVectorData` from analytic patterns):

```@setup gallery
# Sparse scattered measurements with a two-bump non-uniformity.
function scalar_data(n = 8_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 148.0
    x = r .* cos.(θ); y = r .* sin.(θ)
    v = 2.5 .* exp.(-(((x .- 60) .^ 2 .+ (y .+ 40) .^ 2) ./ 4000)) .+
        1.8 .* exp.(-(((x .+ 50) .^ 2 .+ (y .- 70) .^ 2) ./ 3000)) .+ 0.15 .* randn(n)
    return WaferData((x = x, y = y, value = v), wafer)
end

# Regular grid (no gaps when markersize matches spacing).
function dense_scalar_data(step_mm = 3.0)
    xs = collect(-148.0:step_mm:148.0); ys = collect(-148.0:step_mm:148.0)
    pts = [(x, y) for x in xs, y in ys if x^2 + y^2 <= 148.0^2]
    x = first.(pts); y = last.(pts)
    v = sin.(x ./ 40) .* cos.(y ./ 40) .+ 0.5 .* exp.(-(x .^ 2 .+ y .^ 2) ./ 8000) .+
        0.08 .* randn(length(x))
    return WaferData((x = x, y = y, value = v), wafer)
end

# Vortex + small outward radial component.
function vector_data(n = 6_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 130.0
    x = r .* cos.(θ); y = r .* sin.(θ)
    vx = -y ./ 80 .+ x ./ 300 .+ 0.03 .* randn(n)
    vy = x ./ 80 .+ y ./ 300 .+ 0.03 .* randn(n)
    return WaferVectorData((x = x, y = y, vx = vx, vy = vy), wafer)
end

# Two Gaussian sources → large ±divergence at the source centres.
function divergence_data(n = 50_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 140.0
    x = r .* cos.(θ); y = r .* sin.(θ)
    σ² = 2500.0
    gauss_flow(x, y, cx, cy, amp) = begin
        dx, dy = x .- cx, y .- cy
        w = amp .* exp.(-(dx .^ 2 .+ dy .^ 2) ./ σ²)
        return w .* dx, w .* dy
    end
    vx1, vy1 = gauss_flow(x, y, 60.0, 40.0, 1.0)
    vx2, vy2 = gauss_flow(x, y, -50.0, -50.0, -1.0)
    vx = vx1 .+ vx2 .+ 0.02 .* randn(n)
    vy = vy1 .+ vy2 .+ 0.02 .* randn(n)
    return WaferVectorData((x = x, y = y, vx = vx, vy = vy), wafer)
end

# Differential rotation → vorticity large at the centre, decaying outward.
function vorticity_data(n = 50_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 140.0
    x = r .* cos.(θ); y = r .* sin.(θ)
    speed = exp.(-(x .^ 2 .+ y .^ 2) ./ 5000.0)
    vx = -y .* speed ./ 40 .+ 0.01 .* randn(n)
    vy = x .* speed ./ 40 .+ 0.01 .* randn(n)
    return WaferVectorData((x = x, y = y, vx = vx, vy = vy), wafer)
end

# Exposure-field grid, keeping fields that overlap the wafer disk.
function example_fields()
    fw, fh = 26.0, 33.0
    r = wafer.diameter_mm / 2.0
    all_fields = vec([WaferField((ci - 0.5) * fw, (ri - 5) * fh, fw, fh, ci, ri)
                      for ri in 1:9, ci in -5:6])
    return filter(all_fields) do f
        nx = clamp(0.0, f.x_center_mm - fw / 2, f.x_center_mm + fw / 2)
        ny = clamp(0.0, f.y_center_mm - fh / 2, f.y_center_mm + fh / 2)
        nx^2 + ny^2 <= r^2
    end
end

# Per-die yield (3×3 dies per field), radially decaying + noise.
function yield_data()
    fw, fh = 26.0, 33.0
    r_wafer = wafer.diameter_mm / 2.0
    fields = example_fields()
    die_w, die_h = fw / 3.0, fh / 3.0
    x = Float64[]; y = Float64[]; v = Float64[]
    for f in fields, di in 0:2, dj in 0:2
        cx = f.x_center_mm - fw / 2.0 + (di + 0.5) * die_w
        cy = f.y_center_mm - fh / 2.0 + (dj + 0.5) * die_h
        base = clamp(1.0 - (cx^2 + cy^2) / (0.85 * r_wafer^2), 0.0, 1.0)
        push!(x, cx); push!(y, cy); push!(v, clamp(base + 0.12 * randn(), 0.0, 1.0))
    end
    return WaferData((x = x, y = y, value = v), wafer; fields = fields)
end

# Four simulated lots with different spatial patterns (a Tables.jl column table).
function facet_table()
    lots = ["Lot A", "Lot B", "Lot C", "Lot D"]
    n = 3_000
    xs = Float64[]; ys = Float64[]; vs = Float64[]; ids = String[]
    patterns = [
        (cx, cy) -> 100.0 + 8.0 * exp(-((cx - 50)^2 + (cy + 30)^2) / 4000) + 1.5 * randn(),
        (cx, cy) -> 100.0 - 8.0 * exp(-((cx + 40)^2 + (cy - 60)^2) / 5000) + 1.5 * randn(),
        (cx, cy) -> 100.0 + 5.0 * sin(cx / 35) * cos(cy / 35) + 1.5 * randn(),
        (cx, cy) -> 100.0 + 6.0 * (cx^2 + cy^2) / (150^2) + 1.5 * randn(),
    ]
    for (lot, pat) in zip(lots, patterns)
        θ = rand(n) .* 2π; r = sqrt.(rand(n)) .* 148.0
        x = r .* cos.(θ); y = r .* sin.(θ)
        append!(xs, x); append!(ys, y); append!(vs, pat.(x, y)); append!(ids, fill(lot, n))
    end
    return (x = xs, y = ys, value = vs, lot = ids)
end

# Synthetic RGBA "logo": a brand-coloured ring with a notch and a filled centre dot.
function brand_logo(n = 160)
    img = fill(RGBAf(0, 0, 0, 0), n, n)
    for i in 1:n, j in 1:n
        x = (i - 0.5) / n - 0.5; y = (j - 0.5) / n - 0.5
        r = sqrt(x^2 + y^2); θ = atan(y, x)
        0.30 <= r <= 0.46 && (img[i, j] = RGBAf(0.10, 0.45, 0.80, 0.95))
        (r >= 0.28 && abs(θ + π / 2) < 0.22) && (img[i, j] = RGBAf(0, 0, 0, 0))
        r <= 0.12 && (img[i, j] = RGBAf(0.95, 0.55, 0.05, 1.0))
    end
    return img
end
```

## Scatter

Sparse measurement points coloured by value. Good for raw probe data where point density is uneven.

```@example gallery
data = scalar_data()
fig, ax, side = wafer_figure()
p = waferscatter!(ax, data; markersize = 4.0f0)
add_colorbar!(side, p; label = "Overlay (a.u.)")
add_kpi_panel!(side, data)
fig
```

---

## Heatmap

Dense rectangular markers produce a filled colour map. For datasets with more than 5 000 points the recipe automatically switches to an `image!` GPU texture path for faster rendering. `percentile_clip` removes colour-scale distortion from outliers. Override the automatic path with `imagemode = :scatter` or `:image`.

```@example gallery
data = dense_scalar_data()
fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :plasma)
add_colorbar!(side, p; label = "Thickness (nm)")
add_kpi_panel!(side, data)
fig
```

---

## Heatmap with field overlay

Pass a `fields` vector to `WaferData` to overlay exposure-field or die boundaries on any plot type. Fields may extend beyond the wafer edge.

```@example gallery
sdata = dense_scalar_data()
data = WaferData((x = sdata.x, y = sdata.y, value = sdata.values), wafer;
                 fields = example_fields())
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

Scattered data is interpolated to a regular grid via IDW before contouring. Adjust `grid_n` (default 256) and `levels` as needed.

```@example gallery
data = dense_scalar_data(5.0)
fig, ax, side = wafer_figure()
p = wafercontour!(ax, data; levels = 12, colormap = :viridis)
add_colorbar!(side, p; label = "Overlay (a.u.)")
fig
```

---

## Arrows

Arrow plot of a vector field. Subsampled to `max_arrows` (default 4 000) for legibility, and drawn as a single batched `lines!` call (shaft plus a V arrowhead) for low memory use. Scale arrows with `lengthscale`; tune the head with `head_frac` and `head_angle`.

```@example gallery
vdata = vector_data(600)
fig, ax, side = wafer_figure()
waferarrows!(ax, vdata; lengthscale = 8.0, arrowcolor = :steelblue)
fig
```

---

## Streamlines

RK4-traced stream lines from a uniform seed grid. The velocity field is interpolated once to a `grid_n × grid_n` grid and sampled bilinearly during integration, so tracing is fast even for large datasets. Controls: `n_seeds`, `max_steps`, `step_size`, and `grid_n`.

```@example gallery
vdata = vector_data(15_000)
fig, ax, side = wafer_figure()
waferstreamlines!(ax, vdata; n_seeds = 12, max_steps = 80,
                  color = :navy, linewidth = 1.2f0)
fig
```

---

## Divergence

∇·**v** = ∂vx/∂x + ∂vy/∂y, computed by IDW interpolation to a regular grid then central finite differences. A diverging colormap (`:RdBu`) centres the colour scale on zero.

```@example gallery
vdata = divergence_data()
fig, ax, side = wafer_figure()
p = waferdivergence!(ax, vdata; colormap = :RdBu, markersize = 3.0f0)
add_colorbar!(side, p; label = "Divergence (a.u.)")
fig
```

---

## Vorticity

∇×**v** = ∂vy/∂x − ∂vx/∂y. Positive values (red) indicate counterclockwise rotation; negative (blue) indicate clockwise.

```@example gallery
vdata = vorticity_data()
fig, ax, side = wafer_figure()
p = wafervorticity!(ax, vdata; markersize = 3.0f0)
add_colorbar!(side, p; label = "Vorticity (a.u.)")
fig
```

---

## Die-level yield map

Per-die yield across ~100 exposure fields (3×3 = 9 dies each). Field boundaries are
overlaid as thin gray strokes. The 2 mm edge-exclusion ring dims the outer annulus
where yield data is typically not trusted.

```@example gallery
ydata = yield_data()
fig, ax, side = wafer_figure()
p = waferheatmap!(ax, ydata; markersize = 14.0f0, colormap = :RdYlGn,
                  field_color = (:black, 0.0),
                  field_strokecolor = :gray50, field_strokewidth = 0.7f0)
add_colorbar!(side, p; label = "Yield")
add_kpi_panel!(side, ydata)
add_exclusion_ring!(ax, wafer; mm_to_edge = 2.0, label = "2 mm EE",
                    color = :black, linestyle = :dash, dim_outside = true, dim_alpha = 0.4)
add_ring_legend!(ax; position = :lb)
fig
```

---

## Exclusion ring annotation

Draw dashed/dotted radial exclusion rings on any plot, specified as **mm to the edge**
(the natural fab unit). Optionally dim the region outside the ring with a semi-transparent
overlay that works with every recipe type including image-mode heatmaps and CFD plots.

```@example gallery
data = dense_scalar_data()
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
Per-pixel alpha is honoured and a global `opacity` multiplier is applied on top, so
transparent regions of the image let the plot show through. The image can be a **file path**
(PNG with alpha, etc.) or an **`AbstractMatrix` of colors**; target either the wafer `Axis`
or the whole `Figure`. `position` accepts `:lt :ct :rt :lc :center :rc :lb :cb :rb` or an
`(fx, fy)` tuple (image centre in `0..1` of the target).

```@example gallery
logo = brand_logo()        # an RGBA matrix; a "company_logo.png" path works too
data = dense_scalar_data()
fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :viridis)
add_colorbar!(side, p; label = "Thickness (nm)")
add_watermark!(ax, logo; opacity = 0.12, scale = 0.7)   # faded, centred
add_logo!(ax, logo; position = :rt, scale = 0.16)        # opaque, top-right
fig
```

---

## Faceted wafer grid

`wafer_facet` groups any Tables.jl-compatible source by a column and renders one wafer
panel per group. Pass `colorrange = (lo, hi)` for a shared colorscale (single colorbar
below the grid); omit it for independent per-panel scaling. Works with any `plot_type`:
`:heatmap` (default), `:scatter`, or `:contour`.

```@example gallery
table = facet_table()   # columns: x, y, value, lot
wafer_facet(table, wafer; by = :lot, plot_type = :heatmap,
            colormap = :plasma, colorrange = (90.0, 112.0), ncols = 2)
```

---

## CFD Combined: Divergence + Streamlines

The standard CFD summary view: ∇·**v** heatmap as background, streamlines overlaid in white.
`wafer_cfd_figure` handles the layout and prevents the wafer boundary from being drawn twice.

```@example gallery
vdata = divergence_data()
fig, ax, side = wafer_cfd_figure(vdata; scalar = :divergence, vector = :streamlines,
    streamline_color = :white, streamline_linewidth = 1.5f0, n_seeds = 25)
fig
```

---

## CFD Combined: Vorticity + Streamlines

Rotation intensity as background with streamlines showing the flow direction simultaneously.

```@example gallery
vdata = vorticity_data()
fig, ax, side = wafer_cfd_figure(vdata; scalar = :vorticity, vector = :streamlines,
    streamline_color = :white, streamline_linewidth = 1.5f0, n_seeds = 25)
fig
```

### Manual composition

For full control use `draw_boundary = false` on the overlay recipe:

```@example gallery
vdata = divergence_data()
fig, ax, side = wafer_figure()
p = waferdivergence!(ax, vdata; colormap = :RdBu)
waferstreamlines!(ax, vdata; draw_boundary = false, draw_fields = false,
                  color = :white, n_seeds = 30)
add_colorbar!(side, p; label = "∇·v (a.u.)")
fig
```

The same `draw_boundary` and `draw_fields` keywords are available on every recipe,
so any combination (e.g. contour + scatter overlay) is possible without duplicate boundaries.
