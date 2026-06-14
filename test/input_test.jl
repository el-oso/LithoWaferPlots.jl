@testitem "WaferData from NamedTuple (mm mode)" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    tbl = (x = [0.0, 10.0], y = [0.0, 5.0], value = [1.0f0, 2.0f0])
    d = WaferData(tbl, w)
    @test d.x ≈ [0.0, 10.0]
    @test d.y ≈ [0.0, 5.0]
    @test d.values ≈ [1.0, 2.0]
end

@testitem "WaferData from die-index mode" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    grid = DieGrid(0.0, 0.0, 5.0, 5.0)
    tbl = (col = [1, 2, 3], row = [1, 1, 2], value = [10.0, 20.0, 30.0])
    d = WaferData(tbl, grid, w)
    @test d.x[1] ≈ 0.0
    @test d.x[2] ≈ 5.0
    @test d.x[3] ≈ 10.0
    @test d.y[3] ≈ 5.0
end

@testitem "WaferVectorData from NamedTuple (mm mode)" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    tbl = (x = [0.0, 1.0], y = [0.0, 1.0], vx = [1.0, 0.5], vy = [0.5, 1.0])
    d = WaferVectorData(tbl, w)
    @test d.vx ≈ [1.0, 0.5]
    @test d.vy ≈ [0.5, 1.0]
end

@testitem "WaferVectorData from die-index mode" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    grid = DieGrid(0.0, 0.0, 10.0, 10.0)
    tbl = (col = [1, 2], row = [1, 1], vx = [1.0, -1.0], vy = [0.0, 0.5])
    d = WaferVectorData(tbl, grid, w)
    @test d.x[2] ≈ 10.0
    @test d.vx ≈ [1.0, -1.0]
end

@testitem "fields keyword forwarded" begin
    using LithoWaferPlots
    w = WaferSpec(300.0)
    f = WaferField(0.0, 0.0, 10.0, 10.0, 1, 1)
    tbl = (x = [0.0], y = [0.0], value = [1.0])
    d = WaferData(tbl, w; fields = [f])
    @test length(d.fields) == 1
end
