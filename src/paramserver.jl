### Param Server State ###

const DISPLAY_FILTERS=false

if DISPLAY_FILTERS
	using Images, ImageView
end

type ParamServerState
	params
	master_mailbox
	pserver_mailbox
	exit
end

local_state = nothing

function updateview()
	global local_state
	for i in 1:10
		view(c[i],f(local_state.params.data[1][i,:]),interactive=false)
	end
end

function f(x)
	a=x-minimum(x)
	a/=maximum(a)
	grayim(transpose(reshape(a,(28,28))))
end

function handle(message::ParameterRequestMessage)
	global local_state
	put!(local_state.master_mailbox, ParameterUpdateMessage(local_state.params))
end

function handle(message::ParameterUpdateRequestMessage)
	global local_state
	println("[PARAM SERVER] Reading params")
	put!(message.worker_mailbox, ParameterUpdateMessage(local_state.params))
end

function handle(message::GradientUpdateMessage)
	global local_state
	global DISPLAY_FILTERS
	
	println("[PARAM SERVER] Writing params")
	update(local_state.params, message.gradient)
	if DISPLAY_FILTERS
		updateview()
	end
end

function handle(message::InitiateGossipMessage)
	global local_state
	println("[PARAM SERVER] Initiating gossip")
	put!(message.pserver_mailbox, ParameterGossipMessage(local_state.params, local_state.pserver_mailbox))
end

function handle(message::ParameterGossipMessage)
	global local_state
	println("[PARAM SERVER] Paramserver has received ParameterGossipMessage")
	varA = message.parameters
	operand = half_subtract(varA, local_state.params)
	# local_state.params is varB
	local_state.params = add(local_state.params, operand)
	put!(message.pserver_mailbox, ParameterFinalGossipMessage(operand))
end

function handle(message::ParameterFinalGossipMessage)
	global local_state
	println("[PARAM SERVER] Paramserver has received ParameterFinalGossipMessage")
	# local_state.params is varA'
	local_state.params = subtract(local_state.params, message.parameters)
end

function handle(message::CeaseOperationMessage)
	global local_state
	local_state.exit = true
end

function handle(message::Void)
	println("[PARAM SERVER] Spinning")
	sleep(1)
end

function paramserver(id, master_mailbox, pserver_mailbox)
	global local_state
	global DISPLAY_FILTERS
	
	local_state = ParamServerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]), master_mailbox, pserver_mailbox, false)
	
	if DISPLAY_FILTERS
		global c = canvasgrid(4,5)
	end
	
	while !local_state.exit
		handle(take!(local_state.pserver_mailbox))
	end
	
	put!(local_state.master_mailbox, CeasedOperationMessage(id))
	println("[PARAM SERVER] Shutting down")
end
