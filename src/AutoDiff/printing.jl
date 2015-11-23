function Base.show(io::IO,c::CoTangent)
	show(io,c,0)
end
function Base.show{F,T}(io::IO,c::Call{F,T},n::Int)
	for i in 1:n
		print(io,"  ")
	end
	println(io,"Call $(F) $(val(c)|>with_size)")
	for a in c.args
		show(io,a,n+1)
	end
end
function Base.show{T}(io::IO,c::Lift{T},n::Int)
	for i in 1:n
		print(io,"  ")
	end
	println(io,"Lift $(val(c)|>with_size)")
	for a in c.args
		show(io,a,n+1)
	end
end
function Base.show{T}(io::IO,x::Variable{T},n::Int)
	for i in 1:n
		print(io,"  ")
	end
	println(io,"Variable $(val(x)|>with_size)")
end

function Base.show(io::IO,x,n::Int)
	for i in 1:n
		print(io,"  ")
	end
	println(io,"Constant $(x|>with_size)")
end

function with_size{T}(x::T)
	"$(T)"
end
function with_size(x::Real)
	"$(x)"
end
function with_size{T}(x::Array{T})
	"$(T)$(size(x))"
end
