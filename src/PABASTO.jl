module PABASTO
### Mailboxes ###
import Base: put!, wait, isready, take!, fetch

type Mailbox <: AbstractChannel
	data::Dict
	function Mailbox()
		new(Dict())
	end
end

function put!{T}(m::Mailbox, v::T)
	if !haskey(m.data,T)
		m.data[T]=Channel(100)
	end
	put!(m.data[T],v)
	m
end

function take!(m::Mailbox)
	n=length(values(m.data))
	#iterate through channels in a random order
	for c in collect(values(m.data))[randperm(n)]
		if isready(c)
			return take!(c)
		end
	end
	return nothing
end


### Parameters ###
abstract Parameter
abstract Gradient
type ConcreteParameter <: Parameter
end

type ConcreteGradient <: Gradient
end

type GradientUpdateMessage
	gradient::Gradient
end

type ParameterUpdateRequestMessage
	worker_recv_channel::RemoteChannel
end

type ParameterUpdateMessage
	parameters
end

type ExampleIndicesMessage
	indices::Array{Int}
end

type ExamplesRequestMessage
	id::Int
	master_recv_channel::RemoteChannel
end

type CeaseOperationMessage
end

type AdaptiveControlPolicyMessage
	tau::Float64
	num_workers::Int
	batch_size::Int
end

function update(p::ConcreteParameter, g::ConcreteGradient)
	# update p with parameter g
end

# todo: split into separate modules
include("master.jl")
include("paramserver.jl")
include("worker.jl")
end
