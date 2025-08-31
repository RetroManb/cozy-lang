if (isHovered and active)
{
	if (mouse_check_button_pressed(mb_left))
		isMouseDown = true;
	if (isMouseDown and mouse_check_button_released(mb_left))
	{
		isMouseDown = false;
		
		onClick();
	}
}
else
	isMouseDown = false;