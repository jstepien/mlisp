require 'log'
require 'nodes'

class CondHandler
	# Applies CondHandler#handle_conds to all given sexps.
	def apply(sexps)
		sexps.map! { |sexp| handle_conds(sexp) }
	end

	private

	# Recursively tries to find all sexps whose first element is 'cond. Then
	# replaces them with instances of Nodes::Cond.
	def handle_conds(node)
		case node
		when Nodes::Sexp
			if node.first_elem_is_sym? and node.function == 'cond'
				cond = Nodes::Cond.new
				node.arguments.each do |arg|
					if not (arg.is_a? Nodes::Sexp and arg.elements.count == 2)
						Log.error 'Invalid cond syntax.'
					end
					cond.add_option arg.elements[0],
						handle_conds(arg.elements[1])
				end
				cond
			else
				node.elements.map! { |subnode| handle_conds subnode }
				node
			end
		when Nodes::Lambda
			node.value = handle_conds node.value
			node
		else
			node
		end
	end
end
