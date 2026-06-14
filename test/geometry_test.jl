@testitem "wafer_polygon point count" begin
    using LithoWaferPlots
    spec = WaferSpec(300.0)
    pts = wafer_polygon(spec; n=256)
    @test length(pts) >= 256 + 2  # n + notch vertices + closing point
    @test pts[1] == pts[end]       # closed polygon
end

@testitem "wafer_polygon all points near radius" begin
    using LithoWaferPlots
    spec = WaferSpec(300.0)
    r = 150.0
    pts = wafer_polygon(spec; n=512)
    for (x, y) in pts[1:end-1]
        @test sqrt(x^2 + y^2) <= r + 0.1
    end
end

@testitem "notch vertex is indented" begin
    using LithoWaferPlots
    spec = WaferSpec(300.0)
    pts = wafer_polygon(spec; n=256)
    r = 150.0
    min_r = minimum(sqrt(x^2 + y^2) for (x, y) in pts)
    @test min_r < r - 0.5
end

@testitem "inside_wafer mask" begin
    using LithoWaferPlots
    spec = WaferSpec(300.0)  # r=150, edge_excl=2 → r_active=148
    x = [0.0, 148.0, 149.0, 200.0]
    y = [0.0, 0.0,   0.0,   0.0]
    mask = inside_wafer(x, y, spec)
    @test mask[1] == true
    @test mask[2] == true
    @test mask[3] == false
    @test mask[4] == false
end

@testitem "field_bounds" begin
    using LithoWaferPlots
    f = WaferField(10.0, 20.0, 4.0, 6.0, 1, 1)
    xmin, xmax, ymin, ymax = field_bounds(f)
    @test xmin ≈ 8.0
    @test xmax ≈ 12.0
    @test ymin ≈ 17.0
    @test ymax ≈ 23.0
end
