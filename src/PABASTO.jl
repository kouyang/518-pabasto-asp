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
	return m
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
	worker_mailbox::RemoteChannel
end

type ParameterUpdateMessage
	parameters
end

type ExampleIndicesMessage
	indices::Array{Int}
end

type ExamplesRequestMessage
	id::Int
	worker_mailbox::RemoteChannel
end

type CeaseOperationMessage
end

type AdaptiveControlPolicyMessage
	tau::Float64
	num_workers::Int
	num_paramservers::Int
	example_batch_size::Int
	batch_size::Int
	gossip_time::Float64
end

type InitiateGossipMessage
	# Master sends this to paramserver: here is the process id of the paramserver
	# I want you to gossip with. The master should send this message to both members of
	# the pair of paramservers selected for gossiping.
	# Every gossip_time seconds, the master randomly selects two paramservers for
	# gossiping (asynchronous gossip)
	# Upon arrival, paramserver sends ParameterGossipMessage to process id below
	pserver_id::Int
end

type ParameterGossipMessage
	# When paramserver receives this message, it immediately performs gossip_average using
	# the parameters below and its current parameters
	parameters::Parameter
end

function update(p::Parameter, g::Gradient)
	# update p with parameter g
end

function add_procs(count)
	return fetch(@spawnat 1 Main.add_pabasto_procs(count))
end

# todo: split into separate modules
include("master.jl")
include("paramserver.jl")
include("worker.jl")
end
