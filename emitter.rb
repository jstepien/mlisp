require 'label_gen'
require 'nodes'

# Manages emitting x86 assembly.
class Emitter
	# Creates a new label generator and an empty array of lexemes' labels.
	def initialize(symbol_table)
		@label = LabelGen.new
		@symbol_table = symbol_table
		@lexemes_labels = {}
	end

	# Returns a string with the assembly code for given sexps.
	def emit(sexps)
		@buffer = ''
		emit_data sexps
		emit_code sexps
		@buffer
	end

	private

	# Begins a data section and calls Emitter#emit_constants for all sexps.
	def emit_data(sexps)
		data_section
		sexps.each { |sexp| emit_constants sexp }
	end

	# Begins a text section, adds a global 'main' symbol, externs, emits code
	# for lambdas, and emits the main function if there are any sexps which
	# have some actual effect.
	def emit_code(sexps)
		write 'global main'
		emit_stdlib_functions_externs
		text_section
		sexps.each { |sexp| emit_lambdas sexp }
		sexps.delete_if { |sexp| sexp.is_a? Nodes::Lambda }
		emit_main_function sexps if sexps.any?
	end

	# Emits the code for the main function.
	def emit_main_function(sexps)
		start_function 'main'
		sexps.each { |sexp| emit_sexp sexp }
		end_function
	end

	# Recursively looks for Nodes::Lambda instances and calls
	# Emitter#emit_lambda for all which will be found.
	def emit_lambdas(node)
		case node
		when Nodes::Sexp
			node.elements.each { |n| emit_lambdas n }
		when Nodes::Cond
			node.options.each do |opt|
				[opt.cond, opt.value].each { |subnode| emit_lambdas subnode }
			end
		when Nodes::Lambda
			emit_lambdas node.value
			emit_lambda node
		end
	end

	# Emits code for a given labda.
	def emit_lambda(lmbd)
		lmbd.label = @label.add :lambda if lmbd.label.nil?
		start_function lmbd.label
		write lmbd.evaluate @label, @symbol_table
		end_function
	end

	# Emits a list of external functions from the standard library. The second
	# line are functions defined in funcs.lisp. They are listed separately
	# because they have to be removed from the output assembly code in order to
	# have the funcs.lisp file compiled without any 'function already defined'
	# errors.
	def emit_stdlib_functions_externs
		write 'extern cons, print, cdr, car, cdar, cadr, caar, cddr, ' +
			'caaar, caadr, caddr, cdddr, cddar, cdadr, cadar, ' +
			'atom, eq, list, numberp, assert, GT, MUL, SUB'
		write 'extern and, null, not, append, or, assoc, eval'
	end

	# Emits code beginning a function.
	def start_function(name)
		write [ "#{name}:", 'push ebp', 'mov ebp, esp' ]
	end


	# Emits code closing a function.
	def end_function
		write [ 'pop ebp', 'ret' ]
	end

	# Adds a given string or a collection of strings to the code buffer.
	def write(code)
		if code.respond_to? :each
			code.each { |instr| write instr }
		else
			@buffer << code + "\n"
		end
	end

	# Emits the result of a given node's Nodes::Node#evaluate method.
	def emit_sexp(node)
		write node.evaluate(@label, @symbol_table)
	end

	# Emits code starting a data section.
	def data_section
		write "section .data"
	end

	# Emits code starting a text section.
	def text_section
		write "section .text"
	end

	# Recursively looks for constants to be emitted, that is numerical
	# constants, quoted symbols, lists etc., and emits a respective code which
	# should be placed in a data section.
	def emit_constants(node)
		case node
		when Nodes::ListNode
			emit_constants node.succ if node.succ
			emit_constants node.data
			emit_list_node node
		when Nodes::Constant
			return if node.label
			node.label = @label.add :constant
			write "#{node.label} dd #{Constants::TYPE_INT}, #{node.value}"
		when Nodes::String
			return if node.label
			lexeme_label = emit_lexeme node.value
			node.label = @label.add :string
			write "#{node.label} dd #{Constants::TYPE_STRING}, #{lexeme_label}"
		when Nodes::QuotedSymbol
			return if node.label
			lexeme_label = emit_lexeme node.name
			node.label = @label.add :quoted_symbol
			write "#{node.label} dd #{Constants::TYPE_SYMBOL}, #{lexeme_label}"
		when Nodes::Sexp
			node.elements.each { |n| emit_constants n }
		when Nodes::Cond
			node.options.each do |opt|
				[opt.cond, opt.value].each { |subnode| emit_constants subnode }
			end
		when Nodes::Lambda
			emit_constants node.value
		end
	end

	# Emits code defining a list node.
	def emit_list_node(node)
		raise "No data label for #{node.inspect}" unless node.data.label
		node.label = @label.add :list_node
		write "#{node.label} dd #{Constants::TYPE_NODE}, #{node.data.label}," +
			" #{node.succ ? node.succ.label : 0}"
	end

	# Emits code which defines a lexeme's value as an array of chars.
	def emit_lexeme(value)
		return @lexemes_labels[value] if @lexemes_labels.include? value
		label = @label.add :lexeme
		write "#{label} db \"#{value}\", 0"
		@lexemes_labels[value] = label
	end
end
