module PABASTO
### Parameters ###
abstract Parameter
abstract Gradient
type ConcreteParameter <: Parameter
	# fill me
end

type ConcreteGradient <: Gradient
	# fill me
end

type GradientUpdateMessage
	gradient::ConcreteGradient
end

type ParameterUpdateRequestMessage
	worker_recv_channel::RemoteChannel
end

type SendParameterUpdateMessage
	parameter::ConcreteParameter
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

function update(p::ConcreteParameter, g::ConcreteGradient)
	# update p with parameter g
end

num_workers = 3
num_paramservers = 1

include("hash.jl")

# todo: split into separate modules
include("master.jl")
include("paramserver.jl")
include("worker.jl")
end
