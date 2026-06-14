@testitem "WaferScatter renders without error" tags=[:rendering] begin
    using GLMakie
    GLMakie.activate!(; visible=false)

    w   = WaferSpec(300.0)
    tbl = (x=randn(1000) .* 100, y=randn(1000) .* 100, value=randn(1000))
    d   = WaferData(tbl, w)
    fig, ax, side = wafer_figure()
    p = waferscatter!(ax, d)
    add_colorbar!(side, p)
    add_kpi_panel!(side, d)
    @test fig isa Figure
end

@testitem "WaferHeatmap renders without error" tags=[:rendering] begin
    using GLMakie
    GLMakie.activate!(; visible=false)

    w   = WaferSpec(300.0)
    tbl = (x=randn(500) .* 100, y=randn(500) .* 100, value=rand(500))
    d   = WaferData(tbl, w)
    fig, ax, side = wafer_figure()
    p = waferheatmap!(ax, d)
    @test fig isa Figure
end

@testitem "WaferContour renders without error" tags=[:rendering] begin
    using GLMakie
    GLMakie.activate!(; visible=false)

    w   = WaferSpec(300.0)
    xs  = [x for x in -140.0:5.0:140.0 for y in -140.0:5.0:140.0]
    ys  = [y for x in -140.0:5.0:140.0 for y in -140.0:5.0:140.0]
    vs  = sin.(xs ./ 30) .+ cos.(ys ./ 30)
    d   = WaferData(xs, ys, vs, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = wafercontour!(ax, d)
    @test fig isa Figure
end

@testitem "WaferArrows renders without error" tags=[:rendering] begin
    using GLMakie
    GLMakie.activate!(; visible=false)

    w   = WaferSpec(300.0)
    xs  = [x for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    ys  = [y for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    vxs = -ys ./ 100
    vys =  xs ./ 100
    d   = WaferVectorData(xs, ys, vxs, vys, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = waferarrows!(ax, d)
    @test fig isa Figure
end

@testitem "WaferStreamlines renders without error" tags=[:rendering] begin
    using GLMakie
    GLMakie.activate!(; visible=false)

    w   = WaferSpec(300.0)
    xs  = [x for x in -120.0:5.0:120.0 for y in -120.0:5.0:120.0]
    ys  = [y for x in -120.0:5.0:120.0 for y in -120.0:5.0:120.0]
    vxs = -ys ./ 80
    vys =  xs ./ 80
    d   = WaferVectorData(xs, ys, vxs, vys, w, WaferField[])
    fig, ax, side = wafer_figure()
    p = waferstreamlines!(ax, d; n_seeds=5, max_steps=50)
    @test fig isa Figure
end
