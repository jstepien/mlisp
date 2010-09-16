require 'log'
require 'nodes'

class LambdaHandler
	# Applies LambdaHandler#handle_lambdas to all given sexps.
	def apply(sexps)
		sexps.map! { |sexp| handle_lambdas(sexp) }
	end

	private

	def syntax_error
		Log.error 'Invalid lambda syntax.'
	end

	# Recursively tries to find all sexps whose first element is 'lambda. Then
	# replaces them with instances of Nodes::Lambda.
	def handle_lambdas(node)
		return node unless node.is_a? Nodes::Sexp
		if node.first_elem_is_sym? and node.function == 'lambda'
			syntax_error unless node.arguments.count == 2 and valid_args? node
			args = node.arguments[0].elements.map do
				|x| Nodes::Lambda::Arg.new x.name
			end
			Nodes::Lambda.new args, node.arguments[1]
		else
			node.elements.map! { |subnode| handle_lambdas subnode }
			node
		end
	end

	# True if the node is a correctly formed lambda, that is
	#   (lambda (symbol symbol...) anything)
	def valid_args?(node)
		args_sexp = node.arguments[0]
		args_sexp.is_a? Nodes::Sexp and args_sexp.elements.all? do
			|x| x.is_a? Nodes::Symbol
		end
	end
end
