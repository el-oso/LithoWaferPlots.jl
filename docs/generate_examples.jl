"""
Generate documentation example images.

    julia --project=docs docs/generate_examples.jl
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

function scalar_data(n = 8_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 148.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    # two-bump pattern — looks like a real process non-uniformity
    v = 2.5 .* exp.(-(((x .- 60) .^ 2 .+ (y .+ 40) .^ 2) ./ 4000)) .+
        1.8 .* exp.(-(((x .+ 50) .^ 2 .+ (y .- 70) .^ 2) ./ 3000)) .+
        0.15 .* randn(n)
    return WaferData((x = x, y = y, value = v), WAFER)
end

function dense_scalar_data(step_mm = 3.0)
    # Regular grid — no empty spots when markersize matches grid spacing.
    xs = collect(-148.0:step_mm:148.0)
    ys = collect(-148.0:step_mm:148.0)
    pts = [(x, y) for x in xs, y in ys if x^2 + y^2 <= 148.0^2]
    x = first.(pts)
    y = last.(pts)
    v = sin.(x ./ 40) .* cos.(y ./ 40) .+ 0.5 .* exp.(-(x .^ 2 .+ y .^ 2) ./ 8000) .+
        0.08 .* randn(length(x))
    return WaferData((x = x, y = y, value = v), WAFER)
end

function vector_data(n = 6_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 130.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    # vortex + small outward radial component
    vx = -y ./ 80 .+ x ./ 300 .+ 0.03 .* randn(n)
    vy = x ./ 80 .+ y ./ 300 .+ 0.03 .* randn(n)
    return WaferVectorData((x = x, y = y, vx = vx, vy = vy), WAFER)
end

# Divergence example: two Gaussian sources at different wafer locations.
# ∇·v is large (+) at the source centres and large (−) between them.
function divergence_data(n = 50_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 140.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    σ² = 2500.0
    # source at (+60, +40), sink at (−50, −50)
    function gauss_flow(x, y, cx, cy, amp)
        dx, dy = x .- cx, y .- cy
        d² = dx .^ 2 .+ dy .^ 2
        w = amp .* exp.(-d² ./ σ²)
        return w .* dx, w .* dy
    end
    vx1, vy1 = gauss_flow(x, y, 60.0, 40.0, 1.0)
    vx2, vy2 = gauss_flow(x, y, -50.0, -50.0, -1.0)
    noise = 0.02
    vx = vx1 .+ vx2 .+ noise .* randn(n)
    vy = vy1 .+ vy2 .+ noise .* randn(n)
    return WaferVectorData((x = x, y = y, vx = vx, vy = vy), WAFER)
end

# Vorticity example: differential rotation — fast at centre, slow at edge.
# ω = ∂vy/∂x − ∂vx/∂y is large at centre, falls off outward.
function vorticity_data(n = 50_000)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 140.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    σ² = 5000.0
    speed = exp.(-(x .^ 2 .+ y .^ 2) ./ σ²)   # fast core, slow rim
    vx = -y .* speed ./ 40 .+ 0.01 .* randn(n)
    vy = x .* speed ./ 40 .+ 0.01 .* randn(n)
    return WaferVectorData((x = x, y = y, vx = vx, vy = vy), WAFER)
end

# ── fields overlay ─────────────────────────────────────────────────────────────

function example_fields()
    fw, fh = 26.0, 33.0
    r = WAFER.diameter_mm / 2.0
    all_fields = vec(
        [
            WaferField((ci - 0.5) * fw, (ri - 5) * fh, fw, fh, ci, ri)
                for ri in 1:9, ci in -5:6
        ]
    )
    # Keep only fields that at least partially overlap the wafer disk.
    # The nearest point on a rectangle [cx±hw, cy±hh] to the origin is
    # (clamp(0, x1, x2), clamp(0, y1, y2)); if that point is outside r, drop the field.
    return filter(all_fields) do f
        hw, hh = fw / 2.0, fh / 2.0
        nx = clamp(0.0, f.x_center_mm - hw, f.x_center_mm + hw)
        ny = clamp(0.0, f.y_center_mm - hh, f.y_center_mm + hh)
        nx^2 + ny^2 <= r^2
    end
end

# ── 1. WaferScatter ────────────────────────────────────────────────────────────

let sdata = scalar_data()
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferscatter!(ax, sdata; markersize = 4.0f0)
    add_colorbar!(side, p; label = "Overlay (a.u.)")
    add_kpi_panel!(side, sdata)
    save(joinpath(OUT, "example_scatter.png"), fig; px_per_unit = 2)
    println("scatter done")
end

# ── 2. WaferHeatmap ───────────────────────────────────────────────────────────

let sdata = dense_scalar_data()
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferheatmap!(ax, sdata; markersize = 6.0f0, colormap = :plasma)
    add_colorbar!(side, p; label = "Thickness (nm)")
    add_kpi_panel!(side, sdata)
    save(joinpath(OUT, "example_heatmap.png"), fig; px_per_unit = 2)
    println("heatmap done")
end

# ── 3. WaferContour ───────────────────────────────────────────────────────────

let sdata = dense_scalar_data(5.0)
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = wafercontour!(ax, sdata; levels = 12, colormap = :viridis)
    add_colorbar!(side, p; label = "Overlay (a.u.)")
    save(joinpath(OUT, "example_contour.png"), fig; px_per_unit = 2)
    println("contour done")
end

# ── 4. WaferArrows ────────────────────────────────────────────────────────────
# Use fewer, well-spaced seed points so individual arrows are legible.

let vdata = vector_data(600)
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferarrows!(ax, vdata; lengthscale = 8.0, arrowcolor = :steelblue)
    save(joinpath(OUT, "example_arrows.png"), fig; px_per_unit = 2)
    println("arrows done")
end

# ── 5. WaferStreamlines ───────────────────────────────────────────────────────

let vdata = vector_data(15_000)
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferstreamlines!(
        ax, vdata; n_seeds = 12, max_steps = 80,
        color = :navy, linewidth = 1.2f0
    )
    save(joinpath(OUT, "example_streamlines.png"), fig; px_per_unit = 2)
    println("streamlines done")
end

# ── 6. WaferDivergence ────────────────────────────────────────────────────────

let vdata = divergence_data()
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferdivergence!(ax, vdata; colormap = :RdBu, markersize = 3.0f0)
    add_colorbar!(side, p; label = "Divergence (a.u.)")
    save(joinpath(OUT, "example_divergence.png"), fig; px_per_unit = 2)
    println("divergence done")
end

# ── 7. WaferVorticity ─────────────────────────────────────────────────────────

let vdata = vorticity_data()
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = wafervorticity!(ax, vdata; markersize = 3.0f0)
    add_colorbar!(side, p; label = "Vorticity (a.u.)")
    save(joinpath(OUT, "example_vorticity.png"), fig; px_per_unit = 2)
    println("vorticity done")
end

# ── 8. Heatmap with field overlay (for getting_started) ───────────────────────

let
    fields = example_fields()
    sdata = dense_scalar_data()
    sdata_with_fields = WaferData(
        (x = sdata.x, y = sdata.y, value = sdata.values), WAFER; fields = fields
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

# ── 9. Heatmap + exclusion rings ──────────────────────────────────────────────

let sdata = dense_scalar_data()
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferheatmap!(ax, sdata; colormap = :plasma)
    add_colorbar!(side, p; label = "Thickness (nm)")
    add_kpi_panel!(side, sdata)
    # inner ring: dashed line only
    add_exclusion_ring!(
        ax, WAFER; mm_to_edge = 2.0,
        label = "2 mm EE", color = :white, linestyle = :dash
    )
    # outer ring: dotted line + dim overlay outside
    add_exclusion_ring!(
        ax, WAFER; mm_to_edge = 20.0,
        label = "20 mm keep-out", color = :yellow, linestyle = :dot,
        dim_outside = true, dim_alpha = 0.35
    )
    add_ring_legend!(ax; position = :rb)
    save(joinpath(OUT, "example_exclusion_rings.png"), fig; px_per_unit = 2)
    println("exclusion rings done")
end

# ── 10. CFD combined: divergence + streamlines ────────────────────────────────

let vdata = divergence_data()
    fig, ax, side = wafer_cfd_figure(
        vdata; scalar = :divergence, vector = :streamlines,
        streamline_color = :white, streamline_linewidth = 1.5f0, n_seeds = 25,
    )
    save(joinpath(OUT, "example_cfd_div_streamlines.png"), fig; px_per_unit = 2)
    println("cfd divergence+streamlines done")
end

# ── 10. CFD combined: vorticity + streamlines ─────────────────────────────────

let vdata = vorticity_data()
    fig, ax, side = wafer_cfd_figure(
        vdata; scalar = :vorticity, vector = :streamlines,
        streamline_color = :white, streamline_linewidth = 1.5f0, n_seeds = 25,
    )
    save(joinpath(OUT, "example_cfd_vort_streamlines.png"), fig; px_per_unit = 2)
    println("cfd vorticity+streamlines done")
end

# ── 12. Die-level yield map ────────────────────────────────────────────────────
# ~96 exposure fields × 9 dies (3×3 per field) = ~864 dies.
# Yield follows a radially decaying Gaussian (process non-uniformity) + noise.

function yield_data()
    fw, fh = 26.0, 33.0
    r_wafer = WAFER.diameter_mm / 2.0
    fields = example_fields()   # ~96 partially-on-wafer fields

    die_w, die_h = fw / 3.0, fh / 3.0
    x = Float64[]
    y = Float64[]
    v = Float64[]

    for f in fields
        for di in 0:2, dj in 0:2
            cx = f.x_center_mm - fw / 2.0 + (di + 0.5) * die_w
            cy = f.y_center_mm - fh / 2.0 + (dj + 0.5) * die_h
            r2 = cx^2 + cy^2
            # radially-decaying base yield, lower at edge
            base = clamp(1.0 - r2 / (0.85 * r_wafer^2), 0.0, 1.0)
            yield = clamp(base + 0.12 * randn(), 0.0, 1.0)
            push!(x, cx)
            push!(y, cy)
            push!(v, yield)
        end
    end

    return WaferData((x = x, y = y, value = v), WAFER; fields = fields)
end

let ydata = yield_data()
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferheatmap!(
        ax, ydata;
        markersize = 14.0f0,
        colormap = :RdYlGn,
        field_color = (:black, 0.0),
        field_strokecolor = :gray50,
        field_strokewidth = 0.7f0,
    )
    add_colorbar!(side, p; label = "Yield")
    add_kpi_panel!(side, ydata)
    add_exclusion_ring!(
        ax, WAFER; mm_to_edge = 2.0,
        label = "2 mm EE", color = :black, linestyle = :dash,
        dim_outside = true, dim_alpha = 0.4,
    )
    add_ring_legend!(ax; position = :lb)
    save(joinpath(OUT, "example_yield.png"), fig; px_per_unit = 2)
    println("yield done")
end

# ── 13. Faceted wafer maps ────────────────────────────────────────────────────
# Four simulated lots (A–D) with different spatial patterns.
# Shared colorscale (colorrange) produces a single colorbar below the 2×2 grid.

function facet_table()
    lots = ["Lot A", "Lot B", "Lot C", "Lot D"]
    n = 3_000
    xs = Float64[]
    ys = Float64[]
    vs = Float64[]
    ids = String[]
    patterns = [
        (cx, cy) -> 100.0 + 8.0 * exp(-((cx - 50)^2 + (cy + 30)^2) / 4000) + 1.5 * randn(),
        (cx, cy) -> 100.0 - 8.0 * exp(-((cx + 40)^2 + (cy - 60)^2) / 5000) + 1.5 * randn(),
        (cx, cy) -> 100.0 + 5.0 * sin(cx / 35) * cos(cy / 35) + 1.5 * randn(),
        (cx, cy) -> 100.0 + 6.0 * (cx^2 + cy^2) / (150^2) + 1.5 * randn(),
    ]
    for (lot, pat) in zip(lots, patterns)
        θ = rand(n) .* 2π
        r = sqrt.(rand(n)) .* 148.0
        x = r .* cos.(θ)
        y = r .* sin.(θ)
        v = pat.(x, y)
        append!(xs, x)
        append!(ys, y)
        append!(vs, v)
        append!(ids, fill(lot, n))
    end
    return (x = xs, y = ys, value = vs, lot = ids)
end

let tbl = facet_table()
    fig = wafer_facet(
        tbl, WAFER;
        by = :lot,
        plot_type = :heatmap,
        colormap = :plasma,
        colorrange = (90.0, 112.0),
        ncols = 2,
    )
    save(joinpath(OUT, "example_facet.png"), fig; px_per_unit = 2)
    println("facet done")
end

# ── 14. AlgebraOfGraphics compositing ────────────────────────────────────────
# Wafer heatmap (LithoWaferPlots) beside an AoG radial scatter, coloured by zone.
# Both panels live in one Figure — AoG draws into a grid position via draw!().

let
    n = 6_000
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 148.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    thickness = 100.0 .+ 12.0 .* exp.(-r .^ 2 ./ 7000) .+ 2.5 .* randn(n)
    zone = ifelse.(r .< 50, "Center", ifelse.(r .< 110, "Middle", "Edge"))

    wdata = WaferData((x = x, y = y, value = thickness), WAFER)
    df = DataFrame(r = r, thickness = thickness, zone = zone)

    fig = Figure(size = (1050, 480))

    # left sub-layout: wafer heatmap + colorbar
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

    # right: AlgebraOfGraphics radial profile coloured by zone
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

# ── 15. Logo & watermark overlays ─────────────────────────────────────────────
# Build a synthetic RGBA "logo" in-code (a brand-coloured ring with a notch and a
# transparent centre) — demonstrates the matrix-input + alpha path with no binary asset.

function brand_logo(n = 160)
    img = fill(RGBAf(0, 0, 0, 0), n, n)
    for i in 1:n, j in 1:n
        x = (i - 0.5) / n - 0.5
        y = (j - 0.5) / n - 0.5
        r = sqrt(x^2 + y^2)
        θ = atan(y, x)
        # opaque ring (transparent hole in the middle → shows the plot through it)
        if 0.3 <= r <= 0.46
            img[i, j] = RGBAf(0.1, 0.45, 0.8, 0.95)
        end
        # a notch at the bottom (−90°) to echo a wafer
        if r >= 0.28 && abs(θ + π / 2) < 0.22
            img[i, j] = RGBAf(0, 0, 0, 0)
        end
        # filled centre dot
        if r <= 0.12
            img[i, j] = RGBAf(0.95, 0.55, 0.05, 1.0)
        end
    end
    return img
end

let sdata = dense_scalar_data()
    logo = brand_logo()
    fig, ax, side = wafer_figure(; resolution = RESOLUTION)
    p = waferheatmap!(ax, sdata; colormap = :viridis)
    add_colorbar!(side, p; label = "Thickness (nm)")
    # faded watermark across the wafer, opaque logo in the top-right corner
    add_watermark!(ax, logo; opacity = 0.12, scale = 0.7)
    add_logo!(ax, logo; position = :rt, scale = 0.16)
    save(joinpath(OUT, "example_overlay.png"), fig; px_per_unit = 2)
    println("logo/watermark done")
end

println("\nAll images written to $OUT")
