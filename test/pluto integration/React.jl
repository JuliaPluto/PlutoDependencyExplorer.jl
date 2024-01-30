using Test
import Pluto: Configuration, Notebook, ServerSession, ClientSession, update_run!, Cell, WorkspaceManager
import Pluto.Configuration: Options, EvaluationOptions


import PlutoDependencyExplorer: CyclicReferenceError, MultipleDefinitionsError

order_to_run(notebook, id::Integer) = order_to_run(notebook, [id])
function order_to_run(notebook, idx)
    topo_order = Pluto.topological_order(notebook.topology, notebook.cells[idx])
    indexin(topo_order.runnable, notebook.cells)
end


@testset "Reactivity" begin
    🍭 = ServerSession()
    🍭.options.evaluation.workspace_use_distributed = false

    @testset "Mutliple assignments" begin
        notebook = Notebook([
            Cell("x = 1"),
            Cell("x = 2"),
            Cell("f(x) = 3"),
            Cell("f(x) = 4"),
            Cell("g(x) = 5"),
            Cell("g = 6"),
        ])
    

        update_run!(🍭, notebook, notebook.cells[1])
        update_run!(🍭, notebook, notebook.cells[2])
        @test occursinerror("Multiple", notebook.cells[1])
        @test occursinerror("Multiple", notebook.cells[2])
    
        setcode!(notebook.cells[1], "")
        update_run!(🍭, notebook, notebook.cells[1])
        @test notebook.cells[1] |> noerror
        @test notebook.cells[2] |> noerror
    
    # https://github.com/fonsp/Pluto.jl/issues/26
        setcode!(notebook.cells[1], "x = 1")
        update_run!(🍭, notebook, notebook.cells[1])
        setcode!(notebook.cells[2], "x")
        update_run!(🍭, notebook, notebook.cells[2])
        @test notebook.cells[1] |> noerror
        @test notebook.cells[2] |> noerror

        update_run!(🍭, notebook, notebook.cells[3])
        update_run!(🍭, notebook, notebook.cells[4])
        @test occursinerror("Multiple", notebook.cells[3])
        @test occursinerror("Multiple", notebook.cells[4])
    
        setcode!(notebook.cells[3], "")
        update_run!(🍭, notebook, notebook.cells[3])
        @test notebook.cells[3] |> noerror
        @test notebook.cells[4] |> noerror
    
        update_run!(🍭, notebook, notebook.cells[5])
        update_run!(🍭, notebook, notebook.cells[6])
        @test occursinerror("Multiple", notebook.cells[5])
        @test occursinerror("Multiple", notebook.cells[6])
    
        setcode!(notebook.cells[5], "")
        update_run!(🍭, notebook, notebook.cells[5])
        @test notebook.cells[5] |> noerror
        @test notebook.cells[6] |> noerror

        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)
    end

    @testset "Mutliple assignments topology" begin
        notebook = Notebook([
            Cell("x = 1"),
            Cell("z = 4 + y"),
            Cell("y = x + 2"),
            Cell("y = x + 3"),
        ])
        notebook.topology = Pluto.updated_topology(notebook.topology, notebook, notebook.cells)

        let topo_order = Pluto.topological_order(notebook.topology, notebook.cells[[1]])
            @test indexin(topo_order.runnable, notebook.cells) == [1,2]
            @test topo_order.errable |> keys == notebook.cells[[3,4]] |> Set
        end
        let topo_order = Pluto.topological_order(notebook.topology, notebook.cells[[1]], allow_multiple_defs=true)
            @test indexin(topo_order.runnable, notebook.cells) == [1,3,4,2] # x first, y second and third, z last
            # this also tests whether multiple defs run in page order
            @test topo_order.errable == Dict()
        end
    end

    @testset "Simple insert cell" begin
        notebook = Notebook(Cell[])
        update_run!(🍭, notebook, notebook.cells)

        insert_cell!(notebook, Cell("a = 1"))
        update_run!(🍭, notebook, notebook.cells[begin])

        insert_cell!(notebook, Cell("b = 2"))
        update_run!(🍭, notebook, notebook.cells[begin+1])

        insert_cell!(notebook, Cell("c = 3"))
        update_run!(🍭, notebook, notebook.cells[begin+2])

        insert_cell!(notebook, Cell("a + b + c"))
        update_run!(🍭, notebook, notebook.cells[begin+3])

        @test notebook.cells[begin+3].output.body == "6"

        setcode!(notebook.cells[begin+1], "b = 10")
        update_run!(🍭, notebook, notebook.cells[begin+1])

        @test notebook.cells[begin+3].output.body == "14"
    end

    @testset "Simple delete cell" begin
        notebook = Notebook(Cell.([
            "x = 42",
            "x",
        ]))
        update_run!(🍭, notebook, notebook.cells)

        @test all(noerror, notebook.cells)

        delete_cell!(notebook, notebook.cells[begin])
        @test length(notebook.cells) == 1

        update_run!(🍭, notebook, Cell[])

        @test expecterror(UndefVarError(:x), notebook.cells[begin])
    end

    @testset ".. as an identifier" begin
        notebook = Notebook(Cell.([
           ".. = 1",
           "..",
        ]))
        update_run!(🍭, notebook, notebook.cells)

        @test all(noerror, notebook.cells)
        @test notebook.cells[end].output.body == "1"
    end

    @testset "Pkg topology workarounds" begin
        notebook = Notebook([
            Cell("1 + 1"),
            Cell("json([1,2])"),
            Cell("using JSON"),
            Cell("""Pkg.add("JSON")"""),
            Cell("Pkg.activate(mktempdir())"),
            Cell("import Pkg"),
            Cell("using Revise"),
            Cell("1 + 1"),
        ])
        notebook.topology = Pluto.updated_topology(notebook.topology, notebook, notebook.cells)

        topo_order = Pluto.topological_order(notebook.topology, notebook.cells)
        @test indexin(topo_order.runnable, notebook.cells) == [6, 5, 4, 7, 3, 1, 2, 8]
        # 6, 5, 4, 3 should run first (this is implemented using `cell_precedence_heuristic`), in that order
        # 1, 2, 7 remain, and should run in notebook order.

        # if the cells were placed in reverse order...
        reverse!(notebook.cell_order)
        topo_order = Pluto.topological_order(notebook.topology, notebook.cells)
        @test indexin(topo_order.runnable, reverse(notebook.cells)) == [6, 5, 4, 7, 3, 8, 2, 1]
        # 6, 5, 4, 3 should run first (this is implemented using `cell_precedence_heuristic`), in that order
        # 1, 2, 7 remain, and should run in notebook order, which is 7, 2, 1.

        reverse!(notebook.cell_order)
    end

    @testset "Pkg topology workarounds -- hard" begin
        notebook = Notebook([
            Cell("json([1,2])"),
            Cell("using JSON"),
            Cell("Pkg.add(package_name)"),
            Cell(""" package_name = "JSON" """),
            Cell("Pkg.activate(envdir)"),
            Cell("envdir = mktempdir()"),
            Cell("import Pkg"),
            Cell("using JSON3, Revise"),
        ])

        notebook.topology = Pluto.updated_topology(notebook.topology, notebook, notebook.cells)

        topo_order = Pluto.topological_order(notebook.topology, notebook.cells)

        comesbefore(A, first, second) = findfirst(isequal(first),A) < findfirst(isequal(second), A)

        run_order = indexin(topo_order.runnable, notebook.cells)

        # like in the previous test
        @test comesbefore(run_order, 7, 5)
        @test_broken comesbefore(run_order, 5, 3)
        @test_broken comesbefore(run_order, 3, 2)
        @test comesbefore(run_order, 2, 1)
        @test comesbefore(run_order, 8, 2)
        @test comesbefore(run_order, 8, 1)

        # the variable dependencies
        @test comesbefore(run_order, 6, 5)
        @test comesbefore(run_order, 4, 3)
    end

    @testset "Mixed usings and reactivity" begin
        notebook = Notebook([
            Cell("a; using Dates"),
            Cell("isleapyear(2)"),
            Cell("a = 3; using LinearAlgebra"),
        ])

        notebook.topology = Pluto.updated_topology(notebook.topology, notebook, notebook.cells)
        topo_order = Pluto.topological_order(notebook.topology, notebook.cells)
        run_order = indexin(topo_order.runnable, notebook.cells)

        @test run_order == [3, 1, 2]
    end

    @testset "Function dependencies" begin
        🍭.options.evaluation.workspace_use_distributed = true

        notebook = Notebook(Cell.([
            "a'b",
            "import LinearAlgebra",
            "LinearAlgebra.conj(b::Int) = 2b",
            "a = 10",
            "b = 10",
        ]))

        update_run!(🍭, notebook, notebook.cells)

        @test :conj ∈ notebook.topology.nodes[notebook.cells[3]].soft_definitions
        @test :conj ∈ notebook.topology.nodes[notebook.cells[1]].references
        @test notebook.cells[1].output.body == "200"

        WorkspaceManager.unmake_workspace((🍭, notebook))
        🍭.options.evaluation.workspace_use_distributed = false
    end

    @testset "Function use inv in its def but also has a method on inv" begin
        notebook = Notebook(Cell.([
            """
            struct MyStruct
                s

                MyStruct(x) = new(inv(x))
            end
            """,
            """
            Base.inv(s::MyStruct) = inv(s.s)
            """,
            "MyStruct(1.) |> inv"
        ]))
        cell(idx) = notebook.cells[idx]
        update_run!(🍭, notebook, notebook.cells)

        @test cell(1) |> noerror
        @test cell(2) |> noerror
        @test cell(3) |> noerror

        # Empty and run cells to remove the Base overloads that we created, just to be sure
        setcode!.(notebook.cells, [""])
        update_run!(🍭, notebook, notebook.cells)

        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)
    end
    
    @testset "multiple cells cycle" begin
        notebook = Notebook(Cell.([
            "a = inv(1)",
            "b = a",
            "c = b",
            "Base.inv(x::Float64) = a",
            "d = Float64(c)",
        ]))
        update_run!(🍭, notebook, notebook.cells)

        @test noerror(notebook.cells[1])
        @test noerror(notebook.cells[2])
        @test noerror(notebook.cells[3])
        @test noerror(notebook.cells[4])
        @test noerror(notebook.cells[5])
        @test notebook.cells[end].output.body == "1.0" # a
    end

    @testset "one cell in two different cycles where one is not a real cycle" begin
        notebook = Notebook(Cell.([
            "x = inv(1) + z",
            "y = x",
            "z = y",
            "Base.inv(::Float64) = y",
            "inv(1.0)",
        ]))
        update_run!(🍭, notebook, notebook.cells)

        @test notebook.cells[end].errored == true
        @test occursinerror("Cyclic", notebook.cells[1])
        @test expecterror(UndefVarError(:y), notebook.cells[end]) # this is an UndefVarError and not a CyclicError

        setcode!.(notebook.cells, [""])
        update_run!(🍭, notebook, notebook.cells)
        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)
    end

    @testset "Two inter-twined cycles" begin
        notebook = Notebook(Cell.([
            """
            begin
                struct A
                    x
                    A(x) = A(inv(x))
                end
                rand()
            end
            """,
            "Base.inv(::A) = A(1)",
            """
            struct B
                x
                B(x) = B(inv(x))
            end
            """,
            "Base.inv(::B) = B(1)",
        ]))
        update_run!(🍭, notebook, notebook.cells)

        @test all(noerror, notebook.cells)
        output_1 = notebook.cells[begin].output.body

        update_run!(🍭, notebook, notebook.cells[2])

        @test noerror(notebook.cells[1])
        @test notebook.cells[1].output.body == output_1
        @test noerror(notebook.cells[2])

        setcode!.(notebook.cells, [""])
        update_run!(🍭, notebook, notebook.cells)
        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)
    end

    @testset "Multiple methods across cells" begin
        notebook = Notebook([
            Cell("a(x) = 1"),
            Cell("a(x,y) = 2"),
            Cell("a(3)"),
            Cell("a(4,4)"),

            Cell("b = 5"),
            Cell("b(x) = 6"),
            Cell("b + 7"),
            Cell("b(8)"),

            Cell("Base.tan(x::String) = 9"),
            Cell("Base.tan(x::Missing) = 10"),
            Cell("Base.tan(\"eleven\")"),
            Cell("Base.tan(missing)"),
            Cell("tan(missing)"),

            Cell("d(x::Integer) = 14"),
            Cell("d(x::String) = 15"),
            Cell("d(16)"),
            Cell("d(\"seventeen\")"),
            Cell("d"),

            Cell("struct asdf; x; y; end"),
            Cell(""),
            Cell("asdf(21, 21)"),
            Cell("asdf(22)"),

            Cell("@enum e1 e2 e3"),
            Cell("@enum e4 e5=24"),
            Cell("Base.@enum e6 e7=25 e8"),
            Cell("Base.@enum e9 e10=26 e11"),
            Cell("""@enum e12 begin
                    e13=27
                    e14
                end"""),
        ])

        update_run!(🍭, notebook, notebook.cells[1:4])
        @test notebook.cells[1] |> noerror
        @test notebook.cells[2] |> noerror
        @test notebook.cells[3].output.body == "1"
        @test notebook.cells[4].output.body == "2"

        setcode!(notebook.cells[1], "a(x,x) = 999")
        update_run!(🍭, notebook, notebook.cells[1])
        @test notebook.cells[1].errored == true
        @test notebook.cells[2].errored == true
        @test notebook.cells[3].errored == true
        @test notebook.cells[4].errored == true
        
        setcode!(notebook.cells[1], "a(x) = 1")
        update_run!(🍭, notebook, notebook.cells[1])
        @test notebook.cells[1] |> noerror
        @test notebook.cells[2] |> noerror
        @test notebook.cells[3].output.body == "1"
        @test notebook.cells[4].output.body == "2"

        setcode!(notebook.cells[1], "")
        update_run!(🍭, notebook, notebook.cells[1])
        @test notebook.cells[1] |> noerror
        @test notebook.cells[2] |> noerror
        @test notebook.cells[3].errored == true
        @test notebook.cells[4].output.body == "2"

        update_run!(🍭, notebook, notebook.cells[5:8])
        @test notebook.cells[5].errored == true
        @test notebook.cells[6].errored == true
        @test notebook.cells[7].errored == true
        @test notebook.cells[8].errored == true

        setcode!(notebook.cells[5], "")
        update_run!(🍭, notebook, notebook.cells[5])
        @test notebook.cells[5] |> noerror
        @test notebook.cells[6] |> noerror
        @test notebook.cells[7].errored == true
        @test notebook.cells[8].output.body == "6"

        setcode!(notebook.cells[5], "b = 5")
        setcode!(notebook.cells[6], "")
        update_run!(🍭, notebook, notebook.cells[5:6])
        @test notebook.cells[5] |> noerror
        @test notebook.cells[6] |> noerror
        @test notebook.cells[7].output.body == "12"
        @test notebook.cells[8].errored == true

        update_run!(🍭, notebook, notebook.cells[11:13])
        @test notebook.cells[12].output.body == "missing"

        update_run!(🍭, notebook, notebook.cells[9:10])
        @test notebook.cells[9] |> noerror
        @test notebook.cells[10] |> noerror
        @test notebook.cells[11].output.body == "9"
        @test notebook.cells[12].output.body == "10"
        @test notebook.cells[13].output.body == "10"
        update_run!(🍭, notebook, notebook.cells[13])
        @test notebook.cells[13].output.body == "10"

        setcode!(notebook.cells[9], "")
        update_run!(🍭, notebook, notebook.cells[9])
        @test notebook.cells[11].errored == true
        @test notebook.cells[12].output.body == "10"

        setcode!(notebook.cells[10], "")
        update_run!(🍭, notebook, notebook.cells[10])
        @test notebook.cells[11].errored == true
        @test notebook.cells[12].output.body == "missing"

        # Cell("d(x::Integer) = 14"),
        # Cell("d(x::String) = 15"),
        # Cell("d(16)"),
        # Cell("d(\"seventeen\")"),
        # Cell("d"),

        update_run!(🍭, notebook, notebook.cells[16:18])
        @test notebook.cells[16].errored == true
        @test notebook.cells[17].errored == true
        @test notebook.cells[18].errored == true

        update_run!(🍭, notebook, notebook.cells[14])
        @test notebook.cells[16] |> noerror
        @test notebook.cells[17].errored == true
        @test notebook.cells[18] |> noerror

        update_run!(🍭, notebook, notebook.cells[15])
        @test notebook.cells[16] |> noerror
        @test notebook.cells[17] |> noerror
        @test notebook.cells[18] |> noerror

        setcode!(notebook.cells[14], "")
        update_run!(🍭, notebook, notebook.cells[14])
        @test notebook.cells[16].errored == true
        @test notebook.cells[17] |> noerror
        @test notebook.cells[18] |> noerror

        setcode!(notebook.cells[15], "")
        update_run!(🍭, notebook, notebook.cells[15])
        @test notebook.cells[16].errored == true
        @test notebook.cells[17].errored == true
        @test notebook.cells[18].errored == true
        @test occursinerror("UndefVarError", notebook.cells[18])

        # Cell("struct e; x; y; end"),
        # Cell(""),
        # Cell("e(21, 21)"),
        # Cell("e(22)"),

        update_run!(🍭, notebook, notebook.cells[19:22])
        @test notebook.cells[19] |> noerror
        @test notebook.cells[21] |> noerror
        @test notebook.cells[22].errored == true

        setcode!(notebook.cells[20], "asdf(x) = asdf(x,x)")
        update_run!(🍭, notebook, notebook.cells[20])
        @test occursinerror("Multiple definitions", notebook.cells[19])
        @test occursinerror("Multiple definitions", notebook.cells[20])
        @test occursinerror("asdf", notebook.cells[20])
        @test occursinerror("asdf", notebook.cells[20])
        @test notebook.cells[21].errored == true
        @test notebook.cells[22].errored == true

        setcode!(notebook.cells[20], "")
        update_run!(🍭, notebook, notebook.cells[20])
        @test notebook.cells[19] |> noerror
        @test notebook.cells[20] |> noerror
        @test notebook.cells[21] |> noerror
        @test notebook.cells[22].errored == true

        setcode!(notebook.cells[19], "begin struct asdf; x; y; end; asdf(x) = asdf(x,x); end")
        setcode!(notebook.cells[20], "")
        update_run!(🍭, notebook, notebook.cells[19:20])
        @test notebook.cells[19] |> noerror
        @test notebook.cells[20] |> noerror
        @test notebook.cells[21] |> noerror
        @test notebook.cells[22] |> noerror

        update_run!(🍭, notebook, notebook.cells[23:27])
        @test notebook.cells[23] |> noerror
        @test notebook.cells[24] |> noerror
        @test notebook.cells[25] |> noerror
        @test notebook.cells[26] |> noerror
        @test notebook.cells[27] |> noerror
        update_run!(🍭, notebook, notebook.cells[23:27])
        @test notebook.cells[23] |> noerror
        @test notebook.cells[24] |> noerror
        @test notebook.cells[25] |> noerror
        @test notebook.cells[26] |> noerror
        @test notebook.cells[27] |> noerror

        setcode!.(notebook.cells[23:27], [""])
        update_run!(🍭, notebook, notebook.cells[23:27])

        setcode!(notebook.cells[23], "@assert !any(isdefined.([@__MODULE__], [Symbol(:e,i) for i in 1:14]))")
        update_run!(🍭, notebook, notebook.cells[23])
        @test notebook.cells[23] |> noerror

        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)

        # for some unsupported edge cases, see:
        # https://github.com/fonsp/Pluto.jl/issues/177#issuecomment-645039993
    end

    @testset "Cyclic" begin
        notebook = Notebook([
            Cell("xxx = yyy")
            Cell("yyy = xxx")
            Cell("zzz = yyy")

            Cell("aaa() = bbb")
            Cell("bbb = aaa()")
            
            Cell("w1(x) = w2(x - 1) + 1")
            Cell("w2(x) = x > 0 ? w1(x) : x")
            Cell("w1(8)")
            
            Cell("p1(x) = p2(x) + p1(x)")
            Cell("p2(x) = p1(x)")

            # 11
            Cell("z(x::String) = z(1)")
            Cell("z(x::Integer) = z()")
            
            # 13
            # some random Base function that we are overloading 
            Cell("Base.get(x::InterruptException) = Base.get(1)")
            Cell("Base.get(x::ArgumentError) = Base.get()")
            
            Cell("Base.step(x::InterruptException) = step(1)")
            Cell("Base.step(x::ArgumentError) = step()")
            
            Cell("Base.exponent(x::InterruptException) = Base.exponent(1)")
            Cell("Base.exponent(x::ArgumentError) = exponent()")
            
            # 19
            Cell("Base.chomp(x::InterruptException) = split() + chomp()")
            Cell("Base.chomp(x::ArgumentError) = chomp()")
            Cell("Base.split(x::InterruptException) = split()")
            
            # 22
            Cell("Base.transpose(x::InterruptException) = Base.trylock() + Base.transpose()")
            Cell("Base.transpose(x::ArgumentError) = Base.transpose()")
            Cell("Base.trylock(x::InterruptException) = Base.trylock()")

            # 25
            Cell("Base.digits(x::ArgumentError) = Base.digits() + Base.isconst()")
            Cell("Base.isconst(x::InterruptException) = digits()")

            # 27
            Cell("f(x) = g(x-1)")
            Cell("g(x) = h(x-1)")
            Cell("h(x) = i(x-1)")
            Cell("i(x) = j(x-1)")
            Cell("j(x) = (x > 0) ? f(x-1) : :done")
            Cell("f(8)")
        ])

        update_run!(🍭, notebook, notebook.cells[1:3])
        @test occursinerror("Cyclic reference", notebook.cells[1])
        @test occursinerror("xxx", notebook.cells[1])
        @test occursinerror("yyy", notebook.cells[1])
        @test occursinerror("Cyclic reference", notebook.cells[2])
        @test occursinerror("xxx", notebook.cells[2])
        @test occursinerror("yyy", notebook.cells[2])
        @test occursinerror("UndefVarError", notebook.cells[3])

        setcode!(notebook.cells[1], "xxx = 1")
        update_run!(🍭, notebook, notebook.cells[1])
        @test notebook.cells[1].output.body == "1"
        @test notebook.cells[2].output.body == "1"
        @test notebook.cells[3].output.body == "1"

        setcode!(notebook.cells[1], "xxx = zzz")
        update_run!(🍭, notebook, notebook.cells[1])
        @test occursinerror("Cyclic reference", notebook.cells[1])
        @test occursinerror("Cyclic reference", notebook.cells[2])
        @test occursinerror("Cyclic reference", notebook.cells[3])
        @test occursinerror("xxx", notebook.cells[1])
        @test occursinerror("yyy", notebook.cells[1])
        @test occursinerror("zzz", notebook.cells[1])
        @test occursinerror("xxx", notebook.cells[2])
        @test occursinerror("yyy", notebook.cells[2])
        @test occursinerror("zzz", notebook.cells[2])
        @test occursinerror("xxx", notebook.cells[3])
        @test occursinerror("yyy", notebook.cells[3])
        @test occursinerror("zzz", notebook.cells[3])

        setcode!(notebook.cells[3], "zzz = 3")
        update_run!(🍭, notebook, notebook.cells[3])
        @test notebook.cells[1].output.body == "3"
        @test notebook.cells[2].output.body == "3"
        @test notebook.cells[3].output.body == "3"

        ##
        
        
        update_run!(🍭, notebook, notebook.cells[4:5])
        @test occursinerror("Cyclic reference", notebook.cells[4])
        @test occursinerror("aaa", notebook.cells[4])
        @test occursinerror("bbb", notebook.cells[4])
        @test occursinerror("Cyclic reference", notebook.cells[5])
        @test occursinerror("aaa", notebook.cells[5])
        @test occursinerror("bbb", notebook.cells[5])

        
        
        
        
        update_run!(🍭, notebook, notebook.cells[6:end])
        @test noerror(notebook.cells[6])
        @test noerror(notebook.cells[7])
        @test noerror(notebook.cells[8])
        @test noerror(notebook.cells[9])
        @test noerror(notebook.cells[10])
        @test noerror(notebook.cells[11])
        @test noerror(notebook.cells[12])
        @test noerror(notebook.cells[13])
        @test noerror(notebook.cells[14])
        @test noerror(notebook.cells[15])
        @test noerror(notebook.cells[16])
        @test noerror(notebook.cells[17])
        @test noerror(notebook.cells[18])
        @test noerror(notebook.cells[19])
        @test noerror(notebook.cells[20])
        @test noerror(notebook.cells[21])
        @test noerror(notebook.cells[22])
        @test noerror(notebook.cells[23])
        @test noerror(notebook.cells[24])
        @test noerror(notebook.cells[25])
        @test noerror(notebook.cells[26])

        ##
        @test noerror(notebook.cells[27])
        @test noerror(notebook.cells[28])
        @test noerror(notebook.cells[29])
        @test noerror(notebook.cells[30])
        @test noerror(notebook.cells[31])
        @test noerror(notebook.cells[32])
        @test notebook.cells[32].output.body == ":done"

        @assert length(notebook.cells) == 32
        
        # Empty and run cells to remove the Base overloads that we created, just to be sure
        setcode!.(notebook.cells, [""])
        update_run!(🍭, notebook, notebook.cells)
        
        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)
    end

    @testset "Variable cannot reference its previous value" begin
        notebook = Notebook([
        Cell("x = 3")
    ])

        update_run!(🍭, notebook, notebook.cells[1])
        setcode!(notebook.cells[1], "x = x + 1")
        update_run!(🍭, notebook, notebook.cells[1])
        @test occursinerror("UndefVarError", notebook.cells[1])

        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)
    end
    
    @testset "Function & package dependencies" begin

        notebook = Notebook([
            Cell("y = 1"),
            Cell("f(x) = x + y"),
            Cell("f(3)"),

            Cell("g(a,b) = a+b"),
            Cell("g(5,6)"),

            Cell("h(x::Int) = x"),
            Cell("h(7)"),
            Cell("h(8.0)"),

            Cell("p(x) = 9"),
            Cell("p isa Function"),

            Cell("module Something
                export a
                a(x::String) = \"🐟\"
            end"),
            Cell("using .Something"),
            Cell("a(x::Int) = x"),
            Cell("a(\"i am a \")"),
            Cell("a(15)"),
            
            Cell("module Different
                export b
                b(x::String) = \"🐟\"
            end"),
            Cell("import .Different: b"),
            Cell("b(x::Int) = x"),
            Cell("b(\"i am a \")"),
            Cell("b(20)"),
            
            Cell("module Wow
                export c
                c(x::String) = \"🐟\"
            end"),
            Cell("begin
                import .Wow: c
                c(x::Int) = x
            end"),
            Cell("c(\"i am a \")"),
            Cell("c(24)"),

            Cell("Ref((25,:fish))"),
            Cell("begin
                import Base: show
                show(io::IO, x::Ref{Tuple{Int,Symbol}}) = write(io, \"🐟\")
            end"),

            Cell("Base.isodd(n::Integer) = \"🎈\""),
            Cell("Base.isodd(28)"),
            Cell("isodd(29)"),

            Cell("using Dates"),
            Cell("year(DateTime(31))"),
        ])
        update_run!(🍭, notebook, notebook.cells)
        
        otr(x) = order_to_run(notebook, x)
        
        
        @test otr(1) == [1,2,3]
        @test otr(2) == [2,3]
        
        @test otr(4) == [4,5]
        @test otr(5) == [5]
        
        setcode!(notebook.cells[5], "g(a) = a+a")
        update_run!(🍭, notebook, notebook.cells[5])
        
        @test otr(4) == [4,5]
        @test otr(5) == [5,4]
        
        
        @test otr(6) == [6,7,8]
        @test otr(7) == [7]
        
        @test otr(9) == [9,10]
        

        setcode!(notebook.cells[9], "p = p")
        update_run!(🍭, notebook, notebook.cells[9])
        
        @test otr(9) == []
        
        # multiple definitions for `Something` should be okay?
        @test_broken otr(11) == [11,12,13,14,15]
        @test otr(13) == [13,14,15]
        
        @test otr(16) == [16,17,18,19,20]
        @test otr(18) == [18,19,20]
        
        @test otr(21) == [21,22,23,24]
        @test otr(22) == [22,23,24]
        @test otr(24) == [24]

        
        @test otr(27) == [27,28,29]
        @test otr(28) == [28]
        
        @test otr(30) == [30,31]
        
        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)
    end


    @testset "Functional programming" begin
        notebook = Notebook([
            Cell("a = 1"),
            Cell("map(2:2) do val; (a = val; 2*val) end |> last"),

            Cell("b = 3"),
            Cell("g = f"),
            Cell("f(x) = x + b"),
            Cell("g(6)"),

            Cell("h = [x -> x + b][1]"),
            Cell("h(8)"),
        ])

        update_run!(🍭, notebook, notebook.cells[1:2])
        @test notebook.cells[1].output.body == "1"
        @test notebook.cells[2].output.body == "4"

        update_run!(🍭, notebook, notebook.cells[3:6])
        @test notebook.cells[3] |> noerror
        @test notebook.cells[4] |> noerror
        @test notebook.cells[5] |> noerror
        @test notebook.cells[6] |> noerror
        @test notebook.cells[6].output.body == "9"

        setcode!(notebook.cells[3], "b = -3")
        update_run!(🍭, notebook, notebook.cells[3])
        @test notebook.cells[6].output.body == "3"

        update_run!(🍭, notebook, notebook.cells[7:8])
        @test notebook.cells[7] |> noerror
        @test notebook.cells[8].output.body == "5"

        setcode!(notebook.cells[3], "b = 3")
        update_run!(🍭, notebook, notebook.cells[3])
        @test notebook.cells[8].output.body == "11"

        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)
        
    end

    @testset "Run multiple" begin
        notebook = Notebook([
            Cell("x = []"),
            Cell("b = a + 2; push!(x,2)"),
            Cell("c = b + a; push!(x,3)"),
            Cell("a = 1; push!(x,4)"),
            Cell("a + b +c; push!(x,5)"),

            Cell("a = 1; push!(x,6)"),

            Cell("n = m; push!(x,7)"),
            Cell("m = n; push!(x,8)"),
            Cell("n = 1; push!(x,9)"),

            Cell("push!(x,10)"),
            Cell("push!(x,11)"),
            Cell("push!(x,12)"),
            Cell("push!(x,13)"),
            Cell("push!(x,14)"),

            Cell("join(x, '-')"),

            Cell("φ(16)"),
            Cell("φ(χ) = χ + υ"),
            Cell("υ = 18"),

            Cell("f(19)"),
            Cell("f(x) = x + g(x)"),
            Cell("g(x) = x + y"),
            Cell("y = 22"),
        ])

        update_run!(🍭, notebook, notebook.cells[1])

        @testset "Basic" begin
            update_run!(🍭, notebook, notebook.cells[2:5])

            update_run!(🍭, notebook, notebook.cells[15])
            @test notebook.cells[15].output.body == "\"4-2-3-5\""
        end
        
        @testset "Errors" begin
            update_run!(🍭, notebook, notebook.cells[6:9])

            # should all err, no change to `x`
            update_run!(🍭, notebook, notebook.cells[15])
            @test notebook.cells[15].output.body == "\"4-2-3-5\""
        end

        @testset "Maintain order when possible" begin
            update_run!(🍭, notebook, notebook.cells[10:14])

            update_run!(🍭, notebook, notebook.cells[15])
            @test notebook.cells[15].output.body == "\"4-2-3-5-10-11-12-13-14\""

            update_run!(🍭, notebook, notebook.cells[1]) # resets `x`, only 10-14 should run, in order
            @test notebook.cells[15].output.body == "\"10-11-12-13-14\""
            update_run!(🍭, notebook, notebook.cells[15])
            @test notebook.cells[15].output.body == "\"10-11-12-13-14\""
        end
        

        update_run!(🍭, notebook, notebook.cells[16:18])
        @test notebook.cells[16] |> noerror
        @test notebook.cells[16].output.body == "34"
        @test notebook.cells[17] |> noerror
        @test notebook.cells[18] |> noerror

        setcode!(notebook.cells[18], "υ = 8")
        update_run!(🍭, notebook, notebook.cells[18])
        @test notebook.cells[16].output.body == "24"
        
        update_run!(🍭, notebook, notebook.cells[19:22])
        @test notebook.cells[19] |> noerror
        @test notebook.cells[19].output.body == "60"
        @test notebook.cells[20] |> noerror
        @test notebook.cells[21] |> noerror
        @test notebook.cells[22] |> noerror

        setcode!(notebook.cells[22], "y = 0")
        update_run!(🍭, notebook, notebook.cells[22])
        @test notebook.cells[19].output.body == "38"

        WorkspaceManager.unmake_workspace((🍭, notebook); verbose=false)
    end

end
