using MNIST

### INITIALIZATION ###

workers = Tuple{Int, Any, Any}[]
paramservers = Tuple{Int, Any, Any}[]
num_workers = 3
num_paramservers = 1
pserver_gradient_update_channel = RemoteChannel(() -> Channel(num_workers * 10), 1)
pserver_update_request_channel = RemoteChannel(() -> Channel(num_workers * 10), 1)

function initialize_nodes(master_channel)
	for i = 1:num_paramservers
		add_paramserver()
	end
	for i = 1:num_workers
		add_worker(master_channel)
	end
end

function add_paramserver()
	id = add_proc()
	# todo: remove wait
	master_recv_channel = RemoteChannel(() -> Channel(10), id);
	remotecall_fetch(paramserver_setup, id, master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel);
	ref = @spawnat id paramserver()
	push!(paramservers, (id, ref, master_recv_channel))
end

function add_worker(master_channel)
	id = add_proc()
	master_recv_channel = RemoteChannel(() -> Channel(10), id);
	pserver_recv_update_channel = RemoteChannel(() -> Channel(10), id);
	ref = @spawnat id worker(id, master_channel, master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
	push!(workers, (id, ref, master_recv_channel))
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

# Handle request from workers for more examples
function handle_request(request::ExamplesRequestMessage)
	global num_train_examples
	global num_processed_examples
	global batch_size

	id = request.id
	channel = request.master_recv_channel
	examples = []

	count = 0;
	while count < batch_size && num_processed_examples < num_train_examples
		example_id = num_processed_examples + 1
		push!(examples, example_id)
		count = count + 1
		num_processed_examples = num_processed_examples + 1
	end

	put!(channel, ExampleIndicesMessage(examples));
	if (isempty(examples))
		println("[MASTER] Processed all examples")
		return false
	end
	println("[MASTER] Assigned examples $(examples) to worker $(id)")
	return true
end

function master(master_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_ids, worker_ids, paramservers, workers)
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
			msg = AdaptiveControlPolicyMessage(tau, num_workers, batch_size);
			for i = 1:length(workers)
				worker_tup = workers[i];
				worker_control_channel = worker_tup[4];
				put!(worker_control_channel, msg);
			end
			println("[MASTER] Control Policy Messages Sent");
		end
end

function get_pserver_gradient_update_channel()
	if isready(pserver_gradient_update_channel)
		return take!(pserver_gradient_update_channel)
	else
		return nothing
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
