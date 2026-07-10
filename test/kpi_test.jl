@testitem "KPIMean" begin
    using LithoWaferPlots
    k = KPIMean()
    @test name(k) == "Mean"
    @test compute(k, [1.0, 2.0, 3.0]) ≈ 2.0
end

@testitem "KPISigma" begin
    using LithoWaferPlots
    k = KPISigma()
    @test name(k) == "Sigma"
    @test compute(k, [1.0, 2.0, 3.0]) ≈ 1.0
end

@testitem "KPIMax and KPIMin" begin
    using LithoWaferPlots
    v = [3.0, 1.0, 4.0, 1.5]
    @test compute(KPIMax(), v) ≈ 4.0
    @test compute(KPIMin(), v) ≈ 1.0
end

@testitem "KPIMedian" begin
    using LithoWaferPlots
    @test compute(KPIMedian(), [1.0, 2.0, 3.0, 100.0]) ≈ 2.5
end

@testitem "KPIMeanPlus3Sigma and KPIMeanMinus3Sigma" begin
    using LithoWaferPlots, Statistics
    v = [0.0, 2.0, 4.0]
    @test compute(KPIMeanPlus3Sigma(), v) ≈ 2.0 + 3 * std(v)
    @test compute(KPIMeanMinus3Sigma(), v) ≈ 2.0 - 3 * std(v)
end

@testitem "KPIP99" begin
    using LithoWaferPlots
    v = collect(1.0:100.0)
    @test compute(KPIP99(), v) ≈ 99.0 atol = 1.0
end

@testitem "format_value default" begin
    using LithoWaferPlots
    k = KPIMean()
    s = format_value(k, 3.14159265)
    @test occursin("3.14159", s)
end

@testitem "DEFAULT_KPIS has 6 entries" begin
    using LithoWaferPlots
    @test length(DEFAULT_KPIS) == 6
end

@testitem "Custom KPI implements contract" begin
    using LithoWaferPlots, TypeContracts

    struct MyRange <: AbstractKPI end
    LithoWaferPlots.name(::MyRange) = "Range"
    LithoWaferPlots.compute(::MyRange, v::AbstractVector{<:Real})::Float64 =
        Float64(maximum(v) - minimum(v))

    @test implements(MyRange, AbstractKPI)
end

@testitem "format_value significant digits" begin
    using LithoWaferPlots
    @test format_value(KPIMean(), 3.14159) == "3.14159"            # 2-arg default: 6 sig figs
    @test format_value(KPIMean(), 3.14159, 3) == "3.14"            # 3-arg: sigdigits
    @test format_value(KPIMean(), 123.456, 2) == "120.0"
end

@testitem "zone_kpis splits radially and pins the boundary convention" begin
    using LithoWaferPlots

    w = WaferSpec(300.0)   # r = 150
    # 2 points strictly inside a 100mm-radius boundary, 2 strictly outside, 1 exactly on it
    x = [0.0, 10.0, 140.0, 149.0, 100.0]
    y = [0.0, 0.0, 0.0, 0.0, 0.0]
    v = [1.0, 3.0, 10.0, 20.0, 5.0]
    d = WaferData(x, y, v, w, WaferField[])

    zk = zone_kpis(d; mm_to_edge = 50.0)   # boundary radius = 150 - 50 = 100
    inner = Dict(zk.inner)
    ring = Dict(zk.ring)
    # inner: 0.0, 10.0, and the boundary point 100.0 (<=, matching inside_wafer's convention)
    @test inner["Mean"] ≈ (1.0 + 3.0 + 5.0) / 3
    # ring: 140.0 and 149.0 (> boundary)
    @test ring["Mean"] ≈ (10.0 + 20.0) / 2

    # mm_to_edge >= wafer radius errors, matching add_exclusion_ring!
    @test_throws ErrorException zone_kpis(d; mm_to_edge = 200.0)

    # a zone with no points returns an empty vector, not an error
    zk2 = zone_kpis(d; mm_to_edge = 0.5)   # boundary radius = 149.5: everything is inner
    @test isempty(zk2.ring)
    @test !isempty(zk2.inner)

    # kpis= accepts a subset
    zk3 = zone_kpis(d; mm_to_edge = 50.0, kpis = [KPIMean(), KPIMax()])
    @test length(zk3.inner) == 2 && length(zk3.ring) == 2
end

@testitem "sigdigits honours custom format_value (non-breaking)" begin
    using LithoWaferPlots
    # A custom KPI overriding only the 2-arg form (the documented 0.1.x way)
    struct TaggedKPI <: AbstractKPI end
    LithoWaferPlots.name(::TaggedKPI) = "Tagged"
    LithoWaferPlots.compute(::TaggedKPI, v::AbstractVector{<:Real})::Float64 = Float64(sum(v))
    LithoWaferPlots.format_value(::TaggedKPI, v::Real) = "v=$v"

    @test format_value(TaggedKPI(), 3.14159) == "v=3.14159"        # override used
    @test format_value(TaggedKPI(), 3.14159, 3) == "v=3.14"        # override still used, value pre-rounded
end
