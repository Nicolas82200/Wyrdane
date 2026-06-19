extends Resource
class_name KeywordChoice

@export_enum(
	"Rempart", "Assaut", "Protection", "Moisson", "Frénésie",
	"Venin mortel", "Ravage", "Ailes noires", "Égide"
) var name_fr: String = "Rempart"

var keyword_type: int:
	get:
		match name_fr:
			"Rempart": return Keyword.Type.TAUNT
			"Assaut": return Keyword.Type.CHARGE
			"Protection": return Keyword.Type.PROTECTION
			"Moisson": return Keyword.Type.LIFESTEAL
			"Frénésie": return Keyword.Type.FURY
			"Venin mortel": return Keyword.Type.DEADLY_POISON
			"Ravage": return Keyword.Type.RAVAGE
			"Ailes noires": return Keyword.Type.BLACK_WINGS
			"Égide": return Keyword.Type.AEGIS
			_: return Keyword.Type.TAUNT

func _to_string() -> String:
	return name_fr
