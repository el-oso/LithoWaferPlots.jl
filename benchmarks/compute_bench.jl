"""
LithoWaferPlots computation benchmarks (backend-independent).

Measures the Julia-side work: masking, colour normalisation, IDW interpolation,
divergence/vorticity, KPI computation.  These run with any Makie backend
(CairoMakie, GLMakie, WGLMakie) and are suitable for CI.

GPU rendering latency is measured separately in render_bench.jl (GLMakie only).

    julia --project=. benchmarks/compute_bench.jl
"""

using LithoWaferPlots
using CairoMakie
using BenchmarkTools
using Printf

const N = 300_000
const WAFER = WaferSpec(300.0)

function make_scalar_data(n)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 148.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    v = sin.(x ./ 30) .+ cos.(y ./ 30) .+ 0.1 .* randn(n)
    return WaferData(x, y, v, WAFER, WaferField[])
end

function make_vector_data(n)
    θ = rand(n) .* 2π
    r = sqrt.(rand(n)) .* 120.0
    x = r .* cos.(θ)
    y = r .* sin.(θ)
    vx = -y ./ 80
    vy = x ./ 80
    return WaferVectorData(x, y, vx, vy, WAFER, WaferField[])
end

function bench(label::String, target_s::Float64, fn)
    fn()
    GC.gc()
    b = @benchmark $fn() samples = 5 evals = 1
    med = median(b).time / 1.0e9
    status = med < target_s ? "PASS" : "FAIL"
    @printf "%-40s  median = %6.3fs  [%s]\n" label med status
    return med
end

println("Generating data ($N points)...")
sdata = make_scalar_data(N)
vdata = make_vector_data(N)
println("Done.\n")

println("=== Computation benchmarks (CairoMakie, CPU) ===\n")

results = Dict{String, Float64}()

results["inside_wafer mask (300K)"] = bench(
    "inside_wafer mask (300K)", 0.05,
    () -> inside_wafer(sdata.x, sdata.y, WAFER)
)

results["ColorScale + normalize (300K)"] = bench(
    "ColorScale + normalize (300K)", 0.05,
    () -> (cs = ColorScale(sdata.values); normalize(cs, sdata.values))
)

results["divergence grid (256×256)"] = bench(
    "divergence grid (256×256)", 5.0,
    () -> divergence(vdata; grid_n = 256)
)

results["vorticity grid (256×256)"] = bench(
    "vorticity grid (256×256)", 5.0,
    () -> vorticity(vdata; grid_n = 256)
)

results["KPI panel (6 KPIs, 300K)"] = bench(
    "KPI panel (6 KPIs, 300K)", 0.05,
    () -> [compute(k, sdata.values) for k in DEFAULT_KPIS]
)

println()
targets = Dict(
    "inside_wafer mask (300K)" => 0.05,
    "ColorScale + normalize (300K)" => 0.05,
    "divergence grid (256×256)" => 5.0,
    "vorticity grid (256×256)" => 5.0,
    "KPI panel (6 KPIs, 300K)" => 0.05,
)
all_pass = all(results[lbl] < t for (lbl, t) in targets)
println(all_pass ? "All compute benchmarks passed." : "Some benchmarks exceeded targets.")
println()
println("Note: render_bench.jl (GLMakie) measures the GPU rendering path.")
println("      The < 0.3s target applies to GLMakie scatter/heatmap on GPU.")
