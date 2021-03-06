# BGFit - Bacterial Growth Curve Fitting
# Copyright (C) 2012-2012  André Veríssimo
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 2
# of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Google chart visualization tools
#  these are auxiliary javascript functions that help
#  to create a chart 
if typeof google isnt 'undefined'
  google.load 'visualization', '1.0', {'packages':['corechart','table']}
  $(document).ready () -> 
    
    if not $(".proxy_dyna_model_chart").length
      return; 
    
      
    options = {
      curveType: 'function',
      lineWidth: 1,
      pointSize: 5,
      width: 900,
      height: 500,
      legend: {
        #position: "bottom" # places the legend on bottom, instead of on the side
      }
      chartArea: {
          width:"70%",
          height: "80%"
      },
      animation: {
        easing: "in",
        duration: 1000
      },
      vAxis: {
        viewWindowMode: "explicit"
      }
      hAxis: {
        viewWindowMode: "explicit"
      }
    }
    
    window = exports ? this # allowing to define global functions and variables
    window.options = options
    
    setup_m = {
      timeout: 10000,
      dataType: 'json',
      error: (jqXHR, textStatus, errorThrown) ->
        error_text = "There was a problem retrieving data (<a href=\"" + @url + "\">" + @url + "</a>). Error description: " + textStatus
        $("#chart-errors").append($("<p>" + error_text + "</p>"))
    }
    setup = {
      timeout: 10000,
      dataType: 'json',
      error: (jqXHR, textStatus, errorThrown) =>
        #alert(textStatus)
    }
    
    $('a.hide').on 'click' , (event) =>
      top = $(event.currentTarget).parents('.proxy_dyna_model_chart').slideUp()
      false
    
    $('a.download.svg').on 'hover' , (event) =>
      $(event.currentTarget).prop('href','#')
    
    $('a.download.svg').on 'click' , (event) =>
      target = $(event.currentTarget)
      base64 = target.parents('div.proxy_dyna_model_chart').find('div.chart svg').parent()[0].innerHTML
      
      target.prop('href','data:image/svg;base64,'+ btoa(base64))
      true
    
    $('a.download.png').on 'click' , (event) =>
      target = $(event.currentTarget)
      base64 = target.parents('div.proxy_dyna_model_chart').find('div.chart svg').parent()[0]
      imgData = getImgData(base64)
      target.prop('href',imgData)
      true
      

    process_google_chart = (el,data) ->
      calculate_view_window( data, options )
      chart = new google.visualization.ScatterChart el
      # Ready event
      google.visualization.events.addListener chart, 'ready', () =>
        # if not visible yet, it will slide down
        if !$(el).parents('.proxy_dyna_model_chart').is(':visible')
          $(el).parents('.proxy_dyna_model_chart').slideDown(1500, "swing")
        # options div will slide down
        $(el.parentNode).find('div.options').slideDown(1500, "swing")
        # mark chart as loaded
        $(el).attr('loaded','true')
      # Error Event
      google.visualization.events.addListener chart, 'error', (error) =>
        $(el)[0].innerHTML = 'failed to load chart.'
        #$(el).parent().slideDown(1500, "swing").effect("highlight")
      chart.draw(data, options)
    
    data_add = (data, list) ->
      list.forEach (i) => 
        l = data.addColumn 'number' , i.title , i.id
#        alert_flag = 0
        rows = []
        i.rows.forEach (j) =>
          #
          if l == 1
            row = []
          else
            row = (null for num in [1..l-1])
          if j.c[0].v != "-_Inf_" && j.c[1].v != "-_Inf_" 
            row.unshift j.c[0].v
            row.push j.c[1].v
            rows.push row
