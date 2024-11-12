import ExpressionExplorer

"""
```julia
external_package_names(topology::NotebookTopology)::Set{Symbol}
```

Get the set of package names that are imported by any cell in the notebook. This considers all `using` and `import` calls.
"""
function ExpressionExplorer.external_package_names(topology::NotebookTopology)::Set{Symbol}
    union!(Set{Symbol}(), ExpressionExplorer.external_package_names.(c.module_usings_imports for c in values(topology.codes))...)
end
