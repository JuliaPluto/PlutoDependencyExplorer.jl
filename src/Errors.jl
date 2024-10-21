import Base: showerror
import ExpressionExplorer: FunctionName

abstract type ReactivityError <: Exception end

struct CyclicReferenceError <: ReactivityError
	syms::Set{Symbol}
end

function CyclicReferenceError(topology::NotebookTopology, cycle::AbstractVector{<:AbstractCell})
	CyclicReferenceError(cyclic_variables(topology, cycle))
end

struct MultipleDefinitionsError <: ReactivityError
	syms::Set{Symbol}
	function_syms::Set{Symbol}
end
MultipleDefinitionsError(syms::Set{Symbol}) = MultipleDefinitionsError(syms, Set{Symbol}())

function MultipleDefinitionsError(topology::NotebookTopology, cell::AbstractCell, all_definers)
	competitors = setdiff(all_definers, [cell])
	fdefs(c) = topology.nodes[c].funcdefs_without_signatures
	defs(c) = topology.nodes[c].funcdefs_without_signatures ∪ topology.nodes[c].definitions
	MultipleDefinitionsError(
		union((defs(cell) ∩ defs(c) for c in competitors)...),
		union((fdefs(cell) ∩ fefs(c) for c in competitors)...),
	)
end

const _hint1 = "Combine all definitions into a single reactive cell using a `begin ... end` block."
const _hint1 = "Combine all definitions into a single reactive cell using a `begin ... end` block."

# TODO: handle case when cells are in cycle, but variables aren't
function showerror(io::IO, cre::CyclicReferenceError)
	print(io, "Cyclic references among ")
	println(io, join(cre.syms, ", ", " and "))
	println(io, _hint1)
end

function showerror(io::IO, mde::MultipleDefinitionsError)
	print(io, "Multiple definitions for ")
	println(io, join(mde.syms, ", ", " and "))
	println(io, _hint1) # TODO: hint about mutable globals
	if 0 < length(mde.function_syms) < length(mde.syms)
		println()
		println("Tip: Fix multiple defintions for variables first ($(join(setdiff(mde.syms, mde.function_syms), ", ", " and "))), then fix method defintions.")
	end
end
