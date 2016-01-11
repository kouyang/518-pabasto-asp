### Worker State ###
@with_kw type WorkerState
	current_params::Parameter
	master_mailbox
	worker_mailbox
	#tau
	time_var=now()
	param_request_pending::Bool=false
	update_params
	compute_gradient
	#learning_rate
	exit::Bool=false

	hyper_params
end

include("gradient_computations.jl")

function handle(state::WorkerState, message::ExampleIndicesMessage)
	put!(state.master_mailbox, ParameterUpdateRequestMessage(state.worker_mailbox));
	handle(state,take!(state.worker_mailbox,ParameterUpdateMessage))

	grad=compute_gradient(state, message.indices)
	println("[WORKER] Sending gradient updates")
	put!(state.master_mailbox, GradientUpdateMessage(grad))

	println("[WORKER] Requesting examples")
	put!(state.master_mailbox, ExamplesRequestMessage(myid(), state.worker_mailbox))
end
function handle(state::WorkerState, message::TestExampleIndicesMessage)
	accum=0
	for i in message.indices
		example=trainfeatures(i)
		label=map(x->if x==trainlabel(i); 1.0; else 0.0; end, 0:9)
		accum+=loss(state.current_params, (example,label))
		yield()
	end

	println("[WORKER] Sending test results")
	put!(state.master_mailbox, TestLossMessage(state.current_params,accum/length(message.indices)))
end
function Base.dot(a::Array,b::Array)
	return vecdot(a,b)
end
function handle(state::WorkerState, message::ReevaluatePolicyMessage)
	println("[WORKER] Computing gradients")
	params=state.current_params.data
	state.update_params(params)
	g1=0
	for i in message.indices
		example=trainfeatures(i)
		label=map(x->if x==trainlabel(i); 1.0; else 0.0; end, 0:9)
		g1+=state.compute_gradient((example,label))
		yield()
	end

	delta=state.hyper_params.learning_rate*g1/length(message.indices)

	params-=delta

	g2=0
	for i in message.indices
		example=trainfeatures(i)
		label=map(x->if x==trainlabel(i); 1.0; else 0.0; end, 0:9)
		g2+=state.compute_gradient((example,label))
		yield()
	end

	a=(1.0-vecdot(g1,g2)/sqrt(vecdot(g1,g1)*vecdot(g2,g2)))/sqrt(vecdot(delta,delta))
	b=vecdot(g1,g1)
	
	println("[WORKER] ASP features: $(a)  $(b)")

	put!(state.master_mailbox,AdaptiveControlPolicyMessage(state.hyper_params))	
end

function handle(state,message::AdaptiveControlPolicyMessage)
	state.hyper_params=message.hyper_params
	println("[WORKER/PARAMSERVER] Committed policy update")
end

function handle(state::WorkerState, message::ParameterUpdateMessage)
	state.current_params = message.parameters
	state.time_var = now()
	state.param_request_pending=false
	println("[WORKER] Processed parameter value update")
end

function handle(state::WorkerState, msg::AdaptiveControlPolicyMessage)
	state.hyper_params = msg.hyper_params;
	println("[WORKER] Processed control policy message")
end

function handle(state::WorkerState, msg::FinishOperationMessage)
	state.exit = true
end

function handle(state::WorkerState, msg::Void)
	#println("[WORKER] Spinning")
	yield()
end

function handle{T}(state::WorkerState, msg::T)
	println("Handler not defined for $(T)")
end

# main worker loop
function worker(id, master_mailbox, worker_mailbox,starting_params,hyper_params)
	println("[WORKER] Initialized")

	#update_params and compute_gradient are functions which do the obvious
	update_params,compute_gradient=AutoDiff.derivative(loss,starting_params.data, sample_input_output())

	state = WorkerState(
	master_mailbox=master_mailbox,
	worker_mailbox=worker_mailbox,
	#tau=0.2,
	update_params=update_params, 
	compute_gradient=compute_gradient, 
	#learning_rate=0.00005,
	current_params=starting_params,
	hyper_params=hyper_params
	)

	println("[WORKER] Requesting examples")
	put!(state.master_mailbox, ExamplesRequestMessage(id, state.worker_mailbox))
	put!(state.master_mailbox, ExamplesRequestMessage(id, state.worker_mailbox))
	put!(state.master_mailbox, ExamplesRequestMessage(id, state.worker_mailbox))
	
	while !state.exit
		handle(state, take!(state.worker_mailbox))

		#Stale Parameter Checks
		#=
		time_elapsed = Int(now() - state.time_var)
		if time_elapsed >= state.hyper_params.tau * 1000 && !state.param_request_pending
			println("[WORKER] Requesting parameter value updates")
			println("[WORKER] Time last parameter update request: $(time_elapsed)ms");
			put!(state.master_mailbox, ParameterUpdateRequestMessage(state.worker_mailbox));
			state.param_request_pending = true;
		end
		=#
	end

	put!(state.master_mailbox, FinishedOperationMessage(id))
	println("[WORKER] Shutting down")
end
