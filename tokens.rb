# Tokens returned by the Lexer.
module Tokens
	class Token
	end

	class Symbol < Token
		attr_reader :name

		def initialize(name)
			@name = name
		end
	end

	class Constant < Token
		attr_reader :value

		def initialize(value)
			@value = value
		end
	end

	class OpenParen < Token
	end

	class CloseParen < Token
	end

	class EOF < Token
	end

	class QuotationMark < Token
	end

    class String < Token
		attr_reader :value

		def initialize(value)
			@value = value
		end
    end
end
