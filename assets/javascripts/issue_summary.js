Raphael.fn.sector = function (cx, cy, r, total, values, innerLoop, labels, stroke){
	var paper = this,
	rad = Math.PI / 180,
	chart = this.set(),
	startangle = 0,
	delta = 15,
	ms = 500,
	bcolor = 0.1;

	function arc(startX, startY, endX, endY, radius1, radius2, angle, larc_angle, params) {
	  var arcSVG = [radius1, radius2, angle, larc_angle, 1, endX, endY].join(' ');
	  return paper.path('M'+startX+' '+startY + " a " + arcSVG).attr(params);;	
	};
	
	function circularArc(cr, startAngle, endAngle, params) {
	  var startX = cx+cr*Math.cos(startAngle*rad); 
	  var startY = cy+cr*Math.sin(startAngle*rad);
	  var endX = cx+cr*Math.cos(endAngle*rad); 
	  var endY = cy+cr*Math.sin(endAngle*rad);
	  var larc_angle = 0;
	  if (endAngle - startAngle > 180) {
		larc_angle=1;
	  };
	  return arc(startX, startY, endX-startX, endY-startY, cr, cr, 0, larc_angle,params);
	};

	var process = function (j,sr,value,col,label,url,fs) {
		fs = typeof fs !== 'undefined' ? fs : 14;
		if (col == 0) {var color = "hsb(".concat(Math.round(total) / 200, ",", value / total, ", .75)")}
		else {var color = col;};
		
		var	endangle = Math.round((value / total ) * 360) + startangle,
			popangle = (startangle + endangle) / 2,
		  p_sect = circularArc(sr, startangle, endangle, {"stroke": color,"stroke-width": "50","stroke-linejoin": "round"}),
			p_txt  = paper.text(cx + (sr + delta + 55) * Math.cos(popangle * rad), cy + (sr + delta + 25) * Math.sin(popangle * rad), label + "\n" + value).attr({fill: bcolor, stroke: "none", opacity: 0, "font-size": fs});

		p_sect.mouseover(function () {
			p_sect.stop().animate({transform: "s1.1 1.1 " + cx + " " + cy}, ms, "elastic");
			p_txt.stop().animate({opacity: 1}, ms, "elastic");
		}).mouseout(function () {
			p_sect.stop().animate({transform: ""}, ms, "elastic");
			p_txt.stop().animate({opacity: 0}, ms);
		}).mouseup(function(e) {
			alert("clicked");
			window.open(url, '_blank');
		});
			
		chart.push(p_sect);
		chart.push(p_txt);
		startangle = endangle;		
	};

    for (i = 0; i < values.length; i++) {
        process(i,r,values[i][0],0,labels[i],values[i][1]);
    }

	var bg_color = {
		"o" : Raphael.color("blue"),
		"c" : Raphael.color("green")},
		inner_label = { "o" : "Open" , "c" : "Closed" }
		flag = 0;	
    for (i = 0; i < innerLoop.length; i++) {
      process(i,r-60,innerLoop[i][0],bg_color[innerLoop[i][1]], innerLoop[i][3] + " " + inner_label[innerLoop[i][1]] , inner_label[innerLoop[i][2]],10);
    };
	
	var circle = paper.circle(cx, cy, 50).attr("fill", Raphael.getRGB("cornflowerblue"),"stroke", "#fff");
	var c_text = paper.text(cx, cy, total ).attr({fill: Raphael.getRGB("white"), stroke: "none", opacity: 1, "font-size": 20});
	
	return chart;
};

function createChart(ele,chart_canvas) {
  var tracker_tot_ary = new Array(),
    value = 0,
    total = 0,
    labels = [],
    innerLoop = [],
    label = ""; 
  $('#' + ele + ' td').each(function () {
    
    if ($(this).hasClass("t") == true){
      value = parseInt(($(this).children('a').html()),10);
      if (isNaN(value) == false){
        total+=value;
        tracker_tot_ary.push([value, $(this).children('a').attr("href")]);
      }else{
        tracker_tot_ary.push([0, ""]);
      };
    }
    else if ($(this).hasClass("name") == true){
    	label = $(this).children('a').html();
      labels.push(label);
    }
    else{
    	value  = parseInt(($(this).children('a').html()),10);
    	c_link = $(this).children('a').attr("href");
    	if (isNaN(value) == true){
      	value = 0;
      	c_link = "";
      };
      innerLoop.push([value,$(this).attr("class"), c_link, label]);
    };
  });

  Raphael(chart_canvas, 400, 400).sector(200, 200, 150, total, tracker_tot_ary, innerLoop, labels, "#fff");
};

Raphael.fn.barchart = function ( ){
	var paper = this;
	
};