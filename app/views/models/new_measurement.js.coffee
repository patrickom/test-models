$('<div><%= escape_javascript(render("measurements/form")) %></div>').dialog({modal:true, width:$('#content').css("width"), height:'auto'});