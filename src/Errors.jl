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
end

function MultipleDefinitionsError(topology::NotebookTopology, cell::AbstractCell, all_definers)
	competitors = setdiff(all_definers, [cell])

	dd(c) = topology.nodes[c].definitions
	df(c) = topology.nodes[c].funcdefs_with_signatures
	ddf(c) = topology.nodes[c].definitions ∪ topology.nodes[c].funcdefs_without_signatures
	
	MultipleDefinitionsError(
		union!(
			Set{Symbol}(),
			(dd(cell) ∩ ddf(c) for c in competitors)...,
			(ddf(cell) ∩ dd(c) for c in competitors)...,
			((funcdef.name.joined for funcdef in df(cell) ∩ df(c)) for c in competitors)...,
		)
	)
end

const _hint1 = "Combine all definitions into a single reactive cell using a `begin ... end` block."

# TODO: handle case when cells are in cycle, but variables aren't
function showerror(io::IO, cre::CyclicReferenceError)
	print(io, "Cyclic references among ")
	println(io, join(cre.syms, ", ", " and "))
	print(io, _hint1)
end

function showerror(io::IO, mde::MultipleDefinitionsError)
	print(io, "Multiple definitions for ")
	println(io, join(mde.syms, ", ", " and "))
	print(io, _hint1) # TODO: hint about mutable globals
end
