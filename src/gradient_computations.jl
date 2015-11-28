using AutoDiff
using MNIST

type SimpleParameter <: Parameter
	data
end

type SimpleGradient <: Gradient
	data
end

function update(p::SimpleParameter, g::SimpleGradient)
	p.data+=g.data
end

#Replace error with an arbitrary function to minimize
#datum should be a tuple (digit,label) where label is length 10 array with a single 1
function error(params::Array,datum)
	weights1=params[1]
	biases1=params[2]

	layer1=rect_lin(weights1*datum[1].+biases1)
	tmp=exp(layer1)
	prediction=tmp./sum(tmp)
	error=sum((prediction-datum[2]).^2)
end

function error(params::SimpleParameter,datum)
	error(params.data,datum)
end

#Dummy inputs used for initializing variables in the gradient computation
dummy_weights1=zeros(Float64,(10,784))
dummy_biases1=zeros(Float64,(10,))
dummy_input=zeros(Float64,(784,))
dummy_output=zeros(Float64,(10,))

update_params,accumulate_gradient,take_gradient=AutoDiff.derivative(error,Any[dummy_weights1,dummy_biases1],
Any[dummy_input,dummy_output])

#assume dataset is a list of indices
function compute_gradient(params::SimpleParameter, dataset)
	println("[WORKER] Computing gradients")
	update_params(params.data)
	for i in dataset
		example=trainfeatures(i)
		label=map(x->if x==trainlabel(i); 1.0; else 0.0; end, 0:9)
		accumulate_gradient((example,label))
	end
	sleep(0.5)
	return SimpleGradient(take_gradient())
end
