require 'tempfile'
require 'parser'
require 'lexer'
require 'quoter'
require 'emitter'
require 'semantic_check'
require 'cond_handler'
require 'lambda_handler'
require 'defun_handler'
require 'ostruct'

# Manages the whole compilation process using the Compiler#compile method.
class Compiler
	# Accepts a hash which should contain following options:
	# [:input] The input file's name
	# [:output] The output file's name
	# [:link] Should we link the object file and create an executable?
	# [:assemble] Should we call nasm and assemble? If false, implies that
	#             :link is false as well.
	def initialize(opts={})
		@assemble = opts[:assemble]
		@link = @assemble and opts[:link]
		@outputname = opts[:output]
		prepare_output opts[:output]
		prepare_input opts[:input]
	end

	# Parses the input file, applies handlers of special kinds of sexps,
	# generates the assembly code. Depending on the options passed to the
	# constructor it can also assemble or link the result.
	def compile
		sexps = Parser.new(Lexer.new).parse(@input)
		Quoter.new.apply sexps
		# NOTE: OpenStructs are a temporary solution.
		# TODO: Refactor it, make this method shorter, extract the symbol table
		# initialisation to another function.
		symbol_table = {
			'>' => 'GT',
			'>=' => 'GE',
			'<' => 'LT',
			'<=' => 'LE',
			'+' => 'ADD',
			'-' => 'SUB',
			'/' => 'DIV',
			'*' => 'MUL',
		} .reduce({}) do |hash, pair|
			hash.merge({ pair.first => OpenStruct.new({:label => pair.last}) })
		end
		symbol_table.merge! DefunHandler.new.apply sexps
		LambdaHandler.new.apply sexps
		CondHandler.new.apply sexps
		SemanticCheck.apply sexps
		@assembly = Emitter.new(symbol_table).emit sexps
		if @assemble
			assemble
			link if @link
		else
			output_assembly
		end
	end

	private

	# Opens the output file or sets it to STDOUT if filename is equal to '-'.
	# Sets the output file name. It forbids outputting binary data to STDOUT.
	def prepare_output(filename)
		@output = (filename == '-') ? $stdout : File.open(filename, 'w')
		if @assemble or @link
			raise 'I refuse to output binary data to stdout' if filename == '-'
			@output_name = filename
		end
	end

	# Opens the input file or sets it to STDIN if filename is equal to '-'.
	# Sets the input file name.
	def prepare_input(filename)
		@input_name = filename
		@input = (filename == '-') ? $stdin : File.open(filename, 'r')
	end

	# Returns the name of an object file in which assembler's output will be
	# placed.
	def object_file_name
		if @link
			File.dirname(@input_name) + '/' + File.basename(@input_name, '.*') + '.o'
		else
			@output_name
		end
	end

	# Saves the assembly code in the output file.
	def output_assembly
		@output.write(@assembly)
	end

	# Saves the assembly code in a temporary file and calls Compiler#spawn_nasm.
	def assemble
		Tempfile.open File.basename(@input_name) + '.asm' do |file|
			file.write @assembly
			file.close
			spawn_nasm file.path
		end
	end

	# Forks, runs nasm and waits for it to finish.
	def spawn_nasm(input)
		if (child = fork).nil?
			exec "nasm -felf -o #{object_file_name} #{input}"
		end
		Process.wait child
		raise "nasm failed!" if $?.exitstatus != 0
	end

	# Forks, runs a C compiler and waits for it to finish.
	def link
		if (child = fork).nil?
			exec "#{compiler} #{link_flags} -o #{@output_name} " +
				"#{object_file_name} -lmlisp"
		end
		Process.wait child
		raise "#{compiler} failed!" if $?.exitstatus != 0
		File.unlink object_file_name
	end

	# Returns a command running a C compiler.
	def compiler
		ENV['CC'] || 'cc'
	end

	# Returns user-specified LDFLAGS.
	def link_flags
		ENV['LDFLAGS']
	end
end
