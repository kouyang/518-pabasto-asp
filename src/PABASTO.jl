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
	all_channels=filter(x->isready(x[2]),collect(m.data))
	if length(all_channels)>0
		priorities=map(x->priority(x[1],length(x[2].data)),all_channels)
		mtype,c=all_channels[indmax(priorities)]
		return take!(c)
	else
		return nothing
	end
end


### Parameters ###
abstract Parameter
abstract Gradient
type ConcreteParameter <: Parameter
end

type ConcreteGradient <: Gradient
end

### Messages ###

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
end

function update(p::ConcreteParameter, g::ConcreteGradient)
	# update p with parameter g
end

function add_procs(count)
	return fetch(@spawnat 1 Main.add_pabasto_procs(count))
end

##Priorities##
#The default priority of a message type is just the number
#of messages of that type

#To define priority of a new type, follow the example of
#ParameterUpdateMessage
function priority(message_type,queue_length)
	return queue_length
end

function priority(x::Type{ParameterUpdateMessage},queue_length)
	return 10*queue_length
end



# todo: split into separate modules
include("master.jl")
include("paramserver.jl")
include("worker.jl")
end
