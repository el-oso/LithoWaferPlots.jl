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
