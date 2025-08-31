event_inherited();

if (isHovered and isMouseDown)
{
	x += obj_ui.mouseDeltaX;
	y += obj_ui.mouseDeltaY;
}

titleTargetScale = isHovered and !isMouseDown ?
	1.1 :
	1

titleScale += (titleTargetScale-titleScale) * 0.125;