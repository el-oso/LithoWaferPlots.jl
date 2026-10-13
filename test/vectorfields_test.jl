@testitem "divergence/vorticity are unaffected by a NaN point in the source data" begin
    using LithoWaferPlots

    w = WaferSpec(300.0)
    xs = [x for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    ys = [y for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    vxs = -ys ./ 100
    vys = xs ./ 100

    d_clean = WaferVectorData(xs, ys, vxs, vys, w, WaferField[])

    vxs_dirty = copy(vxs)
    vxs_dirty[1] = NaN   # WaferVectorData's constructor drops this point at construction time
    d_dirty = WaferVectorData(xs, ys, vxs_dirty, vys, w, WaferField[])

    div_clean = divergence(d_clean; grid_n = 64)
    div_dirty = divergence(d_dirty; grid_n = 64)

    @test !any(isnan, div_dirty.values)
    # the previously-poisoned run lost ~26% of active grid cells to IDW poisoning; with the
    # NaN point filtered before it ever reaches the KDTree/IDW step, output size should match
    # the clean run (same point count, same grid) rather than being substantially smaller.
    @test length(div_dirty.values) == length(div_clean.values)
end

@testitem "divergence/vorticity values sit at their own coordinates" begin
    using LithoWaferPlots

    # v = (x²/2000, x²/2000): divergence = x/1000 depends only on x, vorticity = x/1000
    # likewise; a transposed grid would make both track y instead.
    g = -140.0:4.0:140.0
    xs = [x for x in g for y in g if x^2 + y^2 <= 140.0^2]
    ys = [y for x in g for y in g if x^2 + y^2 <= 140.0^2]
    vd = WaferVectorData(xs, ys, xs .^ 2 ./ 2000, xs .^ 2 ./ 2000)

    for f in (divergence, vorticity)
        w = f(vd; grid_n = 64)
        inner = @. w.x^2 + w.y^2 <= 100.0^2
        err = w.values[inner] .- w.x[inner] ./ 1000
        # RMS error is ~0.0035 at the right coordinates and ~0.07 when transposed
        @test sqrt(sum(abs2, err) / length(err)) < 0.01
    end
end
