event_inherited();

iconTargetScale = isHovered and !isMouseDown ?
	1.5 :
	1
textTargetScale = isHovered and !isMouseDown ?
	1.1 :
	1

iconScale += (iconTargetScale-iconScale) * 0.125;
textScale += (textTargetScale-textScale) * 0.125;