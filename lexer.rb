require 'log'
require 'tokens'

class Lexer
	include Tokens

	attr_reader :line

	def input=(input)
		@buffer = Buffer.new input
		@line = 1
	end

	def next_token
		c = next_nonwhitespace_char
		return next_symbol(c) if c.is_symbol?
		return next_numeral(c) if c.is_numeral?
		case c
		when '('
			OpenParen.new
		when ')'
			CloseParen.new
		when ''
			EOF.new
		when "'"
			QuotationMark.new
		when '"'
			String.new next_string
		else
			Log.error "Illegal character on line #{@line}: '#{c}'"
		end
	end

	private

	def next_nonwhitespace_char
		while true
			return '' if (c = @buffer.read_char).nil?
			@line += 1 if c == "\n"
			return c if not c.is_whitespace?
		end
	end

	def next_symbol(symbol)
		while true
			c = @buffer.read_char
			if c.is_whitespace? or not (symbol + c).is_symbol?
				@buffer.unread_char c
				break
			end
			break if c.nil?
			symbol << c
		end
		Symbol.new symbol
	end

	def next_numeral(symbol)
		while true
			c = @buffer.read_char
			if c.is_whitespace? or not (symbol + c).is_numeral?
				@buffer.unread_char c
				break
			end
			break if c.nil?
			symbol << c
		end
		Constant.new symbol
	end

	def next_string()
		string = ''
		while true
			c = @buffer.read_char
			break if c == '"'
			string << c
		end
		string
	end
end

class Buffer
	BufferSize = 1024

	def initialize(input)
		@input = input
		@buffer = []
	end

	def read_char
		if @buffer.empty?
			return nil unless new_buffer = @input.read(BufferSize)
			@buffer = new_buffer.chars.to_a
		end
		@buffer.shift
	end

	def unread_char(c)
		@buffer.unshift c
	end
end

class String
	WHITESPACES = [' ', "\t", "\n"]

	SYMBOL_RE = /^[a-zA-Z<=>\-*\/\+][a-zA-Z0-9_\-\?=]*$/

	def is_whitespace?
		WHITESPACES.include? self
	end

	def is_symbol?
		self =~ SYMBOL_RE
	end

	def is_numeral?
		self.to_i.to_s == self
	end
end
