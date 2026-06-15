"""
Generate the static example images used by pages **other than the gallery**
(getting_started.md, index.md, aog_compositing.md).

    julia --project=docs docs/generate_examples.jl

The Gallery page renders its plots live via `@example` blocks (see docs/src/gallery.md),
so it needs no pre-generated assets. Only the handful below are committed as PNGs.
"""

using LithoWaferPlots
using CairoMakie
using AlgebraOfGraphics
using DataFrames
using Random: seed!

seed!(42)

const OUT = joinpath(@__DIR__, "src", "assets")
mkpath(OUT)

const WAFER = WaferSpec(300.0)
const RESOLUTION = (800, 580)

# ── shared data ────────────────────────────────────────────────────────────────

function dense_scalar_data(step_mm = 3.0)
    xs = range(-148.0, 148.0; step = step_mm)
    ys = range(-148.0, 148.0; step = step_mm)
    pts = [(x, y) for x in xs, y in ys if x^2 + y^2 <= 148.0^2]
    x = first.(pts)
    y = last.(pts)
    v = @. sin(x / 40) * cos(y / 40) + 0.5 * exp(-(x^2 + y^2) / 8000) + 0.08 * $(randn(length(x)))
    return WaferData((x = x, y = y, value = v), WAFER)
end

function vector_data(n = 6_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 130.0
    x = @. r * cos(θ)
    y = @. r * sin(θ)
    vx = @. -y / 80 + x / 300 + 0.03 * $(randn(n))
    vy = @. x / 80 + y / 300 + 0.03 * $(randn(n))
    return WaferVectorData((x = x, y = y, vx = vx, vy = vy), WAFER)
end

function example_fields()
    fw, fh = 26.0, 33.0
    centers = [((ci - 0.5) * fw, (ri - 5) * fh) for ri in 1:9, ci in -5:6]
    return field_grid(centers, (fw, fh); wafer = WAFER)
end

# ── Heatmap (getting_started) ──────────────────────────────────────────────────

let sdata = dense_scalar_data()
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferheatmap!(ax, sdata; markersize = 6.0f0, colormap = :plasma)
    add_colorbar!(side, p; label = "Thickness (nm)")
    add_kpi_panel!(side, sdata)
    save(joinpath(OUT, "example_heatmap.png"), fig; px_per_unit = 2)
    println("heatmap done")
end

# ── Heatmap with field overlay (getting_started, index) ───────────────────────

let
    sdata = dense_scalar_data()
    sdata_with_fields = WaferData(
        (x = sdata.x, y = sdata.y, value = sdata.values), WAFER; fields = example_fields()
    )
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferheatmap!(
        ax, sdata_with_fields; markersize = 6.0f0, colormap = :plasma,
        field_color = (:black, 0.0),
        field_strokecolor = :black, field_strokewidth = 1.8f0
    )
    add_colorbar!(side, p; label = "Thickness (nm)")
    add_kpi_panel!(side, sdata_with_fields)
    save(joinpath(OUT, "example_heatmap_fields.png"), fig; px_per_unit = 2)
    println("heatmap+fields done")
end

# ── Arrows (getting_started) ──────────────────────────────────────────────────

let vdata = vector_data(600)
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    waferarrows!(ax, vdata; lengthscale = 8.0, arrowcolor = :steelblue)
    save(joinpath(OUT, "example_arrows.png"), fig; px_per_unit = 2)
    println("arrows done")
end

# ── Streamlines (getting_started) ─────────────────────────────────────────────

let vdata = vector_data(15_000)
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    waferstreamlines!(
        ax, vdata; n_seeds = 12, max_steps = 80,
        color = :navy, linewidth = 1.2f0
    )
    save(joinpath(OUT, "example_streamlines.png"), fig; px_per_unit = 2)
    println("streamlines done")
end

# ── AlgebraOfGraphics compositing (aog_compositing) ───────────────────────────

let
    n = 6_000
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 148.0
    x = @. r * cos(θ)
    y = @. r * sin(θ)
    thickness = @. 100.0 + 12.0 * exp(-r^2 / 7000) + 2.5 * $(randn(n))
    zone = @. ifelse(r < 50, "Center", ifelse(r < 110, "Middle", "Edge"))

    wdata = WaferData((x = x, y = y, value = thickness), WAFER)
    df = DataFrame(r = r, thickness = thickness, zone = zone)

    fig = Figure(size = (1050, 480))
    gl = fig[1, 1] = GridLayout()
    ax = Axis(
        gl[1, 1];
        aspect = DataAspect(),
        title = "Thickness map",
        xgridvisible = false, ygridvisible = false,
        topspinevisible = false, rightspinevisible = false,
        xlabel = "x (mm)", ylabel = "y (mm)",
    )
    p = waferheatmap!(ax, wdata; colormap = :plasma)
    cb_side = gl[1, 2] = GridLayout()
    add_colorbar!(cb_side, p; label = "Thickness (nm)")
    colsize!(gl, 2, Relative(0.2))
    colsize!(fig.layout, 1, Relative(0.52))

    zone_ord = sorter("Center", "Middle", "Edge")
    aog_plt = data(df) *
        mapping(
        :r => "Radius (mm)",
        :thickness => "Thickness (nm)";
        color = :zone => zone_ord => "Zone",
    ) *
        visual(Scatter; markersize = 3, alpha = 0.3f0)
    draw!(fig[1, 2], aog_plt; axis = (title = "Radial profile by zone",))

    save(joinpath(OUT, "example_aog.png"), fig; px_per_unit = 2)
    println("aog compositing done")
end

println("\nStatic images written to $OUT")
