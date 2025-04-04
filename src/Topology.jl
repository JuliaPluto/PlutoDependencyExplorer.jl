import ExpressionExplorer: UsingsImports, SymbolsState

"A container for the result of parsing the cell code, with some extra metadata."
Base.@kwdef struct ExprAnalysisCache
    code::String=""
    parsedcode::Expr=Expr(:toplevel, LineNumberNode(1), Expr(:block))
    module_usings_imports::UsingsImports = UsingsImports()
    function_wrapped::Bool=false
    forced_expr_id::Union{UInt,Nothing}=nothing
end

function ExprAnalysisCache(code_str::String, parsedcode::Expr)
    ExprAnalysisCache(;
        code=code_str,
        parsedcode,
        module_usings_imports=ExpressionExplorer.compute_usings_imports(parsedcode),
        function_wrapped=ExpressionExplorerExtras.can_be_function_wrapped(parsedcode),
    )
end

function ExprAnalysisCache(old_cache::ExprAnalysisCache; new_properties...)
    properties = Dict{Symbol,Any}(field => getproperty(old_cache, field) for field in fieldnames(ExprAnalysisCache))
    merge!(properties, Dict{Symbol,Any}(new_properties))
    ExprAnalysisCache(;properties...)
end

"""
The (information needed to create the) dependency graph of a notebook. Cells are linked by the names of globals that they define and reference. 🕸

`NotebookTopology` is an immutable structure. In Pluto's case, where the notebook is constantly changing (being edited), it functions as a *snapshot* of the notebook's reactive state at a current time.

This also means that the `NotebookTopology` cannot be mutated to reflect changes in the notebook. This is done by the `update_topology` function, which takes an old topology and calculates the next one.

# Fields
- `nodes` is really the **dependency graph**. For each cell, it stores the dependency links.
- `codes` is a snapshot of the cell codes at the time when the `topology` was calculated, including some metadata that is used by Pluto.
- `cell_order` is a snapshot of the cell order at the time when the `topology` was calculated.
- `unresolved_cells` contains cells that still have unresolved macro calls
- `disabled_cells` contains cells that are disabled (used by Pluto)
"""
Base.@kwdef struct NotebookTopology{C <: AbstractCell}
    nodes::ImmutableDefaultDict{C,ReactiveNode}=ImmutableDefaultDict{C,ReactiveNode}(ReactiveNode)
    codes::ImmutableDefaultDict{C,ExprAnalysisCache}=ImmutableDefaultDict{C,ExprAnalysisCache}(ExprAnalysisCache)
    cell_order::ImmutableVector{C}=ImmutableVector{C}()

    unresolved_cells::ImmutableSet{C} = ImmutableSet{C}()
    disabled_cells::ImmutableSet{C} = ImmutableSet{C}()
end

# BIG TODO HERE: CELL ORDER
all_cells(topology::NotebookTopology) = topology.cell_order.c

is_resolved(topology::NotebookTopology) = isempty(topology.unresolved_cells)
is_resolved(topology::NotebookTopology, c::AbstractCell) = c in topology.unresolved_cells

is_disabled(topology::NotebookTopology, c::AbstractCell) = c in topology.disabled_cells

function set_unresolved(topology::NotebookTopology{C}, unresolved_cells::Vector{C}) where C <: AbstractCell
    codes = Dict{C,ExprAnalysisCache}(
        cell => ExprAnalysisCache(topology.codes[cell]; function_wrapped=false, forced_expr_id=nothing)
        for cell in unresolved_cells
    )
    NotebookTopology{C}(
        nodes=topology.nodes,
        codes=merge(topology.codes, codes),
        unresolved_cells=union(topology.unresolved_cells, unresolved_cells),
        cell_order=topology.cell_order,
        disabled_cells=topology.disabled_cells,
    )
end


"""
    exclude_roots(topology::NotebookTopology, roots_to_exclude)::NotebookTopology

Returns a new topology as if `topology` was created with all code for `roots_to_exclude`
being empty, preserving disabled cells and cell order.
"""
function exclude_roots(topology::NotebookTopology{C}, cells::Vector{C}) where C <: AbstractCell
    isempty(cells) ? topology : NotebookTopology{C}(
        nodes=setdiffkeys(topology.nodes, cells),
        codes=setdiffkeys(topology.codes, cells),
        unresolved_cells=ImmutableSet{C}(setdiff(topology.unresolved_cells.c, cells); skip_copy=true),
        cell_order=topology.cell_order,
        disabled_cells=topology.disabled_cells,
    )
end
