# AlgebraOfGraphics

[AlgebraOfGraphics.jl](https://aog.makie.org) (AoG) is a grammar-of-graphics layer on top of
Makie. LithoWaferPlots doesn't depend on it, but the two compose well: [`wafer_facet`](@ref)
covers the *spatial* multi-panel case (several wafer maps side by side, sharing a colour
scale) with the full wafer-map treatment — exposure fields, KPI panels, the optimized heatmap
paths, and the notch. AoG covers *statistical* views next to those maps — bar/violin
comparisons, radial scatter, lot-over-lot summaries — that would otherwise need hand-rolled
axes. Use `draw!(fig[r, c], layer)` to drop an AoG panel into the same `Figure` as an ordinary
`waferheatmap!`/`waferarrows!` panel.

Every plot below is rendered live during the documentation build from the exact code shown
above it.

```@example aog
using LithoWaferPlots, CairoMakie, AlgebraOfGraphics, DataFrames
CairoMakie.activate!(type = "png")
wafer = WaferSpec(300.0)

function synth_lot(seed_offset, amp)
    θ = rand(2000) .* 2π
    r = sqrt.(rand(2000)) .* 140.0
    x = @. r * cos(θ); y = @. r * sin(θ)
    v = @. amp * exp(-((x - 40)^2 + (y + 20)^2) / 5000) + 0.3 * randn() + seed_offset
    vx = @. -y / 150 + x / 400
    vy = @. x / 150 + y / 400
    (x = x, y = y, v = v, vx = vx, vy = vy)
end
lots = [("Lot A", synth_lot(100.0, 8.0)), ("Lot B", synth_lot(96.0, 5.0)), ("Lot C", synth_lot(103.0, 10.0))]
nothing # hide
```

## Faceted wafer grid

For a faceted scatter/heatmap coloured by value, AoG is a more natural fit than several
separate `Figure`s: `mapping(…; layout = :lot)` builds the panel grid, titles, shared colour
scale and colorbar automatically. The only wafer-specific touch is overlaying the boundary,
added here as a second `Lines` layer repeated per lot. Reach for `wafer_facet` instead when you
want the full wafer-map treatment per panel.

```@example aog
df = DataFrame(
    x = reduce(vcat, l.x for (_, l) in lots), y = reduce(vcat, l.y for (_, l) in lots),
    value = reduce(vcat, l.v for (_, l) in lots),
    lot = reduce(vcat, fill(name, length(l.x)) for (name, l) in lots)
)

# wafer outline repeated per lot so it draws in every facet
bpts = wafer_polygon(wafer)
lotnames = unique(df.lot)
edge = DataFrame(
    x = repeat(first.(bpts), outer = length(lotnames)),
    y = repeat(last.(bpts), outer = length(lotnames)),
    lot = repeat(lotnames, inner = length(bpts))
)

plt = data(df) * mapping(:x, :y; color = :value => "Thickness (nm)", layout = :lot) *
      visual(Scatter; markersize = 2)
ring = data(edge) * mapping(:x, :y; layout = :lot) * visual(Lines; color = :black)

# colormap goes through `scales`, not `visual` — AoG resolves color scales globally across
# every layer in the plot, so `visual(Scatter; colormap=...)` is silently ignored.
draw(plt + ring, scales(Color = (; colormap = :plasma)); axis = (aspect = DataAspect(), width = 170, height = 170))
```

## Heatmap + arrows beside a KPI summary

A regular LithoWaferPlots panel (`waferheatmap!` + `waferarrows!` overlaid) placed via
`Axis`/`GridLayout` next to an AoG bar chart summarising a KPI across lots —
`draw!(fig[r, c], layer)` renders the AoG layer directly into that `GridLayout` slot rather
than creating its own `Figure`.

```@example aog
fig = Figure(size = (760, 380))

lotname1, lot1 = lots[1]
sdata = WaferData((x = lot1.x, y = lot1.y, value = lot1.v), wafer)
vdata = WaferVectorData((x = lot1.x, y = lot1.y, vx = lot1.vx, vy = lot1.vy), wafer)
ax = Axis(fig[1, 1]; aspect = DataAspect(), title = "$lotname1: thickness + flow")
waferheatmap!(ax, sdata; colormap = :plasma)
waferarrows!(ax, vdata; lengthscale = 10.0, arrowcolor = :black, draw_boundary = false, draw_fields = false)

kpidf = DataFrame(lot = String[], mean = Float64[])
for (name, l) in lots
    push!(kpidf, (name, compute(KPIMean(), l.v)))
end
kpi_layer = data(kpidf) * mapping(:lot, :mean) * visual(BarPlot)
draw!(fig[1, 2], kpi_layer; axis = (; ylabel = "Mean thickness (nm)", width = 220, height = 220))
fig
```

## Exclusion ring + radial distribution

[`add_exclusion_ring!`](@ref) marks the edge-exclusion boundary spatially; an AoG panel plotting
value against radius, coloured by whether each point falls inside or outside that ring, shows
the same cutoff statistically — useful for confirming an edge effect is actually confined to
the excluded annulus.

```@example aog
fig = Figure(size = (760, 380))

ax = Axis(fig[1, 1]; aspect = DataAspect(), title = "Edge exclusion")
waferheatmap!(ax, sdata; colormap = :viridis)
add_exclusion_ring!(ax, wafer; mm_to_edge = 15.0, label = "15 mm EE", dim_outside = true)
add_ring_legend!(ax)

r = hypot.(lot1.x, lot1.y)
zone = ifelse.(r .> (wafer.diameter_mm / 2 - 15.0), "excluded", "active")
raddf = DataFrame(r = r, value = lot1.v, zone = zone)
rad_layer = data(raddf) * mapping(:r, :value; color = :zone) * visual(Scatter; markersize = 3)
draw!(fig[1, 2], rad_layer; axis = (; xlabel = "radius (mm)", ylabel = "value", width = 220, height = 220))
fig
```

## KPI comparison across lots

A grouped bar chart comparing several [`AbstractKPI`](@ref)s at once across lots — the same
`compute`/`name` interface [`add_kpi_panel!`](@ref) uses internally, just fed to AoG instead of
a text panel. `draw` (not `draw!`) here since this chart isn't sharing a `Figure` with a wafer
panel; it builds its own figure and legend.

```@example aog
kpis = [KPIMean(), KPISigma(), KPIMax()]
long = DataFrame(lot = String[], kpi = String[], value = Float64[])
for (lotname, l) in lots, k in kpis
    push!(long, (lotname, name(k), compute(k, l.v)))
end

kpi_layer = data(long) * mapping(:kpi, :value; color = :lot, dodge = :lot) * visual(BarPlot)
draw(kpi_layer; axis = (; ylabel = "value"))
```

## Wafer recipes as AoG visuals: a six-wafer heatmap + arrows facet

Everything above composes AoG panels *next to* LithoWaferPlots panels. This section goes one
step further and drives the wafer recipes themselves **through the AoG interface** —
`data(df) * mapping(…) * visual(WaferHeatmap)` — so a whole lot of wafers gets the full
wafer-map treatment (interpolated heatmap, exposure fields, boundary + notch, arrow overlay)
with AoG handling faceting, the shared colour scale, and the colorbar.

Out of the box that errors: the recipes take a single pre-built `WaferData`/`WaferVectorData`
argument, while AoG feeds plot types raw positional columns. Three extension points bridge the
gap, and all three live *here in the example* — AoG stays a docs-only dependency, never a
package one:

1. `Makie.convert_arguments` (plus `Makie.used_attributes`) teaches the recipes to accept raw
   `x, y, value` / `x, y, vx, vy` columns, packing them into `WaferData`/`WaferVectorData`.
   The non-tabular parameters — the `WaferSpec` and the exposure-field list — ride along as
   `visual(…; wafer, fields)` attributes, which `used_attributes` reroutes into
   `convert_arguments`.
2. `AlgebraOfGraphics.aesthetic_mapping` declares what each positional argument *means*
   (x, y, colour value; x, y, Δx, Δy) so AoG can compute scales and facet limits.
3. An `AlgebraOfGraphics.to_entry` method mirroring AoG's own `to_entry(::Type{Heatmap}, …)`:
   without it, AoG bakes its continuous colour scale into an `RGBA` vector before the plot ever
   sees the data — useless to a recipe that needs raw values to interpolate. The specialization
   passes the value column through untouched and hands the *global* colour scale over as
   `colorrange`/`colormap` attributes instead, which `WaferHeatmap` honours in both render
   modes. `to_entry` and its helpers are AoG internals (not public API), so this method is
   pinned to the AoG version in `docs/Project.toml` — expect to revisit it on AoG upgrades.

```@example aog
const AoG = AlgebraOfGraphics
ext = Base.get_extension(LithoWaferPlots, :LithoWaferPlotsMakieExt)
WHeatmap = ext.WaferHeatmap
WArrows = ext.WaferArrows

Makie.used_attributes(::Type{<:WHeatmap}, ::AbstractVector, ::AbstractVector, ::AbstractVector) = (:wafer, :fields)
function Makie.convert_arguments(
        ::Type{<:WHeatmap}, x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, v::AbstractVector{<:Real};
        wafer = WaferSpec(), fields = WaferField[]
    )
    return (WaferData((x = collect(Float64, x), y = collect(Float64, y), value = collect(Float64, v)), wafer; fields = Vector{WaferField}(fields)),)
end

Makie.used_attributes(::Type{<:WArrows}, ::AbstractVector, ::AbstractVector, ::AbstractVector, ::AbstractVector) = (:wafer, :fields)
function Makie.convert_arguments(
        ::Type{<:WArrows}, x::AbstractVector{<:Real}, y::AbstractVector{<:Real},
        vx::AbstractVector{<:Real}, vy::AbstractVector{<:Real};
        wafer = WaferSpec(), fields = WaferField[]
    )
    return (WaferVectorData(collect(Float64, x), collect(Float64, y), collect(Float64, vx), collect(Float64, vy), wafer, Vector{WaferField}(fields)),)
end

function AoG.aesthetic_mapping(::Type{<:WHeatmap}, ::AoG.Normal, ::AoG.Normal, ::AoG.Normal)
    return AoG.dictionary([1 => AoG.AesX, 2 => AoG.AesY, 3 => AoG.AesColor])
end
function AoG.aesthetic_mapping(::Type{<:WArrows}, ::AoG.Normal, ::AoG.Normal, ::AoG.Normal, ::AoG.Normal)
    return AoG.dictionary([1 => AoG.AesX, 2 => AoG.AesY, 3 => AoG.AesDeltaX, 4 => AoG.AesDeltaY])
end

function AoG.to_entry(P::Type{<:WHeatmap}, p::AoG.ProcessedLayer, categoricalscales::AoG.Dictionary, continuousscales::AoG.Dictionary)
    aes_mapping = AoG.aesthetic_mapping(p)
    scale_mapping = p.scale_mapping
    vals, scale = AoG.numerical_rescale(p.positional[3], 3, aes_mapping, scale_mapping, categoricalscales, continuousscales)
    scale isa AoG.ContinuousScale || error("WaferHeatmap needs a continuous value column")
    color_attributes = AoG.dictionary(
        [
            :colormap => @something(scale.props.aesprops.colormap, AoG.default_colormap()),
            :colorrange => AoG.nonsingular_colorrange(scale),
        ]
    )
    positional = Any[
        AoG.full_rescale(p.positional[1], 1, aes_mapping, scale_mapping, categoricalscales, continuousscales),
        AoG.full_rescale(p.positional[2], 2, aes_mapping, scale_mapping, categoricalscales, continuousscales),
        vals,
    ]
    return AoG.Entry(P, positional, merge(p.named, p.primary, p.attributes, color_attributes))
end
nothing # hide
```

With the bridge in place, generating the data is the only non-AoG code left. Six wafers with
50 000 measurement sites each: a film-thickness value (radial bowl + noise) and an overlay
displacement vector (rotation + expansion, a few nm) per site. Wafer 4 carries a large local
excursion — on the *shared* colour scale it is the one panel that lights up, which is exactly
what a per-panel colour scale would have hidden.

```@example aog
fw, fh = 26.0, 33.0
centers = [((c - 0.5) * fw, (rw - 5) * fh) for rw in 1:9, c in -5:6]
fields = field_grid(centers, (fw, fh); wafer = wafer)

function synth_wafer(wid; outlier = false)
    n = 50_000
    θ = rand(n) .* 2π
    rr = sqrt.(rand(n)) .* 147.0
    x = @. rr * cos(θ)
    y = @. rr * sin(θ)
    v = @. 100.0 + 2.5e-4 * (x^2 + y^2) + 0.3 * randn()           # radial bowl, nm
    if outlier
        v .+= @. 10.0 * exp(-((x + 60)^2 + (y - 50)^2) / 1200)    # large local excursion
    end
    vx = @. -y * 0.03 + x * 0.012 + 0.2 * randn()                 # rotation + expansion, nm
    vy = @. x * 0.03 + y * 0.012 + 0.2 * randn()
    return DataFrame(x = x, y = y, value = v, vx = vx, vy = vy, wafer_id = fill(wid, n))
end
df = reduce(vcat, [synth_wafer("Wafer $i"; outlier = i == 4) for i in 1:6])

# one reference arrow + label per facet: a 5 nm magnitude yardstick
refdf = DataFrame(
    x = fill(-145.0, 6), y = fill(-145.0, 6),
    vx = fill(5.0, 6), vy = fill(0.0, 6),
    lbl = fill("5 nm", 6), wafer_id = unique(df.wafer_id)
)
nothing # hide
```

The plot itself is pure AoG algebra — four layers added together, faceted by `layout =
:wafer_id`. Each wafer's 50 000 arrows are all in the layer's data; the recipe's own
`max_arrows`/`arrow_sample` attributes subsample to 700 random arrows per panel for legibility
(all 300 000 would blanket the heatmaps solid black — the same density lesson as the gallery's
divergence/vorticity overlays), and that stays a `visual(…)` attribute, not a data-side hack.
The reference arrow rides through the same `WaferArrows` visual with the same `lengthscale`,
so its drawn length is guaranteed to be an honest 5 nm yardstick.

```@example aog
heat = data(df) * mapping(:x, :y, :value => "Overlay (nm)"; layout = :wafer_id) *
    visual(WHeatmap; wafer = wafer, fields = fields)
arrows = data(df) * mapping(:x, :y, :vx, :vy; layout = :wafer_id) *
    visual(
    WArrows; wafer = wafer, lengthscale = 6.0, max_arrows = 700,
    arrow_sample = :random, linewidth = 0.5, arrowcolor = :magnitude, colormap = :plasma,
    draw_boundary = false, draw_fields = false
)
refarrow = data(refdf) * mapping(:x, :y, :vx, :vy; layout = :wafer_id) *
    visual(
    WArrows; wafer = wafer, lengthscale = 6.0, linewidth = 1.5,
    arrowcolor = :firebrick, draw_boundary = false, draw_fields = false
)
reflabel = data(refdf) * mapping(:x, :y; text = :lbl => verbatim, layout = :wafer_id) *
    visual(Makie.Text; color = :firebrick, fontsize = 11, align = (:left, :bottom), offset = (0, 4))

t_build = @elapsed fg = draw(
    heat + arrows + refarrow + reflabel,
    scales(Color = (; colormap = :plasma));
    axis = (aspect = DataAspect(), width = 230, height = 230)
)
t_render = @elapsed Makie.colorbuffer(fg.figure)
println("draw (figure build): $(round(t_build; digits = 2)) s, render: $(round(t_render; digits = 2)) s")
fg
```

The `println` reports the timing when this runs as a script; the rendered page shows it here
(`draw` builds the figure — including six 50 000-point IDW interpolations — and `colorbuffer`
rasterizes it; the first `draw` in a fresh session also pays Julia's one-off compile tax):

```@example aog
"draw (figure build): $(round(t_build; digits = 2)) s, render: $(round(t_render; digits = 2)) s"
```
