"""
LithoWaferPlots rendering benchmarks.

Target: all plot types render 300 000 points in < 0.3s (median).
Run with GLMakie for GPU-accelerated results.

    julia --project=.. benchmarks/render_bench.jl
"""

using LithoWaferPlots
using GLMakie
using BenchmarkTools
using Statistics

GLMakie.activate!(; visible=false)

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
    x  = r .* cos.(θ)
    y  = r .* sin.(θ)
    vx = -y ./ 80
    vy =  x ./ 80
    return WaferVectorData(x, y, vx, vy, WAFER, WaferField[])
end

println("Generating data ($N points)...")
scalar_data = make_scalar_data(N)
vector_data = make_vector_data(N)
println("Done.\n")

function bench_plot(label, fn)
    # warm-up
    fn()
    GC.gc()
    b = @benchmark $fn() samples=5 evals=1
    med = median(b).time / 1e9
    status = med < 0.3 ? "✓ PASS" : "✗ FAIL"
    @printf "%-30s  median = %.3fs  %s\n" label med status
    return med
end

println("=== Benchmark results ===\n")

results = Dict{String,Float64}()

results["WaferScatter"] = bench_plot("WaferScatter (300K pts)") do
    fig, ax, _ = wafer_figure()
    waferscatter!(ax, scalar_data)
    display(fig)
    nothing
end

results["WaferHeatmap"] = bench_plot("WaferHeatmap (300K pts)") do
    fig, ax, _ = wafer_figure()
    waferheatmap!(ax, scalar_data)
    display(fig)
    nothing
end

results["WaferArrows"] = bench_plot("WaferArrows (300K pts)") do
    fig, ax, _ = wafer_figure()
    waferarrows!(ax, vector_data)
    display(fig)
    nothing
end

results["WaferStreamlines"] = bench_plot("WaferStreamlines (300K pts)") do
    fig, ax, _ = wafer_figure()
    waferstreamlines!(ax, vector_data; n_seeds=15)
    display(fig)
    nothing
end

results["WaferDivergence"] = bench_plot("WaferDivergence (300K pts)") do
    fig, ax, _ = wafer_figure()
    waferdivergence!(ax, vector_data)
    display(fig)
    nothing
end

results["WaferVorticity"] = bench_plot("WaferVorticity (300K pts)") do
    fig, ax, _ = wafer_figure()
    wafervorticity!(ax, vector_data)
    display(fig)
    nothing
end

println()
all_pass = all(v < 0.3 for v in values(results))
println(all_pass ? "All benchmarks passed." : "Some benchmarks exceeded 0.3s target.")
