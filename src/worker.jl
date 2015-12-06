### Worker State ###
type WorkerState
	current_params::Parameter
	master_mailbox
	worker_mailbox
	tau
	time_var
	param_request_pending::Bool
end

include("gradient_computations.jl")

function handle(state::WorkerState, message::ExampleIndicesMessage)
	grad=compute_gradient(state.current_params, message.indices)
	println("[WORKER] Sending gradient updates")
	put!(state.master_mailbox, GradientUpdateMessage(grad))

	println("[WORKER] Requesting examples")
	put!(state.master_mailbox, ExamplesRequestMessage(myid(), state.worker_mailbox))
end
function handle(state::WorkerState, message::ParameterUpdateMessage)
	state.current_params = message.parameters;
	state.time_var = now();
	state.param_request_pending=false
	println("[WORKER] Worker has received and processed parameter value update")
end
function handle(state::WorkerState, msg::AdaptiveControlPolicyMessage)
	state.tau = msg.tau;
	println("[WORKER] Worker has received and processed control policy message")
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
	println("[WORKER] initialized")

	state = WorkerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]), master_mailbox,worker_mailbox,1.0,now(),false)

	println("[WORKER] Requesting examples")
	put!(state.master_mailbox, ExamplesRequestMessage(id, state.worker_mailbox))
	put!(state.master_mailbox, ExamplesRequestMessage(id, state.worker_mailbox))
	put!(state.master_mailbox, ExamplesRequestMessage(id, state.worker_mailbox))
	while true
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
end
