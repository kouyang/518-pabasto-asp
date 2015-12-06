using MNIST

### TYPE DEFINITION ###

type MasterState
	master_mailbox
	paramservers
	workers
	num_train_examples
	num_processed_examples
	num_epoch
	max_num_epoches
	# parameters for adaptive control policy
	tau
	num_workers
	num_paramservers
	# number of examples the master sends to worker in response to ExamplesRequestMessage
	examples_batch_size
	# number of examples the worker processes to compute a gradient update
	batch_size
end

### INITIALIZATION ###

function initialize_nodes(state::MasterState)
	add_paramservers(state, state.num_paramservers)
	add_workers(state, state.num_workers)
end

function add_paramservers(state::MasterState, count)
	ids = add_procs(count)
	# todo: remove wait
	for id in ids
		pserver_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		remotecall_fetch(paramserver_setup, id, state.master_mailbox, pserver_mailbox)
		push!(state.paramservers, (id, pserver_mailbox))
	end
end

function remove_paramserver(state::MasterState)
	#=
	id, pserver_mailbox = pop!(state.paramservers)
	put!(pserver_mailbox, CeaseOperationMessage())
	=#
end

function add_workers(state::MasterState, count)
	ids = add_procs(count)
	for id in ids
		worker_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		ref = @spawnat id PABASTO.worker(id, state.master_mailbox, worker_mailbox)
		push!(state.workers, (id, ref, worker_mailbox))
	end
end

function remove_worker(state::MasterState)
	id, ref, worker_mailbox = pop!(state.workers)
	put!(worker_mailbox, CeaseOperationMessage())
end

### REQUEST HANDLING ###

# Handle request from workers for more examples
function handle(state::MasterState,request::ExamplesRequestMessage)
	
	if state.num_processed_examples >= state.num_train_examples && state.num_epoch < state.max_num_epoches
		state.num_processed_examples = 0;
		state.num_epoch = state.num_epoch + 1;
	elseif state.num_processed_examples >= state.num_train_examples
		# terminate execution
		return false
	end
	
	id = request.id
	worker_mailbox = request.worker_mailbox

	count = 0;
	examples = []
	while count < state.batch_size && state.num_processed_examples < state.num_train_examples
		example_id = state.num_processed_examples + 1
		push!(examples, example_id)
		count = count + 1
		state.num_processed_examples = state.num_processed_examples + 1
	end
	
	put!(worker_mailbox, ExampleIndicesMessage(examples))
	if (isempty(examples))
		println("[MASTER] Processed all examples")
		return false
	end
	println("[MASTER] Assigned examples $(examples) to worker $(id)")
	return true
end

function handle(state::MasterState,msg::GradientUpdateMessage)
	println("[MASTER] Dispatching GradientUpdateMessage")
	remotecall(handle,state.paramservers[rand(1:end)][1],msg)
end

function handle(state::MasterState,msg::ParameterUpdateRequestMessage)
	println("[MASTER] Dispatching ParameterUpdateRequestMessage")
	remotecall(handle,state.paramservers[rand(1:end)][1],msg)
end

function handle(state::MasterState,msg::Void)
	println("[MASTER] Spinning")
	sleep(1)
end

function master()
	
	master_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), 1)
	
	workers = Tuple{Int, Any, Any}[]
	paramservers = Tuple{Int, Any}[]
	
	train_examples, train_labels = traindata()
	num_train_examples = size(train_examples, 2)
	num_processed_examples = 0
	num_epoch = 1
	max_num_epoches = 1
	
	# parameters for adaptive control policy
	tau = 5.0
	num_workers = 3
	num_paramservers = 1
	# number of examples the master sends to worker in response to ExamplesRequestMessage
	examples_batch_size = 50
	# number of examples the worker processes to compute a gradient update
	batch_size = 10
	
	#REMOVE LATER
	num_train_examples = 1000;
	#REMOVE LATER
	flag = true;
	
	state = MasterState(master_mailbox, paramservers, workers, num_train_examples, num_processed_examples, num_epoch, max_num_epoches, tau, num_workers, num_paramservers, examples_batch_size, batch_size)
	initialize_nodes(state)
	
	while true
		handle(state,take!(state.master_mailbox))
	end
	
end

# COMMENTED OUT CODE - IGNORE
#=
# Handle cease operation message
function handle_request(request::CeaseOperationMessage)
	return false
end

function master(master_channel)
	global tau
	global num_workers
	global num_paramservers
	global example_batch_size
	global batch_size
	
	while true
		if isready(master_channel)
			request = take!(master_channel)
			if !handle_request(request)
				return false
			end
		end

		while isready(pserver_gradient_update_channel)
			remotecall(handle,pserver_ids[rand(1:end)],take!(pserver_gradient_update_channel))
		end
		while isready(pserver_update_request_channel)
			remotecall(handle,pserver_ids[rand(1:end)],take!(pserver_update_request_channel))
		end

		#boo = adaptive_control_policy();
		boo = false;

		if boo
			msg = AdaptiveControlPolicyMessage(tau, num_workers, num_paramservers, example_batch_size, batch_size);
			for i = 1:length(workers)
				worker_tup = workers[i];
				worker_mailbox = worker_tup[3];
				put!(worker_mailbox, msg);
			end
			
			println("[MASTER] Control Policy Messages Sent");
		end
	end
end

function adaptive_control_policy()
	global tau
	global num_workers
	global batch_size
	global flag

	randy = RandomDevice();

	if flag
		tau = tau + 1.0;
		flag = false;
		return true;
	else
		return false;
	end
end
=#
