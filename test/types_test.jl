@testitem "WaferSpec defaults" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    @test w.diameter_mm == 300.0
    @test w.notch_angle_deg == 270.0
    @test w.notch_depth_mm == 4.0
    @test w.edge_exclusion_mm == 2.0
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
