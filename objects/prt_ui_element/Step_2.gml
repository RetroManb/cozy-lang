


/// move all children
for (var i = 0, n = array_length(children); i < n; i++)
{
	var child = children[i];
	child.parent = id;
	child.x = child.xstart+x - sprite_width/2;
	child.y = child.ystart+y - sprite_height/2;
	child.depth = depth-1;
}