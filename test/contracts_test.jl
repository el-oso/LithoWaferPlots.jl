@testitem "All built-in KPIs implement AbstractKPI" begin
    using LithoWaferPlots, TypeContracts
    for T in [KPIMean, KPISigma, KPIMax, KPIMin, KPIMedian,
              KPIMeanPlus3Sigma, KPIMeanMinus3Sigma, KPIP99]
        @test implements(T, AbstractKPI)
    end
end

@testitem "Missing mandatory method fails contract" begin
    using LithoWaferPlots, TypeContracts

    struct BadKPI <: AbstractKPI end
    LithoWaferPlots.name(::BadKPI) = "Bad"
    # missing: compute

    @test !implements(BadKPI, AbstractKPI)
end

@testitem "Optional methods are not required" begin
    using LithoWaferPlots, TypeContracts

    struct MinimalKPI <: AbstractKPI end
    LithoWaferPlots.name(::MinimalKPI) = "Minimal"
    LithoWaferPlots.compute(::MinimalKPI, v::AbstractVector{<:Real})::Float64 = 0.0

    result = satisfies(MinimalKPI, AbstractKPI)
    @test result.satisfied == true
    @test !isempty(result.missing_optional)
end
