@testitem "wafer_polygon point count" begin
    using LithoWaferPlots
    spec = WaferSpec(300.0)
    pts = wafer_polygon(spec; n = 256)
    @test length(pts) >= 256 + 2  # n + notch vertices + closing point
    @test pts[1] == pts[end]       # closed polygon
end

@testitem "wafer_polygon all points near radius" begin
    using LithoWaferPlots
    spec = WaferSpec(300.0)
    r = 150.0
    pts = wafer_polygon(spec; n = 512)
    for (x, y) in pts[1:(end - 1)]
        @test sqrt(x^2 + y^2) <= r + 0.1
    end
end

@testitem "notch vertex is indented" begin
    using LithoWaferPlots
    spec = WaferSpec(300.0)
    pts = wafer_polygon(spec; n = 256)
    r = 150.0
    min_r = minimum(sqrt(x^2 + y^2) for (x, y) in pts)
    @test min_r < r - 0.5
end

@testitem "rounded notch geometry" begin
    using LithoWaferPlots
    spec = WaferSpec(300.0, 270.0, 1.0, 2.0)  # r=150, notch at bottom, 1 mm deep
    r, d = 150.0, 1.0
    pts = wafer_polygon(spec; n = 256)

    # apex sits at depth d from the rim (at the notch angle, 270° → bottom);
    # tolerance covers the sub-mm radial-curvature offset of the rounded bottom
    radii = [sqrt(x^2 + y^2) for (x, y) in pts]
    @test minimum(radii) ≈ r - d atol = 0.05
    apex = pts[argmin(radii)]
    @test apex[1] ≈ 0.0 atol = 1e-3       # x ≈ 0 at 270°
    @test apex[2] ≈ -(r - d) atol = 0.05  # straight down

    # the bulk of the boundary is on the rim (corners + circle), within r
    @test all(<=(r + 1e-6), radii)
    @test count(≈(r; atol = 1e-3), radii) > 200
end

@testitem "inside_wafer mask" begin
    using LithoWaferPlots
    spec = WaferSpec(300.0)  # r=150, edge_excl=2 → r_active=148
    x = [0.0, 148.0, 149.0, 200.0]
    y = [0.0, 0.0, 0.0, 0.0]
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

@testitem "field_grid builds and clips fields" begin
    using LithoWaferPlots
    wafer = WaferSpec(300.0)
    centers = [((c - 0.5) * 26.0, (r - 5) * 33.0) for r in 1:9, c in -5:6]

    # without a wafer: every centre becomes a field
    all_fields = field_grid(centers, (26.0, 33.0))
    @test length(all_fields) == length(centers)
    @test all(f -> f.width_mm == 26.0 && f.height_mm == 33.0, all_fields)

    # array indices become (row_idx, col_idx)
    @test all_fields[1].row_idx == 1 && all_fields[1].col_idx == 1

    # with a wafer: off-disk fields are dropped, on-disk kept
    clipped = field_grid(centers, (26.0, 33.0); wafer = wafer)
    @test 0 < length(clipped) < length(all_fields)
    r = wafer.diameter_mm / 2
    @test all(clipped) do f
        nx = clamp(0.0, f.x_center_mm - 13.0, f.x_center_mm + 13.0)
        ny = clamp(0.0, f.y_center_mm - 16.5, f.y_center_mm + 16.5)
        nx^2 + ny^2 <= r^2
    end

    # scalar field_size → square fields; vector centres → 1 column
    sq = field_grid([(0.0, 0.0), (10.0, 0.0)], 8.0)
    @test length(sq) == 2 && sq[1].width_mm == 8.0 && sq[1].height_mm == 8.0
end
