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
	end

	println("[WORKER] Sending test results")
	put!(state.master_mailbox, TestLossMessage(state.current_params,accum/length(message.indices)))
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
		time_elapsed = Int(now() - state.time_var)
		if time_elapsed >= state.hyper_params.tau * 1000 && !state.param_request_pending
			println("[WORKER] Requesting parameter value updates")
			println("[WORKER] Time last parameter update request: $(time_elapsed)ms");
			put!(state.master_mailbox, ParameterUpdateRequestMessage(state.worker_mailbox));
			state.param_request_pending = true;
		end
	end

	put!(state.master_mailbox, FinishedOperationMessage(id))
	println("[WORKER] Shutting down")
end
