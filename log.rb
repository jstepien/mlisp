# Diagnostic functions.
module Log
	# Prints the given string on stderr and exits with an error status.
	def Log.error(str)
		STDERR.puts "Error: #{str}"
		exit 1
	end
end
