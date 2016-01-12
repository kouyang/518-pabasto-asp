module PABASTO
### Mailboxes ###
import Base: put!, wait, isready, take!, fetch
using IntervalTrees
using Parameters
my_stdout=open("$(myid()).out","w")
function my_println(s)
	println(my_stdout,s)
	flush(my_stdout)
end

#override now to give millisecond precision
function now()
	return Dates.unix2datetime(time())
end


type IntervalMailbox <: AbstractChannel
	data::Dict
	lock::ReentrantLock
	function IntervalMailbox()
		new(Dict(),ReentrantLock())
	end
end

function put!{T}(m::IntervalMailbox,v::T,low::Real,high::Real)
	lock(m.lock)
	if !haskey(m.data,T)
		m.data[T]=IntervalMap{Real,T}()
	end
	push!(m.data[T],IntervalValue{Real,T}(low,high,v))
	unlock(m.lock)
	return m
end

function take!(m::IntervalMailbox,position)
	lock(m.lock)
	all_channels=shuffle(collect(m.data))
	for (T,channel) in all_channels
		i=IntervalTrees.firstintersection(channel,Interval{Real}(position-0.1,position+0.1))

		if i.index!=0
			leafnode=i.node
			interval=leafnode.entries.data[i.index]
			c=channel.n
			IntervalTrees.deletefirst!(channel,Interval{Real}(interval.first,interval.last))
			@assert channel.n==c-1
			unlock(m.lock)
			if channel.n > 10
				my_println("Warning, IntervalMailbox channel backlog: $(T) $(channel.n)")
			end
			return interval.value
		end
	end
	unlock(m.lock)
	return nothing
end


type Mailbox <: AbstractChannel
	data::Dict
	function Mailbox()
		new(Dict())
	end
end

function isready(m::Mailbox,T)
	if !haskey(m.data,T)
		m.data[T]=Channel(100)
	end
	isready(m.data[T])
end

function put!{T}(m::Mailbox, v::T)
	if !haskey(m.data,T)
		m.data[T]=Channel(100)
	end
	put!(m.data[T],v)
	if length(m.data[T].data) > 10
		my_println("Warning, Mailbox channel backlog: $(length(m.data[T].data))")
	end
	return m
end

function take!(m::Mailbox)
	n=length(values(m.data))
	all_channels=filter(x->isready(x[2]),collect(m.data))
	if length(all_channels)>0
		priorities=map(x->priority(x[1],length(x[2].data)),all_channels)
		mtype,c=all_channels[indmax(priorities)]
		return take!(c)
	else
		return nothing
	end
end

function take!(m::Mailbox,T)
	if !haskey(m.data,T)
		m.data[T]=Channel(100)
	end
	take!(m.data[T])
end


### Parameters ###
@with_kw type HyperParameters
	learning_rate
	examples_batch_size
	tau
	num_workers
	num_paramservers
	max_num_epochs
end

abstract Parameter
abstract Gradient
type ConcreteParameter <: Parameter
end

type ConcreteGradient <: Gradient
end

### Messages ###

type GradientUpdateMessage
	gradient::RemoteChannel
end
function GradientUpdateMessage(gradient::Gradient)
	c=RemoteChannel()
	put!(c,gradient)
	GradientUpdateMessage(c)
end

type ParameterUpdateRequestMessage
	worker_mailbox::RemoteChannel
end

type ParameterUpdateMessage
	parameters
end

type ParameterRequestMessage
end

type ExampleIndicesMessage
	indices::Array{Int}
end
type TestExampleIndicesMessage
	indices::Array{Int}
end
type ReevaluatePolicyMessage
	indices::Array{Int}
end
type TestLossMessage
	params::Parameter
	loss::Real
end

type ExamplesRequestMessage
	id::Int
	worker_mailbox::RemoteChannel
end

type CeaseOperationMessage
end

type CeasedOperationMessage
	id::Int
end

type FinishOperationMessage
end

type FinishedOperationMessage
	id::Int
end

type AdaptiveControlPolicyMessage
	hyper_params::HyperParameters
end

function update(p::Parameter, g::Gradient)
	#update p with gradient g
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
function priority(x::Type{TestExampleIndicesMessage},queue_length)
	return 5*queue_length
end

function priority(x::Type{ParameterUpdateMessage},queue_length)
	return 10*queue_length
end

function priority(x::Type{FinishOperationMessage},queue_length)
	return -1
end

function priority(x::Type{AdaptiveControlPolicyMessage},queue_length)
	return 100*queue_length
end

function priority(x::Type{ReevaluatePolicyMessage},queue_length)
	return 10*queue_length
end


# todo: split into separate modules
include("master.jl")
include("paramserver.jl")
include("worker.jl")
end
