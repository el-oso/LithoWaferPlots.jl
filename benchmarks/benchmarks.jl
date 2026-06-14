"""
LithoWaferPlots benchmark suite for PkgBenchmark.jl.

Run from the package root:

    julia --project=. -e '
        using PkgBenchmark
        results = benchmarkpkg(LithoWaferPlots)
        export_markdown(stdout, results)
    '

Compare two commits for regressions:

    baseline = benchmarkpkg(LithoWaferPlots, "main")
    current  = benchmarkpkg(LithoWaferPlots)
    export_markdown(stdout, judge(current, baseline))

Groups
------
  compute/  — backend-independent Julia computation (masking, colour scaling,
               vector-field analysis, KPIs). Runs with CairoMakie (CPU).
  render/   — full plot construction through CairoMakie (CPU rasteriser).
               GPU rendering (GLMakie) is measured separately in render_bench.jl.
"""

using BenchmarkTools
using LithoWaferPlots
using CairoMakie

const SUITE = BenchmarkGroup()

# ── shared test data ──────────────────────────────────────────────────────────
# Use a moderate N that is representative but fast enough for CI.

const _N = 50_000
const _WAFER = WaferSpec(300.0)

let
    θ = LinRange(0, 2π, _N)
    r = sqrt.(LinRange(0, 1, _N)) .* 148.0
    _x = r .* cos.(θ)
    _y = r .* sin.(θ)
    _v = sin.(_x ./ 30) .+ cos.(_y ./ 30)

    _vx = -_y ./ 80
    _vy = _x ./ 80

    global const SDATA = WaferData((x = _x, y = _y, value = _v), _WAFER)
    global const VDATA = WaferVectorData((x = _x, y = _y, vx = _vx, vy = _vy), _WAFER)
end

# ── compute group ─────────────────────────────────────────────────────────────

SUITE["compute"] = BenchmarkGroup(["compute"])

SUITE["compute"]["inside_wafer"] = @benchmarkable inside_wafer(
    $SDATA.x, $SDATA.y, $_WAFER
)

SUITE["compute"]["colorscale"] = @benchmarkable ColorScale($SDATA.values)

SUITE["compute"]["normalize"] = @benchmarkable normalize(
    ColorScale($SDATA.values), $SDATA.values
)

SUITE["compute"]["divergence_256"] = @benchmarkable divergence($VDATA; grid_n = 256)

SUITE["compute"]["vorticity_256"] = @benchmarkable vorticity($VDATA; grid_n = 256)

SUITE["compute"]["kpi_panel"] = @benchmarkable(
    [compute(k, $SDATA.values) for k in DEFAULT_KPIS]
)

# ── render group (CairoMakie, CPU) ────────────────────────────────────────────
# Render benchmarks build full Makie figures, so each is capped (seconds/samples/evals)
# to keep the documentation build — which runs this suite — within a few minutes.

SUITE["render"] = BenchmarkGroup(["render"])

SUITE["render"]["waferscatter"] = @benchmarkable(
    begin
        fig, ax, side = wafer_figure()
        waferscatter!(ax, $SDATA)
        fig
    end,
    seconds = 2.0, samples = 30, evals = 1
)

SUITE["render"]["waferheatmap"] = @benchmarkable(
    begin
        fig, ax, side = wafer_figure()
        waferheatmap!(ax, $SDATA)
        fig
    end,
    seconds = 2.0, samples = 30, evals = 1
)

SUITE["render"]["waferheatmap_image"] = @benchmarkable(
    begin
        fig, ax, side = wafer_figure()
        waferheatmap!(ax, $SDATA; imagemode = :image)
        fig
    end,
    seconds = 2.0, samples = 30, evals = 1
)

SUITE["render"]["wafercontour"] = @benchmarkable(
    begin
        fig, ax, side = wafer_figure()
        wafercontour!(ax, $SDATA)
        fig
    end,
    seconds = 2.0, samples = 30, evals = 1
)

SUITE["render"]["waferarrows"] = @benchmarkable(
    begin
        fig, ax, side = wafer_figure()
        waferarrows!(ax, $VDATA)
        fig
    end,
    seconds = 2.0, samples = 30, evals = 1
)

SUITE["render"]["waferstreamlines"] = @benchmarkable(
    begin
        fig, ax, side = wafer_figure()
        waferstreamlines!(ax, $VDATA; n_seeds = 15)
        fig
    end,
    seconds = 2.0, samples = 30, evals = 1
)

SUITE["render"]["waferdivergence"] = @benchmarkable(
    begin
        fig, ax, side = wafer_figure()
        waferdivergence!(ax, $VDATA)
        fig
    end,
    seconds = 2.0, samples = 30, evals = 1
)

SUITE["render"]["wafervorticity"] = @benchmarkable(
    begin
        fig, ax, side = wafer_figure()
        wafervorticity!(ax, $VDATA)
        fig
    end,
    seconds = 2.0, samples = 30, evals = 1
)
