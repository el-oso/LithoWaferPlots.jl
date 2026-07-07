module LithoWaferPlotsCairoMakieExt

using CairoMakie
using LithoWaferPlots
using PrecompileTools: @compile_workload

# The main `LithoWaferPlotsMakieExt` precompiles recipe *construction* (backend-agnostic:
# attribute setup, ComputePipeline graphs) but never renders a frame, since it only
# weak-deps on abstract `Makie`, never a concrete backend. Backend-specific draw dispatch
# (e.g. CairoMakie's `draw_atomic_*` for our recipe types) only compiles once a concrete
# backend actually renders them — this extension does that render, once, at precompile
# time, matching the pattern CairoMakie's own `src/precompiles.jl` uses
# (`Makie.colorbuffer(figlike)`, no display/window needed, safe in headless CI).
@compile_workload begin
    let wafer = LithoWaferPlots.WaferSpec(300.0),
            x = Float64[-80.0, 0.0, 80.0, 40.0, -40.0],
            y = Float64[-80.0, 0.0, 80.0, -40.0, 40.0],
            v = Float64[1.0, 2.0, 3.0, 2.0, 1.0],
            vx = Float64[0.1, -0.2, 0.3, -0.1, 0.2],
            vy = Float64[0.2, 0.1, -0.3, 0.2, -0.1]

        fields = field_grid([((c - 2) * 26.0, (r - 2) * 33.0) for r in 1:3, c in 1:3], (26.0, 33.0); wafer = wafer)
        sdata = WaferData((x = x, y = y, value = v), wafer; fields = fields)
        vdata = WaferVectorData((x = x, y = y, vx = vx, vy = vy), wafer; fields = fields)

        CairoMakie.activate!()

        fig, ax, side = wafer_figure()
        waferheatmap!(ax, sdata)
        waferheatmap!(ax, sdata; imagemode = :image)
        waferscatter!(ax, sdata)
        wafercontour!(ax, sdata; grid_n = 16)
        colorbuffer(fig)

        fig2, ax2, side2 = wafer_figure()
        waferarrows!(ax2, vdata)
        waferarrows!(ax2, vdata; arrowcolor = :magnitude)
        waferstreamlines!(ax2, vdata; n_seeds = 2, max_steps = 5, grid_n = 16)
        waferdivergence!(ax2, vdata; grid_n = 16)
        wafervorticity!(ax2, vdata; grid_n = 16)
        colorbuffer(fig2)
    end
end

end
