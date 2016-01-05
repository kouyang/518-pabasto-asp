### Param Server State ###

const DISPLAY_FILTERS=false

if DISPLAY_FILTERS
	using Images, ImageView
end
type ParamServerState
	params
	master_mailbox
	shared_pserver_mailbox
	pserver_mailbox
	accumulated_gradients
	n_accumulated_gradients
	index::Int
	time_var
	param_request_pending::Bool
	tau
end

#local_state = nothing
#=
function paramserver_setup(master_mailbox, pserver_mailbox)
	global local_state = ParamServerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]),master_mailbox,pserver_mailbox)
	if DISPLAY_FILTERS
		global c = canvasgrid(4,5)
	end
end
=#

function paramserver(master_mailbox, shared_pserver_mailbox,pserver_mailbox, index)
	state = ParamServerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]),master_mailbox,shared_pserver_mailbox,pserver_mailbox, SimpleGradient(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]), 0,index,now(),false,5)
	println("[PARAM SERVER] initialized")

	while true
		msg=take!(state.pserver_mailbox)
		if msg==nothing
			msg=take!(state.shared_pserver_mailbox,state.index)
		end
		#handle(state,take!(state.pserver_mailbox))
		handle(state,msg)
		if state.index>=2
			low=max(state.index/4,1)
			high=min(state.index/2,state.index-1)
			@assert high >= low
			if state.n_accumulated_gradients > 2
				println("[PARAM SERVER] Pushing gradients")
				put!(state.shared_pserver_mailbox,GradientUpdateMessage(state.accumulated_gradients),low,high)
				state.accumulated_gradients.data*=0
				state.n_accumulated_gradients=0
			end
			time_elapsed = Int(now() - state.time_var)
			if time_elapsed >= state.tau * 1000 && !state.param_request_pending
				println("[PARAM SERVER] Requesting parameter value updates")
				println("Time elapsed (in ms) since last parameter value update request is ", time_elapsed);
				put!(state.shared_pserver_mailbox, ParameterUpdateRequestMessage(state.pserver_mailbox),low,high);
				state.param_request_pending = true;
			end
		end
	end
end

function handle(state:: ParamServerState, message::Void)
	#println("[PARAM SERVER] Spinning")
	#sleep(0.01)
end
#=
function handle(state, message::ParameterRequestMessage)
	#put!(state.master_mailbox, ParameterUpdateMessage(state.params))
end
=#

function handle(state::ParamServerState, message::ParameterUpdateMessage)
	state.params.data = message.parameters.data
	state.time_var = now()
	state.param_request_pending=false
	println("[PARAM SERVER] Param server has received and processed parameter value update")
end

function handle(state, message::ParameterUpdateRequestMessage)
	println("[PARAM SERVER] Reading params")
	put!(message.worker_mailbox,ParameterUpdateMessage(state.params))
end

function updateview()
	for i in 1:10
		view(c[i],f(local_state.params.data[1][i,:]),interactive=false)
	end
end
function f(x)
	a=x-minimum(x)
	a/=maximum(a)
	grayim(transpose(reshape(a,(28,28))))
end
function handle(state::ParamServerState,message::GradientUpdateMessage)
	println("[PARAM SERVER] Writing params")
	update(state.params, message.gradient)
	state.n_accumulated_gradients+=1
	if DISPLAY_FILTERS
		updateview()
	end
end
#=
function handle(message::InitiateGossipMessage)
	global local_state
	println("[PARAM SERVER] Initiating gossip")
	remotecall(handle, message.pserver_id, ParameterGossipMessage(local_state.params, message.self_pserver_id));
end

function handle(message::ParameterGossipMessage)
	global local_state
	println("[PARAM SERVER] Paramserver has received ParameterGossipMessage")
	varA = message.parameters
	operand = half_subtract(varA, local_state.params)
	# local_state.params is varB
	local_state.params = add(local_state.params, operand)
	remotecall(handle, message.pserver_id, ParameterFinalGossipMessage(operand))
end

function handle(message::ParameterFinalGossipMessage)
	global local_state
	println("[PARAM SERVER] Paramserver has received ParameterFinalGossipMessage")
	# local_state.params is varA'
	local_state.params = subtract(local_state.params, message.parameters)
end
=#
