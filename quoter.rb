require 'parser'
require 'log'
require 'constants'

# Looks for quoted expressions and replaces them with constants.
class Quoter
	def initialize
		@quoted_symbols = {}
	end

	# Applies Quoter#find_constants to all given sexps.
	def apply(sexps)
		sexps.map! { |sexp| find_constants sexp }
	end

	private

	# Recursively tries to find all sexps whose first element is 'quote. Then
	# replaces them with quoted constants.
	def find_constants(node)
		if node.is_a? Nodes::Sexp
			first = node.elements.first
			if first.is_a? Nodes::Symbol and first.name == 'quote'
				quote node.elements[1]
			else
				node.elements.map! { |n| find_constants n }
				node
			end
		else
			node
		end
	end

	# Replaces a given node with a constant, quoted node.
	def quote(node)
		case node
		when Nodes::Symbol
			@quoted_symbols[node.name] ||= Nodes::QuotedSymbol.new node.name
		when Nodes::Atom
			node
		when Nodes::Sexp
			node.elements.map! { |n| quote n }
			build_list node
		else
			Log.error "Unexpected #{node}"
		end
	end

	# Creates a list from a quoted s-expression.
	def build_list(node)
		succ = nil
		node.elements.reverse.each do |elem|
			list_node = Nodes::ListNode.new(elem, succ)
			succ = list_node
		end
		succ
	end
end
