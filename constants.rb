# Some constants used both by the compiler and in the C code.
module Constants
	# Offset of bits describing object's type.
	TYPE_OFFSET = 0
	# Number of bits describing object's type.
	TYPE_BITS = 3
	TYPE_INT = 0
	TYPE_NODE = 1
	TYPE_SYMBOL = 2
	TYPE_STRING = 3
	# Size of a double word.
	DWORD_SIZE = 4
	# A value which marks the end of arguments in vararg functions.
	VAR_ARG_DELIM = 0xdeadbeef
end
