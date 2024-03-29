using AutoDiff
using MNIST

type SimpleParameter <: Parameter
	data
	timestamp
end

function SimpleParameter(data)
	return SimpleParameter(data,now())
end

type SimpleGradient <: Gradient
	data
end

function update(p::SimpleParameter, g::SimpleGradient)
	# update p with parameter g
	p.data-=g.data
	p.timestamp=now()
end

function zero_gradient(p::SimpleParameter)
	data = zeros( size(p.data, 1), size(p.data, 2) );
	return SimpleGradient(data);
end

#Replace error with an arbitrary function to minimize
#datum should be a tuple (digit,label) where label is length 10 array with a single 1
function loss(params::Array,datum)
	weights1=params[1]
	biases1=params[2]

	layer1=weights1*datum[1].+biases1
	tmp=exp(layer1)
	prediction=tmp./sum(tmp)

	error=sum((prediction-datum[2]).^2)
end

function loss(params::SimpleParameter, datum)
	loss(params.data,datum)
end
srand(1)
#Dummy inputs used for initializing variables in the gradient computation
dummy_weights1=0.001*randn((10,784))
dummy_biases1=0.001*randn((10,))
dummy_input=zeros(Float64,(784,))
dummy_output=zeros(Float64,(10,))


#assume dataset is a list of indices
function compute_gradient(state::WorkerState,dataset)
	println("[WORKER] Computing gradients")
	state.update_params(state.current_params.data)
	g=0
	for i in dataset
		example=trainfeatures(i)
		label=map(x->if x==trainlabel(i); 1.0; else 0.0; end, 0:9)
		g+=state.compute_gradient((example,label))
	end
	sleep(0.1)
	return SimpleGradient(state.learning_rate*g/length(dataset))
end
