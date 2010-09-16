require 'lexer'
require 'log'
require 'tokens'
require 'nodes'

# The grammar supported by the parser is following
#
#   <program>    ::= <sexps>
#   <sexps>      ::= <sexp> <sexps> | epsilon
#   <sexp>       ::= "(" <elements> ")" | <empty-list>
#   <empty-list> ::= "()"
#   <elements>   ::= <element> <elements>
#   <element>    ::= <sexp> | <symbol> | <constant> | <string> | "'" <element>
class Parser
	def initialize(lexer)
		@lexer = lexer
	end

	# Passes the input file to the Lexer and parses it returning an array of
	# s-expressions represented by subclasses of Nodes::Node.
	def parse(input)
		@lexer.input = input
		@symbols = {}
		@constants = {}
		@strings = {}
		move
		sexps
	end

	private

	# Reports a syntax error when the given class isn't the type of the current
	# token. Otherwise calls Parser#move.
	def match(cls)
		if @token.is_a? cls
			move
		else
			syntax_error
		end
	end

	# Moves to the next token.
	def move
		@token = @lexer.next_token
	end

	# Reports a syntax error.
	def syntax_error
		Log.error "Syntax error at line #{@lexer.line}, unexpected '#{@token}'"
	end

	# Parses sexps.
	def sexps
		all_sexps = []
		while @token.is_a? Tokens::OpenParen
			all_sexps << sexp
		end
		if Tokens::EOF
			all_sexps
		else
			syntax_error
		end
	end

	# Parses a sexp.
	def sexp
		match Tokens::OpenParen
		case @token
		when Tokens::CloseParen
			empty_list
		else
			value = elems
			match Tokens::CloseParen
			Nodes::Sexp.new value
		end
	end

	# Parses an empty list.
	def empty_list
		match Tokens::CloseParen
		Nodes::EmptyList.new
	end

	# Parses elements of a list.
	def elems
		case @token
		when Tokens::CloseParen
			[]
		else
			[ elem ] + elems
		end
	end

	# Parses an element of a list.
	def elem
		case @token
		when Tokens::OpenParen
			sexp
		when Tokens::Symbol
			symbol
		when Tokens::Constant
			constant
		when Tokens::QuotationMark
			match Tokens::QuotationMark
			Nodes::Sexp.new([Nodes::Symbol.new('quote'), elem])
		when Tokens::String
			string
		else
			syntax_error
		end
	end

	# Parses a symbol.
	def symbol
		value = @token.name
		match Tokens::Symbol
		@symbols[value] ||= Nodes::Symbol.new value
	end

	# Parses a constant.
	def constant
		value = @token.value
		match Tokens::Constant
		@constants[value] ||= Nodes::Constant.new value
	end

	# Parses a string.
	def string
		value = @token.value
		match Tokens::String
		@strings[value] ||= Nodes::String.new value
	end
end
