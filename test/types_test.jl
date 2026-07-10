@testitem "WaferSpec defaults" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    @test w.diameter_mm == 300.0
    @test w.notch_angle_deg == 270.0
    @test w.notch_depth_mm == 3.0
    @test w.edge_exclusion_mm == 2.0
    @test w.notch_width_mm == 2.7
    @test w.notch_shape === :rounded_u
end

@testitem "WaferSpec configurable notch shape/size" begin
    using LithoWaferPlots

    # width/shape are keyword-only and layer on top of every existing positional form
    w1 = WaferSpec(300.0; notch_shape = :flat, notch_width_mm = 8.0)
    @test w1.notch_shape === :flat
    @test w1.notch_width_mm == 8.0
    w2 = WaferSpec(300.0, 90.0; notch_shape = :v)
    @test w2.notch_angle_deg == 90.0
    @test w2.notch_shape === :v
    w3 = WaferSpec(300.0, 270.0, 2.0, 2.0; notch_shape = :flat, notch_width_mm = 10.0)
    @test w3.notch_width_mm == 10.0

    # unknown shape errors
    @test_throws ErrorException WaferSpec(300.0; notch_shape = :bogus)

    # :rounded_u requires width <= depth (a wider-than-deep rounded U would bulge past the
    # wafer rim); :flat and :v have no such coupling
    @test_throws ErrorException WaferSpec(300.0, 270.0, 2.0, 2.0; notch_width_mm = 10.0)
    @test WaferSpec(300.0, 270.0, 2.0, 2.0; notch_shape = :flat, notch_width_mm = 10.0) isa WaferSpec
    @test WaferSpec(300.0, 270.0, 2.0, 2.0; notch_shape = :v, notch_width_mm = 10.0) isa WaferSpec
end

@testitem "WaferSpec() defaults to a 300mm wafer" begin
    using LithoWaferPlots
    @test WaferSpec() == WaferSpec(300.0)
end

@testitem "WaferSpec custom notch angle" begin
    using LithoWaferPlots
    w = WaferSpec(200.0, 90.0)
    @test w.notch_angle_deg == 90.0
    @test w.edge_exclusion_mm == 2.0
end

@testitem "DieGrid construction" begin
    using LithoWaferPlots
    g = DieGrid(-50.0, -50.0, 10.0, 10.0)
    @test g.die_width_mm == 10.0
    @test g.die_height_mm == 10.0
end

@testitem "WaferField bounds" begin
    using LithoWaferPlots
    f = WaferField(0.0, 0.0, 10.0, 8.0, 1, 1)
    @test f.width_mm == 10.0
    @test f.height_mm == 8.0
end

@testitem "WaferData construction" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    x = [0.0, 10.0, -10.0]
    y = [0.0, 0.0, 0.0]
    v = [1.0, 2.0, 3.0]
    d = WaferData(x, y, v, w, WaferField[])
    @test length(d.x) == 3
    @test d.values == v
    @test d.wafer === w
end

@testitem "WaferVectorData construction" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    x = [0.0, 1.0]
    y = [0.0, 1.0]
    vx = [1.0, 0.0]
    vy = [0.0, 1.0]
    d = WaferVectorData(x, y, vx, vy, w, WaferField[])
    @test d.vx == vx
    @test d.vy == vy
end

@testitem "WaferData drops non-finite x/y/value rows" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    x = [0.0, 10.0, NaN, 5.0]
    y = [0.0, 0.0, 0.0, Inf]
    v = [1.0, NaN, 3.0, 4.0]
    d = @test_logs (:warn, r"WaferData") WaferData(x, y, v, w, WaferField[])
    @test length(d.x) == 1
    @test d.x == [0.0]
    @test d.values == [1.0]
end

@testitem "WaferVectorData drops non-finite x/y/vx/vy rows" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    x = [0.0, 1.0, 2.0]
    y = [0.0, 1.0, 2.0]
    vx = [1.0, NaN, 0.0]
    vy = [0.0, 0.0, 1.0]
    d = @test_logs (:warn, r"WaferVectorData") WaferVectorData(x, y, vx, vy, w, WaferField[])
    @test length(d.x) == 2
    @test !any(isnan, d.vx)
end
