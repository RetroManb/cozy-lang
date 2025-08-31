event_inherited();

if (isHovered and !isMouseDown)
	iconAlpha = toggled ?
		1 :
		0.5;
else if (isMouseDown)
	iconAlpha = 0;
else
	iconAlpha = toggled;