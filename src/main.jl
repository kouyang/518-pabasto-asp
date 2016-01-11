function add_pabasto_procs(count)
	ids = addprocs(count)
	refs=[remotecall(()->eval(Main, quote
		if myid() != 1 && myid() != 2
			#redirect_stderr(open("$(myid()).err", "w"))
			redirect_stdout(open("$(myid()).out", "w"))
		end
		using PABASTO
	end), id)
	for id in ids
	]
	for ref in refs
		wait(ref)
	end
	return ids
end

using PABASTO

refs=[]
for start in ["0.1","0.5","0.7"]
	for learning_rate in [0.001,0.005]
		for num_workers in [2,6]
			for batch_size in [50,100]
				starting_params=deserialize(open("intervals/$(start).jls","r"))
				hyper_params=PABASTO.HyperParameters(
				examples_batch_size=batch_size,
				learning_rate=learning_rate,
				tau=0.5,
				num_workers=num_workers,
				num_paramservers=1,
				max_num_epochs=4,
				)

				save_folder="$(start)-$(hyper_params)"
				run(`rm -rf $(save_folder)`)
				run(`mkdir -p $(save_folder)`)
				f=open("$(save_folder)/hyper_params.txt","w")
				println(f,hyper_params)
				close(f)
				save_folder="$(start)-$(hyper_params)/"

				master_id = add_pabasto_procs(1)[1]
				push!(refs,@spawnat master_id PABASTO.master(starting_params=starting_params,hyper_params=hyper_params,save_folder=save_folder))
			end
		end
	end
end
for r in refs
	wait(r)
end
rmprocs(workers())
