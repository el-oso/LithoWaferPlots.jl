"""
Generate documentation example images.

    julia --project=docs docs/generate_examples.jl
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

function scalar_data(n=8_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 148.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    # two-bump pattern — looks like a real process non-uniformity
    v = 2.5 .* exp.(-(((x .- 60).^2 .+ (y .+ 40).^2) ./ 4000)) .+
        1.8 .* exp.(-(((x .+ 50).^2 .+ (y .- 70).^2) ./ 3000)) .+
        0.15 .* randn(n)
    return WaferData((x=x, y=y, value=v), WAFER)
end

function dense_scalar_data(n=40_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 148.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    v = sin.(x ./ 40) .* cos.(y ./ 40) .+ 0.5 .* exp.(-(x.^2 .+ y.^2) ./ 8000) .+
        0.08 .* randn(n)
    return WaferData((x=x, y=y, value=v), WAFER)
end

function vector_data(n=6_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 130.0
    x  =  r .* cos.(θ)
    y  =  r .* sin.(θ)
    # vortex + small outward radial component
    vx = -y ./ 80 .+ x ./ 300 .+ 0.03 .* randn(n)
    vy =  x ./ 80 .+ y ./ 300 .+ 0.03 .* randn(n)
    return WaferVectorData((x=x, y=y, vx=vx, vy=vy), WAFER)
end

# Divergence example: two Gaussian sources at different wafer locations.
# ∇·v is large (+) at the source centres and large (−) between them.
function divergence_data(n=50_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 140.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    σ² = 2500.0
    # source at (+60, +40), sink at (−50, −50)
    function gauss_flow(x, y, cx, cy, amp)
        dx, dy = x .- cx, y .- cy
        d² = dx.^2 .+ dy.^2
        w  = amp .* exp.(-d² ./ σ²)
        return w .* dx, w .* dy
    end
    vx1, vy1 = gauss_flow(x, y,  60.0,  40.0,  1.0)
    vx2, vy2 = gauss_flow(x, y, -50.0, -50.0, -1.0)
    noise = 0.02
    vx = vx1 .+ vx2 .+ noise .* randn(n)
    vy = vy1 .+ vy2 .+ noise .* randn(n)
    return WaferVectorData((x=x, y=y, vx=vx, vy=vy), WAFER)
end

# Vorticity example: differential rotation — fast at centre, slow at edge.
# ω = ∂vy/∂x − ∂vx/∂y is large at centre, falls off outward.
function vorticity_data(n=50_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 140.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    σ² = 5000.0
    speed = exp.(-(x.^2 .+ y.^2) ./ σ²)   # fast core, slow rim
    vx = -y .* speed ./ 40 .+ 0.01 .* randn(n)
    vy =  x .* speed ./ 40 .+ 0.01 .* randn(n)
    return WaferVectorData((x=x, y=y, vx=vx, vy=vy), WAFER)
end

# ── fields overlay ─────────────────────────────────────────────────────────────

function example_fields()
    return [WaferField(cx, cy, 26.0, 33.0, ci, ri)
            for (ri, cy) in zip(-1:1, [-33.0, 0.0, 33.0])
            for (ci, cx) in zip(-1:1, [-26.0, 0.0, 26.0])]
end

# ── 1. WaferScatter ────────────────────────────────────────────────────────────

let sdata = scalar_data()
    fig, ax, side = wafer_figure(; resolution=RESOLUTION)
    p = waferscatter!(ax, sdata; markersize=4f0)
    add_colorbar!(side, p; label="Overlay (a.u.)")
    add_kpi_panel!(side, sdata)
    save(joinpath(OUT, "example_scatter.png"), fig; px_per_unit=2)
    println("scatter done")
end

# ── 2. WaferHeatmap ───────────────────────────────────────────────────────────

let sdata = dense_scalar_data()
    fig, ax, side = wafer_figure(; resolution=RESOLUTION)
    p = waferheatmap!(ax, sdata; markersize=3f0, colormap=:plasma)
    add_colorbar!(side, p; label="Thickness (nm)")
    add_kpi_panel!(side, sdata)
    save(joinpath(OUT, "example_heatmap.png"), fig; px_per_unit=2)
    println("heatmap done")
end

# ── 3. WaferContour ───────────────────────────────────────────────────────────

let sdata = dense_scalar_data(20_000)
    fig, ax, side = wafer_figure(; resolution=RESOLUTION)
    p = wafercontour!(ax, sdata; levels=12, colormap=:viridis)
    add_colorbar!(side, p; label="Overlay (a.u.)")
    save(joinpath(OUT, "example_contour.png"), fig; px_per_unit=2)
    println("contour done")
end

# ── 4. WaferArrows ────────────────────────────────────────────────────────────
# Use fewer, well-spaced seed points so individual arrows are legible.

let vdata = vector_data(600)
    fig, ax, side = wafer_figure(; resolution=RESOLUTION)
    p = waferarrows!(ax, vdata; lengthscale=8.0, arrowcolor=:steelblue)
    save(joinpath(OUT, "example_arrows.png"), fig; px_per_unit=2)
    println("arrows done")
end

# ── 5. WaferStreamlines ───────────────────────────────────────────────────────

let vdata = vector_data(15_000)
    fig, ax, side = wafer_figure(; resolution=RESOLUTION)
    p = waferstreamlines!(ax, vdata; n_seeds=12, max_steps=80,
                          color=:navy, linewidth=1.2f0)
    save(joinpath(OUT, "example_streamlines.png"), fig; px_per_unit=2)
    println("streamlines done")
end

# ── 6. WaferDivergence ────────────────────────────────────────────────────────

let vdata = divergence_data()
    fig, ax, side = wafer_figure(; resolution=RESOLUTION)
    p = waferdivergence!(ax, vdata; colormap=:RdBu, markersize=3f0)
    add_colorbar!(side, p; label="Divergence (a.u.)")
    save(joinpath(OUT, "example_divergence.png"), fig; px_per_unit=2)
    println("divergence done")
end

# ── 7. WaferVorticity ─────────────────────────────────────────────────────────

let vdata = vorticity_data()
    fig, ax, side = wafer_figure(; resolution=RESOLUTION)
    p = wafervorticity!(ax, vdata; markersize=3f0)
    add_colorbar!(side, p; label="Vorticity (a.u.)")
    save(joinpath(OUT, "example_vorticity.png"), fig; px_per_unit=2)
    println("vorticity done")
end

# ── 8. Heatmap with field overlay (for getting_started) ───────────────────────

let
    fields = example_fields()
    sdata = dense_scalar_data()
    sdata_with_fields = WaferData(
        (x=sdata.x, y=sdata.y, value=sdata.values), WAFER; fields=fields)
    fig, ax, side = wafer_figure(; resolution=RESOLUTION)
    p = waferheatmap!(ax, sdata_with_fields; markersize=3f0, colormap=:plasma,
                      field_color=(:black, 0.0),
                      field_strokecolor=:black, field_strokewidth=1.8f0)
    add_colorbar!(side, p; label="Thickness (nm)")
    add_kpi_panel!(side, sdata_with_fields)
    save(joinpath(OUT, "example_heatmap_fields.png"), fig; px_per_unit=2)
    println("heatmap+fields done")
end

println("\nAll images written to $OUT")
