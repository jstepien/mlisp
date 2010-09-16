# Generates unique labels for given strings.
class LabelGen
	def initialize
		@labels = []
		@class_count = {}
	end

	# Adds a new label for a given string and returns it.
	def add(str)
		label = str.to_s + '_' + (@class_count[str] ||= 0).to_s
		@labels << label
		@class_count[str] += 1
		label
	end
end
