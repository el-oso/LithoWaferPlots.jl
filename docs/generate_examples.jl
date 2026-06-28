"""
Generate the static example images used by pages **other than the gallery**
(getting_started.md, index.md).

    julia --project=docs docs/generate_examples.jl

The Gallery page renders its plots live via `@example` blocks (see docs/src/gallery.md),
so it needs no pre-generated assets. Only the handful below are committed as PNGs.
"""

using LithoWaferPlots
using CairoMakie
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

println("\nStatic images written to $OUT")
