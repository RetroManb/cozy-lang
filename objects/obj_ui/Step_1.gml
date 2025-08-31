
/// get ui element that is being hovered over
hoveringInstance = noone;

with (prt_ui_element)
	isHovered = false;

var minDepth = infinity;

var list = ds_list_create();
var count = collision_point_list(mouse_x,mouse_y,prt_ui_element,true,true,list,false);

for (var i = 0; i < count; i++)
{
	var element = list[| i];
	
	if (element.depth < minDepth)
	{
		minDepth = element.depth;
		hoveringInstance = element;
	}
}

if (instance_exists(hoveringInstance))
	hoveringInstance.isHovered = true;

ds_list_destroy(list);