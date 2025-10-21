textAlpha = 1;
text = "Average execute\ntime over 3 seconds";

onClick = function() {
	var start = get_timer();
	
	var count = 0;
	
	do
	{
		obj_cozytest.run(true);
		count++;
		
		array_resize(obj_cozytest.output,0);
	} until (get_timer() >= start+3000000);
	
	var timeElapsedMs = (get_timer()-start)/1000;
	executionTime = timeElapsedMs/count;
}