using Test
import Pluto: Notebook, Cell, updated_topology, static_resolve_topology, is_just_text, NotebookTopology

@testset "updated_topology identity" begin
    notebook = Notebook([
        Cell("x = 1")
        Cell("function f(x)
            x + 1
        end")
        Cell("a = x - 123")
        Cell("")
        Cell("")
        Cell("")
    ])
    
    empty_top = notebook.topology
    topo = updated_topology(empty_top, notebook, notebook.cells)
    # updated_topology should preserve the identity of the topology if nothing changed. This means that we can cache the result of other functions in our code!
    @test topo === updated_topology(topo, notebook, notebook.cells)
    @test topo === updated_topology(topo, notebook, Cell[])
    @test topo === static_resolve_topology(topo)
    
    # for n in fieldnames(NotebookTopology)
    #     @test getfield(topo, n) === getfield(top2a, n)
    # end
    
    setcode!(notebook.cells[1], "x = 999")
    topo_2 = updated_topology(topo, notebook, notebook.cells[1:1])
    @test topo_2 !== topo
    
    
    setcode!(notebook.cells[4], "@asdf 1 + 2")
    topo_3 = updated_topology(topo_2, notebook, notebook.cells[4:4])
    @test topo_3 !== topo_2
    @test topo_3 !== topo
    
    @test topo_3.unresolved_cells |> only === notebook.cells[4]
    
    @test topo_3 === updated_topology(topo_3, notebook, notebook.cells[1:3])
    @test topo_3 === updated_topology(topo_3, notebook, Cell[])
    # rerunning the cell with the macro does not change the topology because it was already unresolved
    @test topo_3 === updated_topology(topo_3, notebook, notebook.cells[1:4])
    
    # let's pretend that we resolved the macro in the 4th cell
    topo_3_resolved = NotebookTopology(;
        nodes=topo_3.nodes, 
        codes=topo_3.codes, 
        unresolved_cells=setdiff(topo_3.unresolved_cells, notebook.cells[4:4]),
        cell_order=topo_3.cell_order,
        disabled_cells=topo_3.disabled_cells,
    )
    
    @test topo_3_resolved === updated_topology(topo_3_resolved, notebook, notebook.cells[1:3])
    @test topo_3_resolved === updated_topology(topo_3_resolved, notebook, Cell[])
    # rerunning the cell with the macro makes it unresolved again
    @test topo_3_resolved !== updated_topology(topo_3_resolved, notebook, notebook.cells[1:4])
    
    notebook.cells[4] ∈ updated_topology(topo_3_resolved, notebook, notebook.cells[1:4]).unresolved_cells
    
    # @test topo_3 === static_resolve_topology(topo_3)
end
