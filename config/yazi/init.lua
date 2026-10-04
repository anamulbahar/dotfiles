-- Append a POSIX-style slash to directory names without using icons or fonts.
Entity:children_add(function(self)
	return self._file.cha.is_dir and "/" or ""
end, 4500)
