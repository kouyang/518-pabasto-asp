function add_pabasto_procs(count)
	ids = addprocs(count)
	for id in ids
		remotecall_fetch(()->eval(Main, quote
			if myid() != 1
				redirect_stderr(open("$(myid()).err", "w"))
				redirect_stdout(open("$(myid()).out", "w"))
				function Base.print(x::String)
					print(STDOUT, x)
					flush(STDOUT)
				end
			end
			using PABASTO
		end), id)
	end
	return ids
end

using PABASTO

master_id = add_pabasto_procs(1)[1]
master_mailbox = fetch(@spawnat master_id PABASTO.master_mailbox())
@spawnat master_id PABASTO.master(master_mailbox)
