module LithoWaferPlotsGLMakieExt

using GLMakie
using LithoWaferPlots
using PrecompileTools: @compile_workload

# Same rationale as `LithoWaferPlotsCairoMakieExt`: render once here so GLMakie's
# backend-specific draw/shader/screen dispatch for our recipe types compiles now
# instead of on a real user's first plot. Rendering needs an (offscreen) GL context,
# which isn't guaranteed on every machine that merely installs this package (headless
# CI without a GPU or Xvfb) — GLMakie's own `src/precompiles.jl` treats basic
# `colorbuffer`/`Screen` calls as safe, but wraps the riskier `display(...)` call in
# `try/catch`. We're more conservative: wrap the whole render in `try/catch` so a
# missing GL context degrades to "no extra warm-up" rather than a failed install.
@compile_workload begin
    try
        let wafer = LithoWaferPlots.WaferSpec(300.0),
                x = Float64[-80.0, 0.0, 80.0, 40.0, -40.0],
                y = Float64[-80.0, 0.0, 80.0, -40.0, 40.0],
                v = Float64[1.0, 2.0, 3.0, 2.0, 1.0],
                vx = Float64[0.1, -0.2, 0.3, -0.1, 0.2],
                vy = Float64[0.2, 0.1, -0.3, 0.2, -0.1]

            fields = field_grid([((c - 2) * 26.0, (r - 2) * 33.0) for r in 1:3, c in 1:3], (26.0, 33.0); wafer = wafer)
            sdata = WaferData((x = x, y = y, value = v), wafer; fields = fields)
            vdata = WaferVectorData((x = x, y = y, vx = vx, vy = vy), wafer; fields = fields)

            GLMakie.activate!()

            fig, ax, side = wafer_figure()
            waferheatmap!(ax, sdata)
            waferheatmap!(ax, sdata; imagemode = :image)
            waferscatter!(ax, sdata)
            wafercontour!(ax, sdata; grid_n = 16)
            colorbuffer(fig; px_per_unit = 1)

            fig2, ax2, side2 = wafer_figure()
            waferarrows!(ax2, vdata)
            waferarrows!(ax2, vdata; arrowcolor = :magnitude)
            waferstreamlines!(ax2, vdata; n_seeds = 2, max_steps = 5, grid_n = 16)
            waferdivergence!(ax2, vdata; grid_n = 16)
            wafervorticity!(ax2, vdata; grid_n = 16)
            colorbuffer(fig2; px_per_unit = 1)
        end
    catch
        # ponytail: no GL context available at precompile time (headless CI, no GPU);
        # skip the extra warm-up rather than fail the whole package install.
    end
end

end
