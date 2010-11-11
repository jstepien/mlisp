# This module consists of definitions of nodes representing elements of a tree
# of s-expressions.
module Nodes
	# The base class of all nodes.
	class Node
		# The label used by the assembler for jmps, movs, etc.
		attr_reader :label

		# Substitutes dashes with underscores.
		def label=(val)
			@label = val.valid_c_symbol
		end

		# Returns an array of instructions evaluating the node and putting the
		# result in EAX.
		def evaluate(label_gen, symbol_table)
			["mov eax, #{label}"]
		end
	end

	# A segment of a list.
	class ListNode < Node
		attr_accessor :data, :succ

		def initialize(data, succ)
			@data = data
			@succ = succ
		end
	end

	# An s-expression.
	class Sexp < Node
		# All elements of the sexp.
		attr_reader :elements

		# Functions which accept an arbitrary number of arguments.
		VarArgFuncs = %w{ list }

		def initialize(elements)
			@elements = elements
		end

		# All elements excluding the first.
		def arguments
			elements.drop 1
		end

		# If the first element is a Nodes::Symbol, it's name, otherwise first
		# element's label.
		def function
			if first_elem_is_sym?
				elements.first.name
			else
				elements.first.label
			end
		end

		# True if the first element is a Nodes::Symbol.
		def first_elem_is_sym?
			elements.first.is_a? Nodes::Symbol
		end

		def evaluate(label_gen, symbol_table)
			output = []
			offset = 0
			if VarArgFuncs.include? function
				output << "push #{Constants::VAR_ARG_DELIM}"
				offset += Constants::DWORD_SIZE
			end
			arguments.reverse.each do |node|
				output += node.evaluate label_gen, symbol_table
				output << 'push eax'
			end
			output += [ "call #{function_label(symbol_table)}",
				"add esp, #{Constants::DWORD_SIZE * arguments.count + offset}" ]
		end

		private

		def function_label(symbol_table)
			if first_elem_is_sym?
				name = elements.first.name
				if symbol_table.include? name
					symbol_table[name].label
				else
					name.valid_c_symbol
				end
			else
				elements.first.label
			end
		end
	end

	# An atom. Not a list, in other words.
	class Atom < Node
	end

	# A symbol which will be sought in the symbol table passed to
	# Nodes::Symbol#evaluate.
	class Symbol < Atom
		# The lexeme of the symbol.
		attr_reader :name

		def initialize(name)
			@name = name
		end

		def evaluate(label_gen, symbol_table)
			Log.error "'#{name}' has no value" unless symbol_table.include? name
			symbol_table[name].evaluate(label_gen, symbol_table)
		end
	end

	# A symbol which will *not* be sought in the symbol table.
	class QuotedSymbol < Atom
		# The lexeme of the symbol.
		attr_reader :name

		def initialize(name)
			@name = name
		end
	end

	# A constant integer.
	class Constant < Atom
		attr_reader :value

		def initialize(value)
			@value = value
		end
	end

	# A constant string.
	class String < Atom
		attr_reader :value

		def initialize(value)
			@value = value
		end
	end

	# An empty list string.
	class EmptyList < Atom
		# Sets @label to 0.
		def initialize
			@label = '0'
		end

		def evaluate(label_gen, symbol_table)
			[ "xor eax, eax" ]
		end
	end

	# A set of conditions and their respective values.
	class Cond < Node
		# An option consisting of a condition and its value which will be
		# evaluated when the condition evaluates to true.
		class Option
			attr_reader :cond, :value

			def initialize(cond, value)
				@cond = cond
				@value = value
			end
		end

		attr :options

		def initialize
			@options = []
		end

		# Adds a new Option instance to @options
		def add_option(cond, value)
			@options << Option.new(cond, value)
		end

		def evaluate(label_gen, symbol_table)
			output = []
			end_label = label_gen.add :end_cond
			options.each do |opt|
				next_opt_label = label_gen.add :cond_option
				output += opt.cond.evaluate(label_gen, symbol_table) +
					[ 'cmp eax, 0', "jz #{next_opt_label}" ] +
					opt.value.evaluate(label_gen, symbol_table) +
					[ "jmp #{end_label}", "#{next_opt_label}:" ]
			end
			output + [ 'mov eax, 0', "#{end_label}:" ]
		end
	end

	# A lambda, an anonymous function.
	class Lambda < Node
		# A lambda's argument.
		class Arg
			attr_reader :name
			# The offset from the EBP, after the lambda is being called.
			attr_accessor :stack_offset

			def initialize(name)
				@name = name
			end

			def evaluate(label_gen, symbol_table)
				[ "mov eax, [ebp+#{stack_offset}]" ]
			end
		end

		attr_reader :args
		attr_accessor :value

		def initialize(args, value)
			@args = args
			@value = value
		end

		def evaluate(label_gen, symbol_table)
			number = 0
			args.each do |arg|
				arg.stack_offset = (2 + number) * Constants::DWORD_SIZE
				number += 1
			end
			args_hash = create_args_hash label_gen
			value.evaluate(label_gen, symbol_table.merge(args_hash))
		end

		private

		# Returns a hash of arguments' names pointing to Lambda::Arg instances.
		# The result is to be merged with a symbol table during the evaluation
		# of the lambda.
		def create_args_hash(label_gen)
			args.reduce({}) { |hash,arg| hash.merge({ arg.name => arg }) }
		end
	end
end

class String
	# Substitutes dashes with underscores.
	def valid_c_symbol
		self.tr '-', '_'
	end
end
