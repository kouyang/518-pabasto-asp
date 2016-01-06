function add_pabasto_procs(count)
	ids = addprocs(count)
	refs=[remotecall(()->eval(Main, quote
		if myid() != 1
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

master_id = add_pabasto_procs(1)[1]
fetch(@spawnat master_id PABASTO.master())
