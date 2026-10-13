"""
Generate the static example images used by pages **other than the gallery**
(README.md, getting_started.md, index.md). Every image draws the exposure-field grid
in the default field style.

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

const WAFER = WaferSpec()
const RESOLUTION = (800, 580)

# ── shared data ────────────────────────────────────────────────────────────────

function example_fields()
    fw, fh = 26.0, 33.0
    centers = [((ci - 0.5) * fw, (ri - 5) * fh) for ri in 1:9, ci in -5:6]
    return field_grid(centers, (fw, fh); wafer = WAFER)
end

const FIELDS = example_fields()

function dense_scalar_data(step_mm = 3.0)
    xs = range(-148.0, 148.0; step = step_mm)
    ys = range(-148.0, 148.0; step = step_mm)
    pts = [(x, y) for x in xs, y in ys if x^2 + y^2 <= 148.0^2]
    x = first.(pts)
    y = last.(pts)
    v = @. sin(x / 40) * cos(y / 40) + 0.5 * exp(-(x^2 + y^2) / 8000) + 0.08 * $(randn(length(x)))
    return WaferData(x, y, v; fields = FIELDS)
end

function vector_data(n = 6_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 130.0
    x = @. r * cos(θ)
    y = @. r * sin(θ)
    vx = @. -y / 80 + x / 300 + 0.03 * $(randn(n))
    vy = @. x / 80 + y / 300 + 0.03 * $(randn(n))
    return WaferVectorData(x, y, vx, vy; fields = FIELDS)
end

# Noise-free source/sink pair on the x axis and counter-rotating vortex pair on the
# y axis, sampled out to the wafer edge: finite differences amplify measurement noise,
# so divergence/vorticity need a smooth field.
function smooth_vector_data(n = 15_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 148.0
    x = @. r * cos(θ)
    y = @. r * sin(θ)
    g1 = @. exp(-((x - 60)^2 + y^2) / 2500)
    g2 = @. exp(-((x + 60)^2 + y^2) / 2500)
    g3 = @. exp(-(x^2 + (y - 60)^2) / 2500)
    g4 = @. exp(-(x^2 + (y + 60)^2) / 2500)
    vx = @. ((x - 60) * g1 - (x + 60) * g2 - (y - 60) * g3 + (y + 60) * g4) / 50
    vy = @. (y * g1 - y * g2 + x * g3 - x * g4) / 50
    return WaferVectorData(x, y, vx, vy; fields = FIELDS)
end

function save_example(name, fig)
    save(joinpath(OUT, "example_$name.png"), fig; px_per_unit = 2)
    println("$name done")
    return nothing
end

# ── scalar plots ───────────────────────────────────────────────────────────────

let sdata = dense_scalar_data()
    fig, = wafer_figure(sdata; label = "Thickness (nm)", resolution = RESOLUTION, colormap = :plasma)
    save_example("heatmap", fig)

    fig, = wafer_figure(
        sdata; plot_type = :scatter, label = "Thickness (nm)", resolution = RESOLUTION,
        markersize = 4.0f0, colormap = :plasma
    )
    save_example("scatter", fig)

    fig, = wafer_figure(
        sdata; plot_type = :contour, label = "Thickness (nm)", kpis = nothing,
        resolution = RESOLUTION, levels = 12, colormap = :viridis
    )
    save_example("contour", fig)
end

# ── vector plots ───────────────────────────────────────────────────────────────

let vdata = vector_data(600)
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    waferarrows!(ax, vdata; lengthscale = 8.0, arrowcolor = :steelblue)
    save_example("arrows", fig)
end

let vdata = vector_data(15_000)
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    waferstreamlines!(ax, vdata; n_seeds = 12, max_steps = 80, color = :navy, linewidth = 1.2f0)
    save_example("streamlines", fig)

    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferdivergence!(ax, smooth_vector_data(); colormap = :RdBu)
    add_colorbar!(side, p; label = "Divergence (a.u.)")
    save_example("divergence", fig)

    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = wafervorticity!(ax, smooth_vector_data())
    add_colorbar!(side, p; label = "Vorticity (a.u.)")
    save_example("vorticity", fig)
end

println("\nStatic images written to $OUT")
