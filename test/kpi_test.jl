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
    @test compute(KPIMeanPlus3Sigma(), v)  ≈ 2.0 + 3*std(v)
    @test compute(KPIMeanMinus3Sigma(), v) ≈ 2.0 - 3*std(v)
end

@testitem "KPIP99" begin
    using LithoWaferPlots
    v = collect(1.0:100.0)
    @test compute(KPIP99(), v) ≈ 99.0 atol=1.0
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
