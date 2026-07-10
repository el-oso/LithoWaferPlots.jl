@testitem "WaferScatter renders without error" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    tbl = (x = randn(1000) .* 100, y = randn(1000) .* 100, value = randn(1000))
    d = WaferData(tbl, w)
    fig, ax, side = wafer_figure()
    p = waferscatter!(ax, d)
    add_colorbar!(side, p)
    add_kpi_panel!(side, d)
    @test fig isa Figure
end

@testitem "WaferScatter forwards unrecognized Makie attributes" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    tbl = (x = randn(50) .* 100, y = randn(50) .* 100, value = randn(50))
    d = WaferData(tbl, w)
    fig, ax, side = wafer_figure()
    p = waferscatter!(ax, d; marker = :diamond, strokewidth = 2.0f0, alpha = 0.5)
    @test p[:marker][] == :diamond
    @test p[:strokewidth][] == 2.0f0
    sc = only(filter(pl -> pl isa Scatter, p.plots))
    @test sc[:marker][] == Makie.to_spritemarker(:diamond)
    @test fig isa Figure
end

@testitem "WaferHeatmap renders without error" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    tbl = (x = randn(500) .* 100, y = randn(500) .* 100, value = rand(500))
    d = WaferData(tbl, w)
    fig, ax, side = wafer_figure()
    p = waferheatmap!(ax, d)
    @test fig isa Figure
end

