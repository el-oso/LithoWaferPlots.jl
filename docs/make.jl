using Documenter
using DocumenterVitepress
using LithoWaferPlots

makedocs(;
    modules  = [LithoWaferPlots],
    sitename = "LithoWaferPlots.jl",
    authors  = "el_oso",
    format   = DocumenterVitepress.MarkdownVitepress(
        repo = "github.com/el-oso/LithoWaferPlots.jl",
    ),
    pages = [
        "Home"            => "index.md",
        "Getting Started" => "getting_started.md",
        "Custom KPIs"     => "custom_kpi.md",
        "Performance"     => "performance.md",
        "API Reference"   => "api.md",
    ],
    warnonly = [:missing_docs],
)
