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
      visual(Scatter; markersize = 2, colormap = :plasma)
ring = data(edge) * mapping(:x, :y; layout = :lot) * visual(Lines; color = :black)

draw(plt + ring; axis = (aspect = DataAspect(), width = 170, height = 170))
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
