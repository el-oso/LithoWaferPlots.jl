using Documenter
using DocumenterVitepress
using LithoWaferPlots
using PkgBenchmark

# ── Run benchmarks and write the report embedded by performance.md ──────────────
# Set LWP_BENCHMARKS=false to skip (fast local builds); a placeholder is written so
# the @eval embed in performance.md always finds a file.

const GEN = joinpath(@__DIR__, "generated")
mkpath(GEN)
const REPORT = joinpath(GEN, "benchmark_report.md")

# The DocumenterVitepress markdown writer renders every embedded heading as an H1
# regardless of level, which pollutes the page ToC. Convert the report's headings to
# bold paragraphs so the fragment nests cleanly under the page's section. Code fences
# (e.g. the versioninfo block) are left untouched.
function flatten_headings(md::AbstractString)
    infence = false
    return join(
        map(split(md, '\n'; keepempty = true)) do ln
            startswith(ln, "```") && (infence = !infence)
            m = (!infence) ? match(r"^#{1,6}\s+(.*)$", ln) : nothing
            # Trailing newline keeps the bold line a standalone paragraph so it does
            # not merge with the description text that follows a heading.
            m === nothing ? ln : "**$(m.captures[1])**\n"
        end,
        '\n'
    )
end

if get(ENV, "LWP_BENCHMARKS", "true") == "true"
    @info "Running PkgBenchmark suite for documentation…"
    script = abspath(joinpath(@__DIR__, "..", "benchmarks", "benchmarks.jl"))
    results = benchmarkpkg("LithoWaferPlots"; script = script)
    open(REPORT, "w") do io
        print(io, flatten_headings(sprint(export_markdown, results)))
    end
    @info "Benchmark report written to $REPORT"
else
    @info "LWP_BENCHMARKS=false — skipping benchmarks, writing placeholder."
    write(REPORT, "_Benchmarks were skipped in this build (`LWP_BENCHMARKS=false`)._\n")
end

makedocs(;
    modules = [LithoWaferPlots],
    sitename = "LithoWaferPlots.jl",
    authors = "el_oso",
    format = DocumenterVitepress.MarkdownVitepress(
        devbranch = "master",
        devurl = "dev",
        repo = "github.com/el-oso/LithoWaferPlots.jl",
        sidebar_drawer = true
    ),
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Gallery" => "gallery.md",
        "Interactive" => "interactive.md",
        "Custom KPIs" => "custom_kpi.md",
        "AlgebraOfGraphics" => "aog_compositing.md",
        "Performance" => "performance.md",
        "API Reference" => "api.md",
    ],
    checkdocs = :exports,
    warnonly = [:missing_docs],
    remotes = nothing,
    doctest = false,
)

DocumenterVitepress.deploydocs(;
    repo = "github.com/el-oso/LithoWaferPlots.jl",
    devbranch = "master",
    push_preview = true,
)
