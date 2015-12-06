using MNIST

### INITIALIZATION ###

workers = Tuple{Int, Any, Any}[]
paramservers = Tuple{Int, Any}[]
num_workers = 3
num_paramservers = 1

function initialize_nodes(master_mailbox)
	add_paramservers(num_paramservers, master_mailbox)
	add_workers(num_workers, master_mailbox)
end

function add_paramserver()
	add_paramservers(1)
end

function add_paramservers(count,master_mailbox)
	ids = add_procs(count)
	# todo: remove wait
	for id in ids
		pserver_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		remotecall_fetch(paramserver_setup, id, master_mailbox,pserver_mailbox)
		push!(paramservers, (id, pserver_mailbox))
	end
end

function remove_paramserver()
	#=
	id, ref, master_recv_channel = pop!(paramservers)
	put!(master_recv_channel, CeaseOperationMessage())
	=#
end

function add_worker(master_channel)
	add_workers(1, master_channel)
end

function add_workers(count, master_mailbox)
	ids = add_procs(count)
	for id in ids
		worker_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		ref = @spawnat id PABASTO.worker(id, master_mailbox,worker_mailbox)
		push!(workers, (id, ref, worker_mailbox))
	end
end

function remove_worker()
	id, ref, worker_mailbox = pop!(workers)
	put!(worker_mailbox, CeaseOperationMessage())
end

### REQUEST HANDLING ###

train_examples, train_labels = traindata()
num_train_examples = size(train_examples, 2)
num_processed_examples = 0

# parameters for adaptive control policy
tau = 5
num_workers = 3
batch_size = 10

#REMOVE LATER
num_train_examples = 1000;
#REMOVE LATER
flag = true;

type MasterState
	master_mailbox
	pservers
	workers
end

# Handle request from workers for more examples
function handle(state::MasterState,request::ExamplesRequestMessage)
	global num_train_examples
	global num_processed_examples
	global batch_size

	global shut

	id = request.id
	channel = request.master_recv_channel

	count = 0;
	examples = []
	while count < batch_size && num_processed_examples < num_train_examples
		example_id = num_processed_examples + 1
		push!(examples, example_id)
		count = count + 1
		num_processed_examples = num_processed_examples + 1
	end

	put!(channel, ExampleIndicesMessage(examples))
	if (isempty(examples))
		println("[MASTER] Processed all examples")
		return false
	end
	println("[MASTER] Assigned examples $(examples) to worker $(id)")
	return true
end

function handle(state::MasterState,msg::GradientUpdateMessage)
	println("[MASTER] Dispatching GradientUpdateMessage")
	remotecall(handle,state.pservers[rand(1:end)][1],msg)
end

function handle(state::MasterState,msg::ParameterUpdateRequestMessage)
	println("[MASTER] Dispatching ParameterUpdateRequestMessage")
	remotecall(handle,state.pservers[rand(1:end)][1],msg)
end

function handle(state::MasterState,msg::Void)
	println("[MASTER] Spinning")
	sleep(1)
end

function master()
	master_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), 1)
	initialize_nodes(master_mailbox)
	state=MasterState(master_mailbox, paramservers,workers)
	
	while true
		handle(state,take!(state.master_mailbox))
		
		#=
=======
# Handle cease operation message
function handle_request(request::CeaseOperationMessage)
	return false
end

function master(master_channel)
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
>>>>>>> d740cbecf0187b43dc307e1083fa453a439208c9
			msg = AdaptiveControlPolicyMessage(tau, num_workers, batch_size);
			for i = 1:length(workers)
				worker_tup = workers[i];
				worker_control_channel = worker_tup[4];
				put!(worker_control_channel, msg);
			end
<<<<<<< HEAD
			println("[MASTER] Control Policy Messages Sent");
		=#
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
