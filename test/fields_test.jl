@testitem "fielded table constructor preserves intrafield coords" begin
    using LithoWaferPlots
    wafer = WaferSpec(300.0)
    fields = [
        WaferField(0.0, 0.0, 26.0, 33.0, 1, 1),
        WaferField(30.0, 0.0, 26.0, 33.0, 2, 1),
    ]
    tbl = (
        fx = [0.0, 0.0, 30.0],
        fy = [0.0, 0.0, 0.0],
        dx = [1.0, -2.0, 3.0],
        dy = [0.5, 0.5, -1.0],
        value = [10.0, 20.0, 30.0],
    )
    fd = fielded(tbl, fields; wafer = wafer)
    @test fd.field_id == [1, 1, 2]
    @test fd.ifx == [1.0, -2.0, 3.0]            # stored directly, no subtraction
    @test fd.data.x == [1.0, -2.0, 33.0]        # absolute = center + intrafield
    @test fd.data.values == [10.0, 20.0, 30.0]
end

@testitem "center matching tolerates small position error" begin
    using LithoWaferPlots
    fields = [WaferField(30.0, 0.0, 26.0, 33.0, 2, 1)]
    # field center reported with sub-tol jitter
    tbl = (fx = [30.0004, 29.9996], fy = [0.0003, -0.0002], dx = [1.0, 2.0], dy = [0.0, 0.0], value = [1.0, 2.0])
    fd = fielded(tbl, fields; tol = 1.0e-3)
    @test fd.field_id == [1, 1]
end

@testitem "assign_to_fields point-in-rectangle" begin
    using LithoWaferPlots
    fields = [
        WaferField(0.0, 0.0, 10.0, 10.0, 1, 1),
        WaferField(20.0, 0.0, 10.0, 10.0, 2, 1),
    ]
    x = [0.0, 20.0, 100.0]
    y = [0.0, 0.0, 0.0]
    @test assign_to_fields(x, y, fields) == [1, 2, 0]
end

@testitem "full vs partial field detection" begin
    using LithoWaferPlots
    wafer = WaferSpec(300.0)               # radius 150
    center = WaferField(0.0, 0.0, 26.0, 33.0, 1, 1)
    edge = WaferField(140.0, 0.0, 26.0, 33.0, 2, 1)   # corner at (153, 16.5) -> outside
    outside = WaferField(300.0, 0.0, 26.0, 33.0, 3, 1)

    @test is_full_field(center, wafer)
    @test !is_full_field(edge, wafer)

    fields = [center, edge, outside]
    @test full_fields(fields, wafer) == [center]
    @test partial_fields(fields, wafer) == [edge]   # overlaps but clipped; `outside` excluded

    # active boundary (edge exclusion) is stricter
    near = WaferField(0.0, 132.5, 26.0, 33.0, 1, 9)  # top corner ~149.6 mm: inside edge (150), outside active (148)
    @test is_full_field(near, wafer; boundary = :edge)
    @test !is_full_field(near, wafer; boundary = :active)
end

@testitem "filter_full drops points on partial fields" begin
    using LithoWaferPlots
    wafer = WaferSpec(300.0)
    fields = [
        WaferField(0.0, 0.0, 26.0, 33.0, 1, 1),     # full
        WaferField(140.0, 0.0, 26.0, 33.0, 2, 1),   # partial
    ]
    tbl = (
        fx = [0.0, 0.0, 140.0],
        fy = [0.0, 0.0, 0.0],
        dx = [1.0, 2.0, 1.0],
        dy = [0.0, 0.0, 0.0],
        value = [1.0, 2.0, 99.0],
    )
    fd = fielded(tbl, fields; wafer = wafer)
    kept = filter_full(fd)
    @test kept.data.values == [1.0, 2.0]            # the partial-field point is gone
    @test all(id == 1 for id in kept.field_id)
end

@testitem "serpentine shot numbering meanders" begin
    using LithoWaferPlots
    # 2 rows × 3 cols; row_idx increases +y (bottom = 1)
    fields = WaferField[]
    for r in 1:2, c in 1:3
        push!(fields, WaferField(Float64(c) * 30, Float64(r) * 30, 26.0, 26.0, c, r))
    end
    nums = serpentine_numbers(fields)   # bottomleft, lr
    # map (col,row) -> number
    num = Dict((fields[i].col_idx, fields[i].row_idx) => nums[i] for i in eachindex(fields))
    @test num[(1, 1)] == 1 && num[(2, 1)] == 2 && num[(3, 1)] == 3   # bottom row L→R
    @test num[(3, 2)] == 4 && num[(2, 2)] == 5 && num[(1, 2)] == 6   # next row R→L
    @test sort(nums) == collect(1:6)
