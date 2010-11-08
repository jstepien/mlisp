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
		@input = opts[:input]
		@output = opts[:output]
		@link = opts[:link]
		@assemble = opts[:assemble]
	end

	# Opens a file, parses it, applies handlers of special kinds of sexps,
	# generates the assembly code. Depending on the options passed to the
	# constructor it can also assemble or link the result.
	def compile
		sexps = Parser.new(Lexer.new).parse(File.open(@input))
		Quoter.new.apply sexps
		# NOTE: OpenStructs are a temporary solution.
		# TODO: Refactor it, make this method shorter, extract the symbol table
		# initialisation to another function.
		symbol_table = {
			'>' => 'GT',
			'*' => 'MUL',
			'-' => 'SUB',
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

	# Returns the name of an object file in which assembler's output will be
	# placed.
	def object_file_name
		if @link
			File.dirname(@input) + '/' + File.basename(@input, '.*') + '.o'
		else
			@output
		end
	end

	# Saves the assembly code in the output file.
	def output_assembly
		File.open(@output, 'w').write(@assembly)
	end

	# Saves the assembly code in a temporary file and calls Compiler#spawn_nasm.
	def assemble
		Tempfile.open File.basename(@input) + '.asm' do |file|
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
			exec "#{compiler} #{link_flags} -o #{@output} " +
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
