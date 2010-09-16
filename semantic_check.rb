require 'log'
require 'nodes'

# Classes doing some semantic checks.
module SemanticCheck
	# Checks whether arguments' numbers are correct.
	class ArgCount
		# Numbers of arguments accepted by a functions from the standard
		# library.
		StdLibArgsCount = {
			'cons' => 2,
			'car' => 1,
			'cdr' => 1,
			'cdar' => 1,
			'cadr' => 1,
			'print' => 1,
			'atom' => 1,
			'eq' => 2,
		}

		def check(node)
			return unless node.is_a? Nodes::Sexp
			if (node.first_elem_is_sym? and
				StdLibArgsCount.include? node.function)
				if node.arguments.count != StdLibArgsCount[node.function]
					Log.error("#{node.arguments.count} argument(s) for " +
							  "#{node.function} given, " +
							  "#{StdLibArgsCount[node.function]} expected.")
				else
					# TODO: count other functions' args
				end
			end
			node.arguments.each { |subnode| check subnode }
		end
	end

	# Applies all available semantic tests.
	def self.apply(sexps)
		check = ArgCount.new
		sexps.each { |sexp| check.check(sexp) }
	end
end