end

@testitem "stack_fields averages over fields by intrafield coord" begin
    using LithoWaferPlots
    wafer = WaferSpec(300.0)
    fields = [WaferField(0.0, 0.0, 26.0, 33.0, 1, 1), WaferField(30.0, 0.0, 26.0, 33.0, 2, 1)]
    tbl = (
        fx = [0.0, 0.0, 0.0, 30.0, 30.0, 30.0],
        fy = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        dx = [0.0, 1.0, 0.0, 0.0, 1.0, 0.0],
        dy = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0],
        value = [10.0, 20.0, 30.0, 20.0, 30.0, 40.0],
    )
    af = stack_fields(fielded(tbl, fields; wafer = wafer))
    @test af.ifx == [0.0, 1.0, 0.0]            # sorted by (ify, ifx)
    @test af.ify == [0.0, 0.0, 1.0]
    @test af.value == [15.0, 25.0, 35.0]       # mean of the two stacked fields
    @test af.count == [2, 2, 2]
end

@testitem "field_average_profiles slit and scan" begin
    using LithoWaferPlots
    af = AveragedField([0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [15.0, 25.0, 35.0], [2, 2, 2])
    prof = field_average_profiles(af; slit = :x, scan = :y)
    @test prof.slit.pos == [0.0, 1.0]
    @test prof.slit.value == [25.0, 25.0]      # avg over scan at each slit pos
    @test prof.scan.pos == [0.0, 1.0]
    @test prof.scan.value == [20.0, 35.0]      # avg over slit at each scan pos
end

@testitem "field_kpis over averaged field" begin
    using LithoWaferPlots
    af = AveragedField([0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [15.0, 25.0, 35.0], [2, 2, 2])
    d = Dict(field_kpis(af))
    @test d["Mean"] ≈ 25.0
    @test d["Max"] == 35.0
    @test d["Min"] == 15.0
end

@testitem "average_wafers averages matched positions" begin
    using LithoWaferPlots
    wafer = WaferSpec(300.0)
    x = [0.0, 10.0, -10.0]; y = [0.0, 5.0, -5.0]
    w1 = WaferData((x = x, y = y, value = [1.0, 2.0, 3.0]), wafer)
    # second wafer offset by +10, with sub-tolerance position jitter
    w2 = WaferData((x = x .+ 0.0003, y = y .- 0.0002, value = [11.0, 12.0, 13.0]), wafer)
    avg = average_wafers([w1, w2]; tol = 1.0e-3)
    @test length(avg.values) == 3                  # jittered points still matched
    @test avg.values ≈ [8.0, 6.0, 7.0]             # sorted by (y, x): (-10,-5),(0,0),(10,5)

    v1 = WaferVectorData((x = x, y = y, vx = fill(1.0, 3), vy = fill(0.0, 3)), wafer)
    v2 = WaferVectorData((x = x, y = y, vx = fill(3.0, 3), vy = fill(2.0, 3)), wafer)
    av = average_wafers([v1, v2]; tol = 1.0e-3)
    @test all(av.vx .≈ 2.0) && all(av.vy .≈ 1.0)
end

@testitem "ArrowScale math" begin
    using LithoWaferPlots
    s = arrow_scale(2.0, 20.0)
    @test s.lengthscale == 10.0          # ref_length / ref_magnitude
    @test s.ref_magnitude == 2.0 && s.ref_length_mm == 20.0
    @test s.label == "2.0"
    @test arrow_scale(2.0, 20.0; label = "2 nm").label == "2 nm"
    @test_throws ErrorException arrow_scale(-1.0, 5.0)

    wafer = WaferSpec(300.0)
    vd = WaferVectorData((x = [0.0, 10.0], y = [0.0, 0.0], vx = [1.0, 1.0], vy = [0.0, 0.0]), wafer)
    sf = arrow_scale_from(vd; ref_fraction = 0.1)   # nice(median|v|)=1.0, ref_len=0.1*150=15
    @test sf.ref_magnitude == 1.0 && sf.ref_length_mm == 15.0 && sf.lengthscale == 15.0
end
