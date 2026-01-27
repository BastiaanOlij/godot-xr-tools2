@tool
extends XRT2StageBase

@onready var left_hand : XRT2CollisionHand = $XRT2CharacterBody3D/XROrigin3D/XRT2LeftCollisionHand
@onready var right_hand : XRT2CollisionHand = $XRT2CharacterBody3D/XROrigin3D/XRT2RightCollisionHand

# Called when the node enters the scene tree for the first time.
func _ready():
	super()
