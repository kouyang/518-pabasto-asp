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
	time_var
	exit
	# parameters for adaptive control policy
	tau
	num_workers
	num_paramservers
	# number of examples the master sends to worker in response to ExamplesRequestMessage
	examples_batch_size
	# number of examples the worker processes to compute a gradient update
	batch_size
	gossip_time
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
		# BEHAVIOUR IS NOT CORRECT THOUGH - SHOULD WAIT FOR ALL WORKERS TO FINISH
		# PROCESSING EXAMPLES THAT THEY ALREADY HAVE, SEND GRADIENT UPDATES TO PARAMSERVERS,
		# ETC
		state.exit = true;
		return;
	end
	
	id = request.id
	worker_mailbox = request.worker_mailbox

	count = 0;
	examples = []
	while count < state.examples_batch_size && state.num_processed_examples < state.num_train_examples
		example_id = state.num_processed_examples + 1
		push!(examples, example_id)
		count = count + 1
		state.num_processed_examples = state.num_processed_examples + 1
	end
	
	
	put!(worker_mailbox, ExampleIndicesMessage(examples))
	
	#=
	if (isempty(examples))
		println("[MASTER] Processed all examples")
		return false
	end
	=#
	
	println("[MASTER] Assigned examples $(examples[1])-$(examples[end]) to worker $(id)")
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
	time_var = now()
	exit = false
	
	# parameters for adaptive control policy
	tau = 20.0
	num_workers = 2
	num_paramservers = 1
	# number of examples the master sends to worker in response to ExamplesRequestMessage
	examples_batch_size = 500
	# number of examples the worker processes to compute a gradient update
	batch_size = 10
	gossip_time = 20.0
	
	#REMOVE LATER
	num_train_examples = 10000;
	#REMOVE LATER
	flag = true
	
	# TO SEE GOSSIP WORK, set num_train_examples to 10,000, and num_paramservers to 2.
	# I suggest running code like julia main.jl > debug.txt so you can search through output
	
	state = MasterState(master_mailbox, paramservers, workers, num_train_examples, num_processed_examples, num_epoch, max_num_epoches, time_var, exit, tau, num_workers, num_paramservers, examples_batch_size, batch_size, gossip_time)
	initialize_nodes(state)
	
	while !state.exit
		handle(state,take!(state.master_mailbox))
		
		# Check whether to initiate gossip
		time_elapsed = Int(now() - state.time_var)
		if num_paramservers > 1 && time_elapsed >= state.gossip_time * 1000
			
			# randomly choose 2 distinct paramservers
			
			pserver1_index = rand(1:length(state.paramservers));
			pserver1_id = state.paramservers[pserver1_index][1];
			
			# can do this because id is really stored in array
			sample_wo_replacement_paramservers = copy(state.paramservers);
			
			sample_wo_replacement_paramservers = deleteat!(sample_wo_replacement_paramservers, pserver1_index);
			
			pserver2_index = rand(1:length(sample_wo_replacement_paramservers));
			pserver2_id = sample_wo_replacement_paramservers[pserver2_index][1];
			
			# now dispatch the initiate gossip messages
			println("[MASTER] Dispatching InitiateGossipMessages")
			remotecall(handle, pserver1_id, InitiateGossipMessage(pserver2_id, pserver1_id))
			
			state.time_var = now();
		end
		
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
	global examples_batch_size
	global batch_size
	global gossip_time
	
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
			msg = AdaptiveControlPolicyMessage(tau, num_workers, num_paramservers, example_batch_size, batch_size, gossip_time);
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
	global num_paramservers
	global examples_batch_size
	global batch_size
	global gossip_time
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
