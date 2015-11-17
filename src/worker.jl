###Worker State###
type WorkerState
	current_params::Parameter
	meta_params
	dataset
end

function compute_gradient(params,dataset)
	println("Computing gradients")
	sleep(1)
	#fill me
end

#main worker loop
function worker()
	state=WorkerState(ConcreteParameter(),nothing,nothing)
	for i in 1:10
		grad=compute_gradient(state,dataset)

		#get a parameter server id from master
		paramserver_id=fetch(remotecall(1,get_paramserver))
		
		#fetch parameters
		state.current_params=fetch(remotecall(paramserver_id,read_params))

		#write params to parameter server
		remotecall(paramserver_id,write_params,grad)
	end
end
