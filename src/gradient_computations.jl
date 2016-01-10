using AutoDiff
using MNIST

type SimpleParameter <: Parameter
	data
	timestamp
	discrete_timestamp
end

function SimpleParameter(data)
	return SimpleParameter(data,now(),0)
end

type SimpleGradient <: Gradient
	data
	timestamp
	discrete_timestamp
	n_aggregated
end

function update(p::SimpleParameter, g::SimpleGradient)
	# update p with parameter g
	println("[PARAM SERVER] Staleness: $(p.timestamp-g.timestamp), $(p.discrete_timestamp-g.discrete_timestamp)")
	p.data-=g.data
	p.timestamp = now()
	p.discrete_timestamp += g.n_aggregated
end

function Base.(:+)(g1::SimpleGradient,g2::SimpleGradient)
	SimpleGradient(g1.data+g2.data,min(g1.timestamp,g2.timestamp),min(g1.n_aggregated, g2.n_aggregated))
end

#Replace error with an arbitrary function to minimize
#datum should be a tuple (digit,label) where label is length 10 array with a single 1
function loss(params::Array,datum)
	weights1=params[1]
	biases1=params[2]

	weights2=params[3]
	biases2=params[4]

	layer1=sigmoid(weights1*datum[1].+biases1)
	layer2=(weights2*layer1.+biases2)
	tmp=exp(layer2)
	prediction=tmp./sum(tmp)

	error=sum(-(prediction.*datum[2]))
end

function loss(params::SimpleParameter, datum)
	loss(params.data,datum)
end

#Dummy inputs used for initializing variables in the gradient computation
function sample_parameters(;seed=1,var=0.001)
	srand(seed)
	weights1=0.01*randn((500,784))
	biases1=0.01*randn((500,))
	
	weights2=0.01*randn((10,500))
	biases2=0.01*randn((10,))

	return Any[weights1,biases1,weights2,biases2]
end
function sample_input_output()
	dummy_input=zeros(Float64,(784,))
	dummy_output=zeros(Float64,(10,))
	return (dummy_input, dummy_output)
end


#assume dataset is a list of indices
function compute_gradient(state::WorkerState,dataset)
	println("[WORKER] Computing gradients")
	state.update_params(state.current_params.data)
	g=0
	t=now()
	for i in ones(Int,length(dataset))
		example=trainfeatures(i)
		label=map(x->if x==trainlabel(i); 1.0; else 0.0; end, 0:9)
		g+=state.compute_gradient((example,label))
		yield()
	end
	println("[WORKER] Computed gradients in $(now()-t)")
	return SimpleGradient(state.learning_rate*g/length(dataset),state.current_params.timestamp,state.current_params.discrete_timestamp,1)
end
