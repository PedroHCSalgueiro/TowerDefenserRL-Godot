class_name SaveCodec
extends RefCounted
## Codificação exata para o save. O parser de JSON do Godot NÃO devolve o mesmo double para números
## de 17 dígitos (mudou o último bit em ~17% dos casos testados), e a simulação só repete a mesma
## run se cada float voltar idêntico. Por isso todo float vai para o JSON como texto com o padrão de
## bits IEEE-754 ("~f:" + 16 dígitos hexadecimais); inteiros e textos seguem como são.

const PREFIX := "~f:"


static func encode_float(x: float) -> String:
	return PREFIX + PackedFloat64Array([x]).to_byte_array().hex_encode()


static func decode_float(text: String) -> float:
	return text.substr(PREFIX.length()).hex_decode().to_float64_array()[0]


## Troca, em profundidade, cada float por texto (Dictionary/Array são copiados; o resto passa).
static func encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return encode_float(value)
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[key] = encode(value[key])
			return out
		TYPE_ARRAY:
			var list: Array = []
			for item in value:
				list.append(encode(item))
			return list
	return value


## Inverso de `encode`; inteiros que o JSON trouxe como float (3.0) viram int quando sem parte
## fracionária (o JSON do Godot não distingue).
static func decode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING:
			if String(value).begins_with(PREFIX):
				return decode_float(value)
			return value
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[key] = decode(value[key])
			return out
		TYPE_ARRAY:
			var list: Array = []
			for item in value:
				list.append(decode(item))
			return list
		TYPE_FLOAT:
			# Números sem o prefixo vieram do JSON como float: inteiros voltam como int.
			return int(value) if floorf(value) == value and absf(value) < 9.0e15 else value
	return value
