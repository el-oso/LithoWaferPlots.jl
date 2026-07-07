module LithoWaferPlotsWGLMakieExt

using WGLMakie
using Bonito
using Makie
using LithoWaferPlots
using PrecompileTools: @compile_workload

# Same rationale as the CairoMakie/GLMakie extensions, but WGLMakie renders to a browser
# over a websocket session rather than a local canvas, so there's no `colorbuffer(fig)`
# to call — a real browser isn't guaranteed to be attached during precompilation. Instead
# we build the DOM/session payload and serialize it, matching WGLMakie's own
# `src/precompiles.jl` idiom exactly (`Bonito.session_dom` + `show(IOBuffer(), dom)`,
# never opening a real connection), which compiles the JS-serialization dispatch for our
# recipe types without needing a browser.
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

        WGLMakie.activate!()

        fig, ax, side = wafer_figure()
        waferheatmap!(ax, sdata)
        waferheatmap!(ax, sdata; imagemode = :image)
        waferscatter!(ax, sdata)
        wafercontour!(ax, sdata; grid_n = 16)

        fig2, ax2, side2 = wafer_figure()
        waferarrows!(ax2, vdata)
        waferarrows!(ax2, vdata; arrowcolor = :magnitude)
        waferstreamlines!(ax2, vdata; n_seeds = 2, max_steps = 5, grid_n = 16)
        waferdivergence!(ax2, vdata; grid_n = 16)
        wafervorticity!(ax2, vdata; grid_n = 16)

        for figlike in (fig, fig2)
            session = Session()
            app = App(() -> Bonito.DOM.div(figlike))
            dom = Bonito.session_dom(session, app)
            show(IOBuffer(), dom)
            close(session)
            yield()
        end
        # `__init__` doesn't run during precompilation, so any server/session/task state
        # left behind above must be torn down explicitly here or precompilation hangs
        # waiting for it — matches WGLMakie's own `src/precompiles.jl` cleanup exactly.
        Bonito.cleanup_globals()
        Makie.cleanup_globals()
    end
end

end
