### Worker State ###
type WorkerState
	current_params::Parameter
	master_mailbox
	worker_mailbox
	tau
	batch_size
	time_var
	param_request_pending::Bool
	update_params
	compute_gradient
	learning_rate
	exit
end

include("gradient_computations.jl")

function handle(state::WorkerState, message::ExampleIndicesMessage)
	grad=compute_gradient(state, message.indices)
	println("[WORKER] Sending gradient updates")
	put!(state.master_mailbox, GradientUpdateMessage(grad))

	println("[WORKER] Requesting examples")
	put!(state.master_mailbox, ExamplesRequestMessage(myid(), state.worker_mailbox))
end

function handle(state::WorkerState, message::ParameterUpdateMessage)
	state.current_params.data = message.parameters.data
	state.time_var = now()
	state.param_request_pending=false
	println("[WORKER] Worker has received and processed parameter value update")
end

function handle(state::WorkerState, msg::AdaptiveControlPolicyMessage)
	state.batch_size = msg.batch_size;
	state.tau = msg.tau;
	println("[WORKER] Worker has received and processed control policy message")
end

function handle(state::WorkerState, msg::FinishOperationMessage)
	state.exit = true
end

function handle(s::WorkerState,state::Void)
	println("[WORKER] Spinning")
	sleep(1)
end

function handle{T}(s, state::T)
	println("Handler not defined for $(T)")
end

# main worker loop
function worker(id, master_mailbox, worker_mailbox)
	println("[WORKER] Initialized")

	#update_params and compute_gradient are functions which do the obvious
	update_params,compute_grad=AutoDiff.derivative(error,Any[dummy_weights1,dummy_biases1], Any[dummy_input,dummy_output])

	state = WorkerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]), master_mailbox, worker_mailbox, 1.0, 10, now(), false, update_params, compute_grad,0.0003, false)

	println("[WORKER] Requesting examples")
	put!(state.master_mailbox, ExamplesRequestMessage(id, state.worker_mailbox))
	put!(state.master_mailbox, ExamplesRequestMessage(id, state.worker_mailbox))
	put!(state.master_mailbox, ExamplesRequestMessage(id, state.worker_mailbox))
	while !state.exit
		handle(state,take!(state.worker_mailbox))

		#Stale Parameter Checks
		time_elapsed = Int(now() - state.time_var)
		if time_elapsed >= state.tau * 1000 && !state.param_request_pending
			println("[WORKER] Requesting parameter value updates")
			println("Time elapsed (in ms) since last parameter value update request is ", time_elapsed);
			put!(state.master_mailbox, ParameterUpdateRequestMessage(state.worker_mailbox));
			state.param_request_pending = true;
		end
	end

	put!(state.master_mailbox, FinishedOperationMessage(id))
	println("[WORKER] Shutting down")
end
