__precompile__()

module AutoDiff
using DataStructures
export Constant,Variable, Call, CoTangent, Lift, val
export my_tanh,rect_lin,sigmoid,convolve
export minimize

import Base: (+), (-), (*), (/), (^), 
(.+), (.-), (.*), (./), (.^), exp, log, sum

begin
	#my_zero(x) returns an array of zeros of the same shape as x
	#x can be a number, an array, an array of arrays, etc.
	function my_zero(A::Array)
		[my_zero(x) for x in A]
	end
	function my_zero{T<:Number}(A::Array{T})
		zeros(A)
	end
	function my_zero(x)
		zero(x)
	end
end

#Type CoTangent{T} stores a value of type T and a derivative
abstract CoTangent{T}
type Variable{T} <: CoTangent{T}
	val::T
	delta::T
end
type Constant{T} <: CoTangent{T}
	val::T
	delta::T
end
Variable{T}(val::T)=Variable{T}(val,my_zero(val))
Constant{T}(val::T)=Constant{T}(val,my_zero(val))

is_CoTangent(x::CoTangent)=true
is_CoTangent(x)=false

type Call{F,T} <: CoTangent{T}
	f::Function
	args::Tuple
	val::T
	delta::T
	function Call(f,args,v,delta)
		new(f,args,v,delta)
	end
end

type Lift{T}<:CoTangent{T}
	args
	val::T
	delta::T
end
function Lift(args)
	tmp=map(val,args)
	Lift(args,tmp,my_zero(tmp))
end

val(x)=x
val(x::CoTangent)=x.val

Call(f,args)=Call(f,args,f(map(val,args)...))
Call{T}(f::Function,args,val::T)=Call{Base.function_name(f),T}(f,args,val,my_zero(val))

begin
	function execute(x::Call)
		x.val=x.f(map(val,x.args)...)
	end
	function execute(x::Lift)
		x.val=map(val,x.args)
	end
	function execute(x) end
end

begin
	function clear_array{T<:Real}(A::Array{T})
		fill!(A,zero(T))
	end
	function clear_array{T<:Array}(A::Array{T})
		map(clear_array,A)
	end
	function reset_delta{T<:Real}(t::CoTangent{T})
		t.delta=zero(T)
	end
	function reset_delta{T<:Array}(t::CoTangent{T})
		clear_array(t.delta)
	end
end

function backprop end

#returns a function which computes f'
#expects a function f which takes an array of vars
#and an array of constants
function derivative(f, vars, constants)
	wrapped_vars=map(x->Variable(x),vars)
	wrapped_constants=map(x->Constant(x),constants)
	output=f(wrapped_vars,wrapped_constants)
	l=topological_order(output)
	function update_params(new_params)
		for (x,y) in zip(wrapped_vars,new_params)
			x.val=y
		end
	end
	function gradient(constants)
		map(reset_delta,l)
		for (x,y) in zip(wrapped_constants,constants)
			x.val=y
		end
		map(execute,l)
		output.delta=1
		map(backprop,reverse(l))
		return map(x->x.delta,wrapped_vars)
	end

	return (update_params,gradient)
end

function compute_grad(expr,l)
	map(reset_delta,l)
	expr.delta=1
	map(backprop,reverse(l))
end
begin
	function descend(d::Variable,delta)
		d.val -= delta.*d.delta
	end
	function descend(d::CoTangent,delta) end
end
function minimize(c::CoTangent;delta=0.01,its=1000,f=(it->nothing))
	l=topological_order(c)
	for i in 1:its
		map(execute,l)
		f(i)
		compute_grad(c,l)
		map(x->descend(x,delta), l)
	end
end


function depth_first_map(f,t::CoTangent)
	visited=Set()
	function traverse(c::Union{Call,Lift})
		if !(c in visited)
			for child in c.args
				traverse(child)
			end
			f(c)
			push!(visited,c)
		end
	end
	function traverse(c::Variable)
		if !(c in visited)
			f(c)
			push!(visited,c)
		end
	end
	function traverse(c) end
	traverse(t)
end

function topological_order(c::CoTangent)
	q=Any[]
	depth_first_map(x->push!(q,x),c)
	q
end

include("AutoDiff/printing.jl")
include("AutoDiff/backprop.jl")
include("AutoDiff/call_defs.jl")

function sigmoid(x)
	1 ./(1 .+exp(-x))
end
function my_tanh(x)
	2.0 .* sigmoid(2.0 .* x) .- 1.0
end
function rect_lin(x)
	max(x,0)
end
end
