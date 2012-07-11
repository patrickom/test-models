class CalculateJob < Struct.new(:calculate_ids, :custom_params )
  def perform
    proxy_dyna_models = ProxyDynaModel.find(calculate_ids)
    proxy_dyna_models.call_estimation_with_custom_params( custom_params )
    #proxy_dyna_models.each do |pdm|
    #  pdm.call_estimation_with_custom_params( custom_params )
    #end
  end
  
  def error(job, exception)
    pdm = ProxyDynaModel.find(calculate_ids)
    pdm.notes = "error estimating parameters: " + exception.message
    pdm.save
  end
  
  def failure
    pdm = ProxyDynaModel.find(calculate_ids)
    pdm.notes = "error estimating parameters."
    pdm.save
  end
end

