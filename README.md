# PlutoDependencyExplorer.jl

This package contains Pluto's dependency sorting algorithm. Given a list of cell codes, PlutoDependencyExplorer can tell you in which order these cells should run. For example:

```julia
julia> import PlutoDependencyExplorer as PDE

julia> struct SimpleCell <: PDE.AbstractCell
           code
       end

julia> notebook = SimpleCell.([
           "x + y"
           "x = 1"
           "y = x + 2"
       ]);

julia> empty_topology = PDE.NotebookTopology{SimpleCell}();

julia> topology = PDE.updated_topology(
           empty_topology,
           notebook, notebook;
           get_code_str = c -> c.code,
           get_code_expr = c -> Meta.parse(c.code),
       );

julia> order = PDE.topological_order(topology);

julia> order.runnable
3-element Vector{SimpleCell}:
 SimpleCell("x = 1")
 SimpleCell("y = x + 2")
 SimpleCell("x + y")
```

## ExpressionExplorer.jl

PlutoDependencyExplorer.jl uses the low-level package [ExpressionExplorer.jl](https://github.com/JuliaPluto/expressionexplorer.jl) to find the assignments and references of each cell. PlutoDependencyExplorer uses this information to build a dependency graph between cells (i.e. a `NotebookTopology`), which can be used to find the order to run them in (a `TopologicalOrder`).

If you are interested in **ordering a list of expressions** in execution order (the order that Pluto runs cells in), then use PlutoDependencyExplorer.jl. If you just want to know which variables are assigned or referenced in a **single expression**, use ExpressionExplorer.jl.

# Docs
Take a look at the [**Documentation →**](https://plutojl.org/en/docs/plutodependencyexplorer/)

# Contributing and testing

To work on this package, clone both the Pluto.jl and PlutoDependencyExplorer.jl repositories to your local drive. Then:

1. In your global environment, develop the Pluto and PlutoDependencyExplorer packages: 
    `(@1.10) pkg> dev ~/Documents/Pluto.jl`
    `(@1.10) pkg> dev ~/Documents/PlutoDependencyExplorer.jl`
2. You can now run or `Pkg.test()` Pluto, and it will use your local copy of PlutoDependencyExplorer.

### Advanced: making a change to Pluto and PlutoDependencyExplorer at the same time.

If you are working on a change to PlutoDependencyExplorer that requires a matching change in Pluto, then you open a branch/PR on both repositories. 

We need to tell PlutoDependencyExplorer which version of Pluto to use. To do this, edit the file `PlutoDependencyExplorer.jl/test/pluto integration/DEV EDIT ME pluto pkg source.jl`.


