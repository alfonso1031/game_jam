# Sin `class_name` a propósito: el registro global de clases vive en `.godot/`, que
# no se versiona, así que en un clon nuevo ese nombre no existe hasta abrir el
# editor. Todos los consumidores hacen `preload("res://core/palette.gd")`, que
# funciona siempre. Declararlo además como clase global solo provocaba el warning
# de constante que tapa a una clase.

const VOID := Color("#313638")
const FLOOR := Color("#32535f")
const WALL := Color("#0a777a")
const SLIME_BODY := Color("#4aa881")
const SLIME_CORE := Color("#73efe8")
const WARM_LIGHT := Color("#ecf3b0")
