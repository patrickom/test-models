class ProxyParam < ActiveRecord::Base
  belongs_to :proxy_dyna_model
  belongs_to :param
  has_paper_trail

  def code
    self.param.code
  end
  
  def initialize(*args)
    super
    custom_init
  end
  
  def custom_init
    @unit = [] if @unit.nil?
    @mean = nil if @mean.nil?
    @std_dev = nil if @std_dev.nil?
  end
  
  def mean_add(number)
    
    @mean = nil
    @std_dev = nil
    @unit.push(number)
  end
  
  def mean
    return self.value if @unit.size == 0
    @mean = @unit.sum / @unit.size if @mean.nil?
    self.value = @mean
    @mean
  end
  
  def std_dev
    
    return @std_dev unless @std_dev.nil?

    return 0 if @unit.size == 0
    sum = 0
    @unit.each do |n|
      sum += (n - @mean)**2
    end
    
    @std_dev = Math.sqrt(sum / (@unit.size - 1))    
  end
  
  def count
    @unit.size
  end
  
end