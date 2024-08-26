###############################################################################
# How to run this file locally:
# In the docs/ directory:
# julia --color=yes --project make.jl
###############################################################################

using Documenter
using DocumenterMermaid
using MPOPF

makedocs(
    sitename = "MPOPF Documentation",
    format = Documenter.HTML(),
    modules = [MPOPF],
    pages = [
        "Home" => "index.md",
        "Class Diagram" => "class_diagram.md",
        "Getting Started" => "getting_started.md",
        "Background" => "background.md",
        "Implementation Details" => "implementation_details.md",
        "Approximation Techniques" => "approximation.md",
        "Future Development" => "future_development.md",
        "Design Philosophy" => "design_philosophy.md",
        "API Reference" => "api.md"
    ]
)

deploydocs(
    repo = "github.com/Maxim-Ciobanu/OPF.git",
    devbranch = "Documentation"
)