class Ability
  include CanCan::Ability

  def initialize(user)

    # Model structure
    can :read, [:models,:experiments,:measurements,:lines,:proxy_dyna_models] do |obj|
      obj.can_view(user) # all classes have this method implemented
    end
    can [:update,:edit,:show,:index,:new,:create,:destroy], [:models,:experiments,:measurements,:lines,:proxy_dyna_models] do |obj|
      obj.can_edit(user) # all classes have this method implemented
    end
    
    can [:new], [:experiments,:measurements,:lines,:proxy_dyna_models] do |obj|
      obj.can_edit(user) # all classes have this method implemented
    end
    
    can :new,:models
    
    # Specific to ProxyDynaModel object
    can [:calculate] , :proxy_dyna_models do |obj|
      obj.can_edit(user) # all classes have this method implemented
    end

    # Specific to Measurement object
    can [:regression,:read], [:measurements] do |obj|
      obj.can_view(user) # all classes have this method implemented
    end
    can [:update_regression] , :measurements do |obj|
      obj.can_edit(user) # all classes have this method implemented
    end

    
    # Dyna Model
    can [:update,:edit,:destroy,:show,:index,:new,:create], :dyna_models, DynaModel do |dm|
      !user.nil? && ( !dm.only_owner_can_change || dm.owner_id == user.id )
    end
    
    # Params (for Dyna Models)
    can [:new,:create,:edit,:update,:destroy], :params, Param do |p|
      !user.nil? && ( !p.dyna_model.only_owner_can_change || p.dyna_model.owner_id == user.id )
    end
    
    # Group
    can :access, :groups, Group do |g|
      !user.nil? && g.can_access(user)
    end

    # Any user can do
    can :read, :dyna_models
  end
end