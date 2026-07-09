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
