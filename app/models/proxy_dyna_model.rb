class ProxyDynaModel < ActiveRecord::Base
  belongs_to :measurement
  belongs_to :experiment
  belongs_to :dyna_model
  has_many :proxy_params, :dependent => :destroy
  
  before_create :update_params
  before_update :update_params
  
  has_paper_trail :skip => [:json]
  
  public
  
    # bias standard deviation attribution
    def bias_stdev=(arg)
      @bias_stdev = arg
    end
    # bias standard deviation
    def bias_stdev
      @bias_stdev
    end
    # accuracy standard deviation attribution    
    def accuracy_stdev=(arg)
      @accuracy_stdev = arg
    end
    # accuracy standard deviation
    def accuracy_stdev
      @accuracy_stdev
    end
    # RMSE standard deviation attribution
    def rmse_stdev=(arg)
      @rmse_stdev = arg
    end
    # RMSE standard deviation attribution
    def rmse_stdev
      @rmse_stdev
    end
    
    def get_estimation_url
      estimation_url(self.dyna_model.params)
    end
    
    def get_solver_url
      solver_url
    end
    
    # calculates statiscal data:
    #  - RMSE
    #  - Accuracy factor
    #  - Bias Factor
    def statistical_data
      return nil if measurement.nil? # if proxy_dyna_model does not reference a measurement, then it showld not calculate
      # TODO death phase optional to dyna_model parameter
      lines = measurement.lines_no_death_phase
      size = lines.size
      line = lines.shift
      rmse = 0
      bias = 0 
      accu = 0
      old = line.y
      
      begin
        JSON.parse(json)["result"].each do |pair|
          break if line.nil?
          next if pair[1]<= 0
          #
          if pair[0] >= line.x
            pair[1] = ( old + pair[1] ) / 2 if pair[0] > line.x
            rmse +=  ( pair[1] - line.y ) ** 2
            print pair[1].to_s + " - " + line.y.to_s + "\n"
            bias = Math.log( pair[1] / line.y ).abs
            accu = Math.log( pair[1] / line.y )
            line = lines.shift  
          else
            old = pair[1]
            nil
          end
        end
      rescue Exception => e  
        return [].push(measurement.id).push(-1)
      end
      self.bias = 10 ** (bias / size )
      self.accuracy = 10 ** (accu / size )
      self.rmse = Math.sqrt ( rmse / size )
      self.notes = ""
      self.save
      [].push(measurement.model.id).push(measurement.model.title).push(measurement.id).push( self.bias ).push( self.accuracy ).push( self.rmse  )
    end
    
    def call_pre_estimation_background_job
      clean_stats "parameters are being calculated in background"
    end
  
    # perform parameter estimation
    def call_estimation
      call_estimation_with_custom_params( self.dyna_model.params )
    end
    
    def call_estimation_with_custom_params(params)
      return unless !(self.measurement.nil?) || !(self.estimation.nil?) || !(self.estimation == "")
      
      url = estimation_url( params )
  
      begin
        response = Net::HTTP.get_response(URI(url))
      rescue Timeout::Error
        clean_stats "timeout while calculating parameters, try again"
        return
      end
      result = JSON.parse( response.body.gsub(/(\n|\t)/,'') )
      
      self.proxy_params.each do |d_p|
        d_p.value = result[d_p.param.code] if !result[d_p.param.code].nil?
        d_p.save
        d_p
      end
      self.json = nil
      self.json_cache # call solver and calculate statistical data
    end
    
    def json_cache
      return self.json unless self.json.nil?
      return  if self.call_solver.nil?
      self.statistical_data 
      self.json
    end
    
    def call_solver
      
      url = solver_url
      
      begin    
        response = Net::HTTP.get_response(URI(url))
      rescue Timeout::Error
        self.notes = "timeout while simulating, try again"
        self.json = nil
        self.save
        return
      end
      self.json = response.body.gsub(/(\n|\t)/,'')
      self.save
      self.json
    end
       
    def original_data=(data)
      #@data = data
    end
   
    def convert_param(original_args)
      flag = false
      self.proxy_params.each { |param|
        temp = /#{param.code} = (?<value>[0-9]+[.]?[0-9]*)/.match(original_args)
        if temp
  #        print "---> " + temp.to_s + "\n"
          param.value = temp[:value]
          flag = true if param.save
        end
      }    
      self.call_solver if flag
      statistical_data if flag
    end
    
    def original_data
      string = ""
      self.proxy_params.collect { |param|
        string += param.code.to_s + " = "
        if param.code.nil?
          string += "<value>\n"
        else
          string += param.value.to_s + "\n"
        end
      }
      string
    end
    
    def update_params(no_commit = false)
      
      params = self.proxy_params
      
      dyna_params = self.dyna_model.params
      
      dyna_params.collect { |d_p|
        
        list = nil
        list = params.find_all { |p|
          p.param_id == d_p.id
        }
        if list.length == 0
          new_param = self.proxy_params.build
          new_param.param = d_p
          new_param.value = nil
          
          new_param.save unless no_commit
          
          new_param
        else
          list.first.custom_init
          list.first
        end
      }
     
    end
  
  private
    # clean statistical information
    def clean_stats(note)
      self.rmse = nil
      self.bias = nil
      self.accuracy = nil
      self.notes = note
      self.save
    end
    
    # get solver url with parameters
    def solver_url
      url_params = self.proxy_params.collect { |p|
        next if p.code == 'o'
        return nil if p.value.nil?      
        "#{p.param.code}=#{p.value.to_s}"
      }.compact.join('&')
      
      if self.measurement.nil?
        url = "#{self.dyna_model.solver}?#{url_params}&end=48"
      else
        url = "#{self.dyna_model.solver}?#{url_params}&#{self.measurement.end_title}=#{self.measurement.end.to_s}"
      end
      url
    end
    
    # convert single parameter to url ready
    def param_to_url( code, top , bottom )
      CGI::escape("{\"name\"")   + ":" + CGI::escape("\"") + "#{code}"  + CGI::escape("\"") + "," +
      CGI::escape("\"bottom\"") + ":"  + "#{bottom}"    + "," +
      CGI::escape("\"top\"")    + ":"  + "#{top}" + CGI::escape("}")
    end
    
    # get solver url with parameters
    def estimation_url( params )
      # TODO make death phase optional
      x_array = self.measurement.x_array
      y_array = self.measurement.y_array
   
      url = "#{self.dyna_model.estimation}?time=[#{x_array}]&values=[#{y_array}]"
      url += "&estimation=" + CGI::escape("{\"states\"") + ":["
      # URL parameters (that map against states in SBTOOLBOX2)
      url_states = params.collect { |p|
        next if p.output_only || p.initial_condition
        if p.top.nil? || p.bottom.nil?
          raise Exception.new(p.human_title.html_safe + " does not have top/bottom values")
        else
          param_to_url( p.code , p.top, p.bottom )
        end 
      }.compact.join(',') + "]"
      # URL initial conditions (that map against initial conditions in SBTOOLBOX2)
      url_ic = "," + CGI::escape("\"initial\"") + ":["
      url_ic += params.collect { |p|
        next unless p.initial_condition
        if p.top.nil? || p.bottom.nil?
          raise Exception.new(p.human_title.html_safe + " does not have top/bottom values")
        else
          param_to_url( p.code , p.top, p.bottom )
        end 
      }.compact.join(',') + ',' + param_to_url( "t" , "100" , "0" ) + "]" # adds time
  
      url += url_states + url_ic;
      url += CGI::escape("}")
      url
    end
  
end
