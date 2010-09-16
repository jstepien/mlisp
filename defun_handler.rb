require 'log'
require 'nodes'

class DefunHandler
	# Creates an empty symbol table.
	def initialize
		@symbol_table = {}
	end

	# Applies DefunHandler#handle_defuns to all given sexps. Returns a hash of
	# functions' symbols.
	def apply(sexps)
		sexps.map! { |sexp| handle_defuns(sexp) }
		@symbol_table
	end

	private

	def syntax_error
		Log.error 'Invalid defun syntax.'
	end

	# Recursively tries to find all sexps whose first element is 'defun. Then
	# replaces them with instances of Nodes::Lambda and adds new lambdas to the
	# symbol table.
	def handle_defuns(node)
		return node unless node.is_a? Nodes::Sexp
		if node.first_elem_is_sym? and node.function == 'defun'
			syntax_error unless node.arguments.count == 3 and valid_args? node
			args = node.arguments[1].elements.map do
				|x| Nodes::Lambda::Arg.new x.name
			end
			lmbd = Nodes::Lambda.new args, node.arguments[2]
			lmbd.label = node.arguments[0].name
			@symbol_table.merge!({ lmbd.label => lmbd })
			lmbd
		else
			node.elements.map! { |subnode| handle_defuns subnode }
			node
		end
	end

	# True if the node is a correctly formed defun, that is
	#   (defun symbol (symbol symbol...) anything)
	def valid_args?(node)
		args_sexp = node.arguments[1]
		args_sexp.is_a? Nodes::Sexp and args_sexp.elements.all? do
			|x| x.is_a? Nodes::Symbol
		end and node.arguments[0].is_a? Nodes::Symbol
	end
end
