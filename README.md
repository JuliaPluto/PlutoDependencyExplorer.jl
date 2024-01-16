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

# Contributing and testing

To work on this package, clone both the Pluto.jl and PlutoDependencyExplorer.jl repositories to your local drive. Then:

1. Enter the Pluto.jl package directory: `~ cd ~/Documents/Pluto.jl/`
2. Open Julia in this environment: `julia --project`
3. In the Pluto.jl package, develop the PlutoDependencyExplorer package: `(Pluto.jl) pkg> dev ~/Documents/PlutoDependencyExplorer.jl/`
4. Restart Julia. In your global environment, develop the Pluto.jl package `(@1.10) pkg> dev ~/Documents/Pluto.jl`
5. Also develop: `(@1.10) pkg> dev ~/Documents/PlutoDependencyExplorer.jl`
6. You can now run or test Pluto, and it will use your local copy of PlutoDependencyExplorer.
