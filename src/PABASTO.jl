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
	# I want you to gossip with. The master should send this message to one member of
	# the pair of paramservers selected for gossiping.
	# Every gossip_time seconds, the master randomly selects two paramservers for
	# gossiping (asynchronous gossip)
	# Upon arrival of this message, 1st paramserver sends ParameterGossipMessage to process id below
	# corresponding to the 2nd paramserver with 1st paramserver parameters and 1st paramserver process id
	pserver_id::Int # 2nd paramserver
	self_pserver_id::Int # 1st paramserver
end

type ParameterGossipMessage
	# When 2nd paramserver receives this message, it immediately performs B + (0.5 * A - 0.5 * B) using
	# the parameters below (A) and its current parameters (B). It then sends ParameterFinalGossipMessage
	# to the 1st paramserver with pserver_id below. The ParameterFinalGossipMessage 
	# has 0.5 * A + 0.5 * B - parameters field in this message
	parameters::Parameter
	pserver_id::Int
end

type ParameterFinalGossipMessage
	# When 1st paramserver receives this message with parameters below being equal to
	# 0.5 * A - 0.5 * B, it performs A' - (0.5 * A - 0.5 * B) = A' + (0.5 * B - 0.5 * A)
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