#          else if alert_flag == 0
#            if j.c[0].v == "-_Inf_"
#              alert_flag = j.c[0].v
#            else
#              alert_flag = j.c[1].v
#            alert 'Attention: ' + i.title + ' has ' + alert_flag + ' values!'
        #
        data.addRows rows
      data
    
    process_measurement = (el , data) ->
      #
      list = []
      $(el).parent().find('.measurement-data div').each (i,measurement_data) =>
        setup_m.url = $(measurement_data).attr('data-source') 
        m_ajax = $.ajax(setup_m).done (json) =>
          list.push json

          if list.length != $(el).parent().find('.measurement-data div').length
            return # is not the final measurement
          # 
          data_add(data,list)
          process_google_chart(el,data)
        #
      #    
    
    # calculate view window for google chart
    #  x and y minimum and maximum axis' range
    calculate_view_window = ( data,options ) ->
      # offset for the window view
      OFFSET_RATIO = .3
      
      v_max_arr = (data.getColumnRange(num).max for num in [1..(data.getNumberOfColumns()-1)])
      v_min_arr = (data.getColumnRange(num).min for num in [1..(data.getNumberOfColumns()-1)])
    
      v_max = Math.max.apply(null, v_max_arr)
      v_min = Math.min.apply(null, v_min_arr)
      offset = Math.abs( v_max - v_min ) * OFFSET_RATIO
      v_max = v_max + offset
      if v_min - offset < 0 && v_min >= 0
        v_min = 0 
      else
        v_min = v_min - offset
      options.vAxis = { 
        viewWindow: {
          max: v_max
          min: v_min
          }
      }
      # commented out because charts should have a fixed horizontal size
      h_max = Math.max.apply(null, [data.getColumnRange(0).max] )
      h_min = Math.min.apply(null, [data.getColumnRange(0).min] )
      offset = Math.abs( h_max - h_min ) * OFFSET_RATIO
    
      if h_min - offset < 0 && h_min >= 0
        h_min = 0
      else
        h_min = h_min - offset
      h_max = h_max + offset
      options.hAxis = {
        viewWindow: {
          max: h_max,#range_h.max,
          min: h_min #range_h.min
          }
      }
    
    #
    #
    # Main function that processes chart
    window.process_chart = (element) ->
      data = new google.visualization.DataTable();
      data.addColumn 'number','Time','time'
      #
      $(element).parent().children('div.chart').each (index,el) =>
        #
        $(el).html("<br/><div class=\"one_tab\">loading...</div>")
        $(el).parent().slideDown("slow","easeInCirc")
        if $(el).parent().find('.model-data div').length <= 0
          process_measurement( el , data )
        #
        list = []
        column_number = []
        $(el).parent().find('.model-data div').each (index,el2) =>
          setup.url = $(el2).attr('data-source')
          #
          result = $.ajax(setup)
          #         
          result.done (json) =>
            jsonObj = json
            jsonObj["title"] = $(el2).html()
            list.push jsonObj
            #
            if list.length != $(el).parent().find('.model-data div').length
              return
            #
            list.forEach (i) => 
              l = data.addColumn 'number' , i.title , i.title.toLowerCase()
              if options.series == undefined
                options.series = {}
              temp = { lineWidth: 3, pointSize: 0}
              options.series[String(l-1)] = temp
              #
              rows = []
              i.result.forEach (j) =>
                #
                if l == 1
                  row = []
                else
                  row = (null for num in [1..l-1])
                if j[0] != "-_Inf_" && j[1] != "-_Inf_" 
                  row.unshift j[0]
                  row.push j[1]
                  rows.push row
              #
              data.addRows rows
            #
            process_measurement( el , data )
 
    wrapper = $('.proxy_dyna_model_chart')
    if wrapper.is('.auto-load')    
      wrapper.children('.chart').css("height",options.height)
      window.process_chart(wrapper.children('.chart'))






  
    #
    #
    #
    #
    # Estimate specific javascript
    #    
    $('a.estimate_chart').on 'click' , (event) =>
      target = $(event.currentTarget)
      wrapper = target.parents('.experiments').find('.proxy_dyna_model_chart')
      # set the measurement title to the chart
      wrapper.find('.chart_name').html(target.parent().siblings(".measurement-title").html())
      if !wrapper.children('.proxy_dyna_model_chart').is(':visible')
        wrapper.children('.chart').css("height",options.height)
        wrapper.slideDown()
      wrapper.find('.model-data div').attr('data-source'      , target.parent().siblings(".measurement-model_d").attr('data-source'))
      wrapper.find('.model-data div').html( target.parent().siblings(".measurement-model_d").html() )
      wrapper.find('.measurement-data div').attr('data-source', target.parent().siblings(".measurement-data_d").attr('data-source'))
      wrapper.find('.measurement-data div').html( target.parent().siblings(".measurement-data_d").html() )
      window.process_chart(wrapper.children('.chart'))
      false
    #
    #
    #
    #
    # Stats specific javascript
    #
    
          
    $('h5.button').on 'click' , (event) =>
      target = $(event.currentTarget)
      wrapper = $(target).parent().children('div.toggle')
      if wrapper.is(":visible") 
        wrapper.slideUp()
      else
        wrapper.slideDown()
        if !wrapper.children('.chart').is('.chart')
          wrapper.effect('highlight')

      if wrapper.children('.chart').is('.chart') && !wrapper.children('.chart').attr('loaded')
        wrapper.children('.chart').css("height",options.height)
        window.process_chart(wrapper.children('.chart'))
      false