@testitem "WaferHeatmap image mode renders without error" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -140.0:3.0:140.0 for y in -140.0:3.0:140.0 if x^2 + y^2 <= 148.0^2]
    ys = [y for x in -140.0:3.0:140.0 for y in -140.0:3.0:140.0 if x^2 + y^2 <= 148.0^2]
    vs = sin.(xs ./ 40) .+ cos.(ys ./ 40)
    d = WaferData(xs, ys, vs, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = waferheatmap!(ax, d; imagemode = :image, grid_n = 64)
    add_colorbar!(side, p; label = "Test")
    @test fig isa Figure
end

@testitem "WaferHeatmap image mode paints out to the true wafer edge, feathered" tags = [:rendering] begin
    using CairoMakie
    # Regression test: the raster used to stop at the (smaller) edge-exclusion radius,
    # leaving an unpainted, jagged-edged gap between the raster and the drawn wafer
    # boundary. It must now reach the true wafer radius, with the outermost ring of
    # pixels partially transparent (feathered) rather than a hard cutoff.
    w = WaferSpec(300.0)
    xs = [x for x in -140.0:3.0:140.0 for y in -140.0:3.0:140.0 if x^2 + y^2 <= 148.0^2]
    ys = [y for x in -140.0:3.0:140.0 for y in -140.0:3.0:140.0 if x^2 + y^2 <= 148.0^2]
    vs = sin.(xs ./ 40) .+ cos.(ys ./ 40)
    d = WaferData(xs, ys, vs, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = waferheatmap!(ax, d; imagemode = :image, grid_n = 64)
    img = only(filter(pl -> pl isa Image, p.plots))[3][]

    r = w.diameter_mm / 2.0
    xs_grid = LinRange(-r, r, 64)   # same construction as _heatmap_image!'s grid
    r_active = r - w.edge_exclusion_mm

    # every pixel whose centre lies strictly between the old (edge-exclusion) cutoff and
    # the true edge must now be painted (nonzero alpha) instead of fully transparent.
    # Scan the whole annulus rather than hand-picking one (i, j): the even grid has no
    # pixel centre on either axis, so a hand-picked "closest to (149, 0)" pixel is the
    # corner sample at x = 150.0, whose true radius hypot(150, 2.38) lies OUTSIDE the
    # wafer and is correctly left transparent.
    annulus = [
        (i, j) for i in eachindex(xs_grid), j in eachindex(xs_grid)
            if r_active < hypot(xs_grid[i], xs_grid[j]) < r
    ]
    @test !isempty(annulus)
    @test all(ij -> img[ij[1], ij[2]].alpha > 0.0f0, annulus)

    # the outermost painted ring must be partially transparent (feathered), not opaque —
    # i.e. some pixel strictly inside the true radius has 0 < alpha < 1
    alphas = [img[i, j].alpha for i in eachindex(xs_grid), j in eachindex(xs_grid)]
    @test any(a -> 0.0f0 < a < 1.0f0, alphas)
end

@testitem "WaferDivergence/WaferVorticity switch to image mode at the default (dense) grid_n and get the same edge fix" tags = [:rendering] begin
    using CairoMakie
    # divergence/vorticity always produce a dense grid_n×grid_n field regardless of the
    # input point count, so at the default grid_n=256 they must land in image mode (like
    # WaferHeatmap) and get the same true-radius, feathered edge — not the old scatter-rect
    # mosaic that stopped short of the boundary.
    w = WaferSpec(300.0)
    xs = [x for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    ys = [y for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    d = WaferVectorData(xs, ys, -ys ./ 100, xs ./ 100, w, WaferField[])
    fig, ax, side = wafer_figure()
    pd = waferdivergence!(ax, d)
    img = only(filter(pl -> pl isa Image, pd.plots))[3][]
    @test !any(pl -> pl isa Scatter, pd.plots)

    r = w.diameter_mm / 2.0
    r_active = r - w.edge_exclusion_mm
    grid_n = size(img, 1)
    xs_grid = LinRange(-r, r, grid_n)
    annulus = [
        (i, j) for i in eachindex(xs_grid), j in eachindex(xs_grid)
            if r_active < hypot(xs_grid[i], xs_grid[j]) < r
    ]
    @test !isempty(annulus)
    @test all(ij -> img[ij[1], ij[2]].alpha > 0.0f0, annulus)

    # add_colorbar!'s generic Image-mode branch must reflect the recipe's own resolved
    # (symmetric-about-zero) colorrange, not error or silently fall through.
    add_colorbar!(side, pd)
    @test fig isa Figure
end

@testitem "WaferHeatmap respects an explicit colorrange" tags = [:rendering] begin
    using CairoMakie

    # A colorrange shared across several wafers (e.g. AlgebraOfGraphics' global color
    # scale, or a manual facet comparison) must override the per-dataset ColorScale in
    # BOTH render modes — it used to be silently recomputed from the data.
    w = WaferSpec(300.0)
    tbl = (x = randn(500) .* 100, y = randn(500) .* 100, value = rand(500))
    d = WaferData(tbl, w)

    # scatter mode: the range must reach the Scatter child untouched
    fig, ax, side = wafer_figure()
    p = waferheatmap!(ax, d; colorrange = (0.0, 10.0))
    sc = only(filter(pl -> pl isa Scatter, p.plots))
    @test sc[:colorrange][] == Makie.Vec2f(0.0, 10.0)

    # image mode: values in [0,1] normalized against (0,10) land in the bottom tenth of
    # the colormap, so the baked image must differ from the automatic-range one
    fig2, ax2, side2 = wafer_figure()
    p2 = waferheatmap!(ax2, d; imagemode = :image, grid_n = 32)
    fig3, ax3, side3 = wafer_figure()
    p3 = waferheatmap!(ax3, d; imagemode = :image, grid_n = 32, colorrange = (0.0, 10.0))
    img_auto = only(filter(pl -> pl isa Image, p2.plots))[3][]
    img_wide = only(filter(pl -> pl isa Image, p3.plots))[3][]
    @test img_auto != img_wide
end

@testitem "WaferHeatmap forwards unrecognized Makie attributes" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    tbl = (x = randn(50) .* 100, y = randn(50) .* 100, value = randn(50))
    d = WaferData(tbl, w)
    fig, ax, side = wafer_figure()
    p1 = waferheatmap!(ax, d; marker = :diamond)
    sc = only(filter(pl -> pl isa Scatter, p1.plots))
    @test sc[:marker][] == Makie.to_spritemarker(:diamond)

    fig2, ax2, side2 = wafer_figure()
    p2 = waferheatmap!(ax2, d; imagemode = :image, grid_n = 32, interpolate = false)
    img = only(filter(pl -> pl isa Image, p2.plots))
    @test img[:interpolate][] == false
    @test fig isa Figure && fig2 isa Figure
end

@testitem "WaferContour renders without error" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -140.0:5.0:140.0 for y in -140.0:5.0:140.0]
    ys = [y for x in -140.0:5.0:140.0 for y in -140.0:5.0:140.0]
    vs = sin.(xs ./ 30) .+ cos.(ys ./ 30)
    d = WaferData(xs, ys, vs, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = wafercontour!(ax, d)
    @test fig isa Figure
end

@testitem "WaferContour forwards unrecognized Makie attributes" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -140.0:5.0:140.0 for y in -140.0:5.0:140.0]
    ys = [y for x in -140.0:5.0:140.0 for y in -140.0:5.0:140.0]
    vs = sin.(xs ./ 30) .+ cos.(ys ./ 30)
    d = WaferData(xs, ys, vs, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = wafercontour!(ax, d; linewidth = 2.0f0, linestyle = :dash)
    @test p[:linewidth][] == 2.0f0
    @test fig isa Figure
end

@testitem "WaferArrows renders without error" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    ys = [y for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    vxs = -ys ./ 100
    vys = xs ./ 100
    d = WaferVectorData(xs, ys, vxs, vys, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = waferarrows!(ax, d)
    @test fig isa Figure
end

@testitem "WaferArrows forwards unrecognized Makie attributes" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    ys = [y for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    d = WaferVectorData(xs, ys, -ys ./ 100, xs ./ 100, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = waferarrows!(ax, d; linestyle = :dash, alpha = 0.6, draw_boundary = false, draw_fields = false)
    @test p[:linestyle][] == :dash
    @test only(filter(pl -> pl isa Lines, p.plots)) isa Lines
    @test fig isa Figure
end

@testitem "draw_wafer_boundary!/draw_fields! are idempotent across overlaid recipes" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    fields = field_grid([((c - 2) * 26.0, (r - 2) * 33.0) for r in 1:3, c in 1:3], (26.0, 33.0); wafer = w)
    xs = [x for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    ys = [y for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    sdata = WaferData(xs, ys, xs .+ ys, w, fields)
    vdata = WaferVectorData(xs, ys, -ys ./ 100, xs ./ 100, w, fields)

    fig, ax, side = wafer_figure()
    waferheatmap!(ax, sdata)   # draw_boundary/draw_fields default true
    waferarrows!(ax, vdata)    # also default true — must not re-draw

    ext = Base.get_extension(LithoWaferPlots, :LithoWaferPlotsMakieExt)
    on_this_axis(marks) = count(pl -> Makie.parent_scene(pl) === ax.scene, keys(marks))
    @test on_this_axis(ext._BOUNDARY_MARKS) == 1
    @test on_this_axis(ext._FIELDS_MARKS) == 1
end

@testitem "idempotent boundary skip never leaves a recipe with zero children" tags = [:rendering] begin
    using CairoMakie
    # Regression test: a recipe whose own primary content is empty (e.g. WaferStreamlines
    # tracing zero segments) must still end up with >=1 child plot even when boundary/fields
    # were already drawn by an earlier sibling recipe on the same axis — Makie treats a
    # plot with an empty `.plots` as a primitive and crashes looking up `.clip_planes`.
    w = WaferSpec(300.0)
    x = [-80.0, 0.0, 80.0, 40.0, -40.0]
    y = [-80.0, 0.0, 80.0, -40.0, 40.0]
    vx = [0.1, -0.2, 0.3, -0.1, 0.2]
    vy = [0.2, 0.1, -0.3, 0.2, -0.1]
    vdata = WaferVectorData((x = x, y = y, vx = vx, vy = vy), w)

    fig, ax, side = wafer_figure()
    waferarrows!(ax, vdata)
    p2 = waferstreamlines!(ax, vdata; n_seeds = 2, max_steps = 5, grid_n = 16)
    @test !isempty(p2.plots)
    @test Makie.boundingbox(p2) isa Rect3d
end

@testitem "WaferStreamlines renders without error" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -120.0:5.0:120.0 for y in -120.0:5.0:120.0]
    ys = [y for x in -120.0:5.0:120.0 for y in -120.0:5.0:120.0]
    vxs = -ys ./ 80
    vys = xs ./ 80
    d = WaferVectorData(xs, ys, vxs, vys, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = waferstreamlines!(ax, d; n_seeds = 5, max_steps = 50)
    @test fig isa Figure
end

@testitem "WaferStreamlines forwards unrecognized Makie attributes" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -120.0:5.0:120.0 for y in -120.0:5.0:120.0]
    ys = [y for x in -120.0:5.0:120.0 for y in -120.0:5.0:120.0]
    d = WaferVectorData(xs, ys, -ys ./ 80, xs ./ 80, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = waferstreamlines!(
        ax, d; n_seeds = 5, max_steps = 50, linestyle = :dot,
        draw_boundary = false, draw_fields = false
    )
    @test p[:linestyle][] == :dot
    @test only(filter(pl -> pl isa Lines, p.plots)) isa Lines
    @test fig isa Figure
end

@testitem "WaferDivergence/WaferVorticity forward unrecognized Makie attributes" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    ys = [y for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    d = WaferVectorData(xs, ys, -ys ./ 100, xs ./ 100, w, WaferField[])
    fig, ax, side = wafer_figure()
    pd = waferdivergence!(ax, d; grid_n = 32, marker = :circle, strokewidth = 1.0f0)
    sc = only(filter(pl -> pl isa Scatter, pd.plots))
    @test sc[:marker][] == Makie.to_spritemarker(:circle)

    fig2, ax2, side2 = wafer_figure()
    pv = wafervorticity!(ax2, d; grid_n = 32, marker = :circle)
    sc2 = only(filter(pl -> pl isa Scatter, pv.plots))
    @test sc2[:marker][] == Makie.to_spritemarker(:circle)
    @test fig isa Figure && fig2 isa Figure
end

@testitem "WaferArrows accepts a per-point arrowcolor vector" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -100.0:20.0:100.0 for y in -100.0:20.0:100.0]
    ys = [y for x in -100.0:20.0:100.0 for y in -100.0:20.0:100.0]
    n = length(xs)
    d = WaferVectorData(xs, ys, -ys ./ 100, xs ./ 100, w, WaferField[])
    colorvals = collect(1.0:n)

    fig, ax, side = wafer_figure()
    p = waferarrows!(ax, d; arrowcolor = colorvals, colormap = :plasma, draw_boundary = false, draw_fields = false)
    ln = only(filter(pl -> pl isa Lines, p.plots))
    @test eltype(ln[:color][]) <: Real
    @test fig isa Figure

    # a mismatched-length vector must error, not silently misalign
    @test_throws ErrorException waferarrows!(ax, d; arrowcolor = colorvals[1:(end - 1)])

    # subsampling: the vector must be subsampled in lockstep with the arrows it colors
    p2 = waferarrows!(
        ax, d; arrowcolor = colorvals, max_arrows = 5, arrow_sample = :random,
        draw_boundary = false, draw_fields = false
    )
    @test only(filter(pl -> pl isa Lines, p2.plots)) isa Lines
end

@testitem "WaferDivergence/WaferVorticity colorrange is centered on zero" tags = [:rendering] begin
    using CairoMakie
    # A one-sided synthetic field has a genuinely asymmetric raw (min, max) — colorrange
    # must still straddle zero symmetrically or a diverging colormap's neutral point lands
    # away from the true zero-crossing (verified bug: raw (vmin,vmax) put the midpoint at
    # +0.04 for a field ranging -0.02..0.10, so the whole near-zero region rendered as one
    # solid color instead of transitioning through white at the actual zero).
    w = WaferSpec(300.0)
    x = [x for x in -100.0:20.0:100.0 for y in -100.0:20.0:100.0]
    y = [y for x in -100.0:20.0:100.0 for y in -100.0:20.0:100.0]
    # single source only (no sink): divergence and vorticity are both one-sided
    r2 = @. (x - 30.0)^2 + (y - 20.0)^2
    vx = @. exp(-r2 / 2000.0) * (x - 30.0)
    vy = @. exp(-r2 / 2000.0) * (y - 20.0)
    d = WaferVectorData(x, y, vx, vy, w, WaferField[])

    fig, ax, side = wafer_figure()
    pd = waferdivergence!(ax, d; grid_n = 32)
    lo, hi = pd.plots[1][:colorrange][]
    @test lo ≈ -hi atol = 1.0e-4

    fig2, ax2, side2 = wafer_figure()
    pv = wafervorticity!(ax2, d; grid_n = 32)
    lo2, hi2 = pv.plots[1][:colorrange][]
    @test lo2 ≈ -hi2 atol = 1.0e-4
end

@testitem "WaferDivergence/WaferVorticity respect an explicit colorrange" tags = [:rendering] begin
    using CairoMakie
    # An explicit colorrange (e.g. shared with an overlaid arrow layer encoding the same
    # quantity) must override the auto-computed symmetric range, not be silently discarded.
    w = WaferSpec(300.0)
    x = [x for x in -100.0:20.0:100.0 for y in -100.0:20.0:100.0]
    y = [y for x in -100.0:20.0:100.0 for y in -100.0:20.0:100.0]
    d = WaferVectorData(x, y, -y ./ 100, x ./ 100, w, WaferField[])

    fig, ax, side = wafer_figure()
    pd = waferdivergence!(ax, d; grid_n = 32, colorrange = (-5.0, 5.0))
    @test pd.plots[1][:colorrange][] == Makie.Vec2f(-5.0, 5.0)

    fig2, ax2, side2 = wafer_figure()
    pv = wafervorticity!(ax2, d; grid_n = 32, colorrange = (-3.0, 3.0))
    @test pv.plots[1][:colorrange][] == Makie.Vec2f(-3.0, 3.0)
end

@testitem "Image overlays render without error" tags = [:rendering] begin
    using CairoMakie
    using CairoMakie: RGBAf

    w = WaferSpec(300.0)
    tbl = (x = randn(500) .* 100, y = randn(500) .* 100, value = rand(500))
    d = WaferData(tbl, w)

    # synthetic RGBA image with a transparent corner to exercise the alpha path
    img = [RGBAf(i / 32, j / 32, 0.5, (i + j) / 64) for i in 1:32, j in 1:32]

    # Axis target: general overlay + logo + watermark
    fig, ax, side = wafer_figure()
    waferheatmap!(ax, d)
    @test add_image_overlay!(ax, img; position = :lt, scale = 0.2) isa Any
    @test add_logo!(ax, img; position = :rt) isa Any
    @test add_watermark!(ax, img; opacity = 0.2) isa Any

    # Figure target + (fx, fy) tuple position
    fig2, ax2, side2 = wafer_figure()
    waferheatmap!(ax2, d)
    add_logo!(fig2, img; position = (0.9, 0.1), scale = 0.1)
    @test fig isa Figure
    @test fig2 isa Figure
end

@testitem "GLMakie backend loads and compiles recipes" tags = [:rendering, :glmakie] begin
    # The Makie extension must load and its recipes must compile under GLMakie, not just
    # CairoMakie. Building plot objects exercises the GLMakie pipeline without opening a
    # window, so this stays headless-safe (no display / save).
    using GLMakie

    @test Base.get_extension(LithoWaferPlots, :LithoWaferPlotsMakieExt) !== nothing

    GLMakie.activate!()
    wafer = WaferSpec(300.0)
    xs = [x for x in -120.0:20.0:120.0 for y in -120.0:20.0:120.0]
    ys = [y for x in -120.0:20.0:120.0 for y in -120.0:20.0:120.0]
    sd = WaferData((x = xs, y = ys, value = sin.(xs ./ 40)), wafer)
    vd = WaferVectorData((x = xs, y = ys, vx = -ys ./ 100, vy = xs ./ 100), wafer)

    fig, ax, side = wafer_figure()
    @test waferheatmap!(ax, sd) isa Any
    @test waferarrows!(ax, vd; arrowcolor = :magnitude) isa Any
    @test fig isa Figure
end

@testitem "draw_field_numbers! and sigdigits KPI panel render" tags = [:rendering] begin
    using CairoMakie
    wafer = WaferSpec(300.0)
    fields = full_fields(
        field_grid([((c - 0.5) * 26.0, (r - 5) * 33.0) for r in 1:9, c in -5:6], (26.0, 33.0); wafer = wafer),
        wafer,
    )
    d = WaferData((x = randn(500) .* 100, y = randn(500) .* 100, value = rand(500)), wafer; fields = fields)
    fig, ax, side = wafer_figure()
    p = waferheatmap!(ax, d)
    add_kpi_panel!(side, d; sigdigits = 3)
    @test draw_field_numbers!(ax, fields) === nothing
    @test draw_field_numbers!(ax, fields; numbers = collect(1:length(fields))) === nothing
    # font/placement options
    @test draw_field_numbers!(ax, fields; position = :tr, fontsize = 11, color = :white, alpha = 0.6) === nothing
    @test draw_field_numbers!(ax, fields; position = :bl) === nothing
    @test_throws ErrorException draw_field_numbers!(ax, fields; position = :xx)
    @test fig isa Figure
end

@testitem "ArrowScale drives arrows and reference consistently" tags = [:rendering] begin
    using CairoMakie
    wafer = WaferSpec(300.0)
    xs = [x for x in -120.0:20.0:120.0 for y in -120.0:20.0:120.0]
    ys = [y for x in -120.0:20.0:120.0 for y in -120.0:20.0:120.0]
    vd = WaferVectorData((x = xs, y = ys, vx = -ys ./ 100, vy = xs ./ 100), wafer)
    s = arrow_scale(0.5, 18.0)
    fig, ax, side = wafer_figure()
    @test waferarrows!(ax, vd; scale = s) isa Any
    @test add_scale_arrow!(ax, s) === nothing
    @test fig isa Figure
    @test wafer_cfd_figure(vd; vector = :arrows, scale = s)[1] isa Figure
end

@testitem "add_scale_arrow! matches waferarrows!'s actual resolved scale" tags = [:rendering] begin
    using CairoMakie
    wafer = WaferSpec(300.0)
    xs = [x for x in -120.0:20.0:120.0 for y in -120.0:20.0:120.0]
    ys = [y for x in -120.0:20.0:120.0 for y in -120.0:20.0:120.0]
    vd = WaferVectorData((x = xs, y = ys, vx = -ys ./ 100, vy = xs ./ 100), wafer)

    fig, ax, side = wafer_figure()
    p = waferarrows!(ax, vd; lengthscale = 8.0)
    @test add_scale_arrow!(ax, p) === nothing                        # auto ref_magnitude
    @test add_scale_arrow!(ax, p; ref_magnitude = 0.3) === nothing    # explicit ref_magnitude
    @test fig isa Figure

    s = arrow_scale(0.5, 18.0)
    fig2, ax2, side2 = wafer_figure()
    p2 = waferarrows!(ax2, vd; scale = s)
    @test add_scale_arrow!(ax2, p2) === nothing                       # ArrowScale delegation branch
    @test fig2 isa Figure
end

@testitem "add_scale_arrow!'s auto ref_magnitude uses the actually-drawn (subsampled) arrows" tags = [:rendering] begin
    using CairoMakie, Statistics
    # Regression test: with arrow_sample=:magnitude subsampling active, the auto-picked
    # reference used to be computed over the FULL pre-subsampling population — heavily
    # biased toward small values relative to what's actually drawn (magnitude-based
    # subsampling keeps only the largest |v| points), making the reference arrow much
    # smaller than the arrows it's meant to calibrate. It must instead reflect the subset
    # that ends up on screen.
    w = WaferSpec(300.0)
    n = 2000
    xs = collect(range(-140.0, 140.0; length = n))
    ys = zeros(n)
    # 90% tiny magnitude, 10% large — median over ALL points is tiny (dominated by the
    # majority), but the top max_arrows=100 by magnitude (what :magnitude subsampling
    # keeps) are all drawn from the large minority
    vx = [i <= round(Int, 0.9n) ? 0.01 : 10.0 for i in 1:n]
    vy = zeros(n)
    d = WaferVectorData(xs, ys, vx, vy, w, WaferField[])

    fig, ax, side = wafer_figure()
    p = waferarrows!(ax, d; max_arrows = 100)   # forces subsampling; default arrow_sample=:magnitude
    add_scale_arrow!(ax, p)
    txt = only(filter(pl -> pl isa Makie.Text, ax.scene.plots))
    refmag = parse(Float64, only(txt[:text][]))

    ext = Base.get_extension(LithoWaferPlots, :LithoWaferPlotsMakieExt)
    idx = ext._subsample_idx(d, 100, :magnitude)
    displayed_median = median(hypot.(d.vx[idx], d.vy[idx]))
    full_median = median(hypot.(d.vx, d.vy))

    @test full_median < 1.0            # sanity: the naive full-population median is tiny
    @test refmag > 5.0                 # the fixed reference reflects the displayed (large) subset
    @test isapprox(refmag, displayed_median; rtol = 0.5)
end

@testitem "plot_averaged_field and field_facet render" tags = [:rendering] begin
    using CairoMakie
    wafer = WaferSpec(300.0)
    fields = field_grid([((c - 0.5) * 26.0, (r - 5) * 33.0) for r in 1:9, c in -5:6], (26.0, 33.0); wafer = wafer)
    fx = Float64[]; fy = Float64[]; dx = Float64[]; dy = Float64[]; val = Float64[]
    for f in fields, ix in -10.0:5.0:10.0, iy in -13.0:6.5:13.0
        push!(fx, f.x_center_mm); push!(fy, f.y_center_mm)
        push!(dx, ix); push!(dy, iy); push!(val, 0.02 * ix^2 + 0.1 * iy)
    end
    fd = fielded((fx = fx, fy = fy, dx = dx, dy = dy, value = val), fields; wafer = wafer)
    af = stack_fields(fd; full_only = true)
    @test plot_averaged_field(af) isa Figure
    @test field_facet(fd; full_only = true, colorrange = extrema(val), ncols = 6) isa Figure
end

@testitem "WaferScatter/WaferHeatmap render without error when a value is NaN" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    n = 30
    x = randn(n) .* 80
    y = randn(n) .* 80
    v = collect(1.0:n)
    v[15] = NaN
    d = WaferData(x, y, v, w, WaferField[])   # NaN row already dropped at construction

    fig1, ax1, side1 = wafer_figure()
    p1 = waferscatter!(ax1, d)
    add_colorbar!(side1, p1)
    add_kpi_panel!(side1, d)
    @test fig1 isa Figure

    fig2, ax2, side2 = wafer_figure()
    p2 = waferheatmap!(ax2, d)
    add_colorbar!(side2, p2)
    @test fig2 isa Figure
end

@testitem "plot_averaged_field renders without error when a value is NaN" tags = [:rendering] begin
    using CairoMakie

    wafer = WaferSpec(300.0)
    fields = field_grid([((c - 0.5) * 26.0, (r - 5) * 33.0) for r in 1:9, c in -5:6], (26.0, 33.0); wafer = wafer)
    fx = Float64[]; fy = Float64[]; dx = Float64[]; dy = Float64[]; val = Float64[]
    for f in fields, ix in -10.0:5.0:10.0, iy in -13.0:6.5:13.0
        push!(fx, f.x_center_mm); push!(fy, f.y_center_mm)
        push!(dx, ix); push!(dy, iy); push!(val, 0.02 * ix^2 + 0.1 * iy)
    end
    fd = fielded((fx = fx, fy = fy, dx = dx, dy = dy, value = val), fields; wafer = wafer)
    af = stack_fields(fd; full_only = true)
    af.value[1] = NaN
    @test plot_averaged_field(af) isa Figure
end

@testitem "add_scale_arrow! renders without error" tags = [:rendering] begin
    using CairoMakie

    w = WaferSpec(300.0)
    xs = [x for x in -120.0:20.0:120.0 for y in -120.0:20.0:120.0]
    ys = [y for x in -120.0:20.0:120.0 for y in -120.0:20.0:120.0]
    d = WaferVectorData(xs, ys, -ys ./ 100, xs ./ 100, w, WaferField[])

    fig, ax, side = wafer_figure()
    waferarrows!(ax, d; lengthscale = 8.0)
    # length_data is in mm; keep it a sane fraction of the wafer so it doesn't
    # blow up the axis limits (here a 50 nm vector at lengthscale 0.8 → 40 mm)
    @test add_scale_arrow!(ax, 50.0 * 0.8; label = "50 nm", position = :rb) === nothing
    @test add_scale_arrow!(ax, 40.0; position = :cb) === nothing  # no label path
    @test_throws ErrorException add_scale_arrow!(ax, -1.0)
    @test fig isa Figure
end
